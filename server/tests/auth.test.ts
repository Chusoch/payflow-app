/// <reference types="jest" />

import request from 'supertest';
import app from '../src/app';
import * as firebaseAdmin from '../src/firebase';

// Mock Firebase Auth and Firestore for unit tests
jest.mock('../src/firebase', () => {
  const usersStore: Record<string, any> = {
    '+2348011111111': { walletBalance: 100000 }, // User A: ₦1,000.00 (100,000 kobo)
    '+2348022222222': { walletBalance: 50000 },  // User B: ₦500.00 (50,000 kobo)
  };

  const processedReferences: Record<string, any> = {};

  const mockDb = {
    collection: (collName: string) => ({
      doc: (docId: string) => ({
        get: async () => ({
          exists: !!(collName === 'users' ? usersStore[docId] : processedReferences[docId]),
          data: () => (collName === 'users' ? usersStore[docId] : processedReferences[docId]),
        }),
        set: async (data: any) => {
          if (collName === 'users') {
            usersStore[docId] = { ...(usersStore[docId] || {}), ...data };
          }
        },
        update: async (data: any) => {
          if (collName === 'users') {
            usersStore[docId] = { ...(usersStore[docId] || {}), ...data };
          }
        },
        collection: (subCollName: string) => ({
          doc: (subDocId: string) => ({
            get: async () => ({ exists: false, data: () => null }),
            set: async () => {},
          }),
        }),
      }),
    }),
    runTransaction: async (updateFunction: (transaction: any) => Promise<any>) => {
      const transactionMock = {
        get: async (docRef: any) => {
          return docRef.get();
        },
        update: (docRef: any, data: any) => {},
        set: (docRef: any, data: any) => {},
      };
      return updateFunction(transactionMock);
    },
  };

  const mockAuth = {
    createCustomToken: async (uid: string, claims?: any) => {
      return `custom_token_for_${uid}`;
    },
    verifyIdToken: async (token: string) => {
      if (token === 'valid_user_a_token') {
        return { uid: '+2348011111111', phone_number: '+2348011111111', email: 'user_a@payflow.app' };
      }
      if (token === 'valid_user_b_token') {
        return { uid: '+2348022222222', phone_number: '+2348022222222', email: 'user_b@payflow.app' };
      }
      if (token === 'stale_claim_user_token') {
        return { uid: '+2348011111111', phone_number: '+2348099999999', email: 'user_a@payflow.app' };
      }
      throw new Error('Invalid token');
    },
    getUser: async (uid: string) => ({
      uid,
      phoneNumber: uid,
    }),
  };

  return {
    db: mockDb,
    auth: mockAuth,
    admin: { auth: () => mockAuth, firestore: () => mockDb },
  };
});

import { resetOtpMaps, otpSessionMap } from '../src/routes/auth';
import { normalizePhone } from '../src/services/ledger';

describe('Authentication & User Identity Authorization Tests', () => {
  beforeEach(() => {
    resetOtpMaps();
  });

  it('should send OTP via POST /v1/auth/send-otp and return unique mock pinId', async () => {
    const res = await request(app)
      .post('/v1/auth/send-otp')
      .send({ phone: '08011111111' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.pinId).toBeDefined();
    expect(typeof res.body.pinId).toBe('string');
    expect(res.body.pinId).toContain('mock_pin_');
    expect(res.body.mode).toBe('mock');
  });

  it('should enforce 60-second rate limit on rapid repeated OTP send calls for same phone', async () => {
    const phone = '08011111111';

    // 1st Send Attempt: Succeeds
    const res1 = await request(app).post('/v1/auth/send-otp').send({ phone });
    expect(res1.status).toBe(200);

    // 2nd Send Attempt immediately after: Rejected with 429 Too Many Requests
    const res2 = await request(app).post('/v1/auth/send-otp').send({ phone });
    expect(res2.status).toBe(429);
    expect(res2.body.error).toContain('Rate limit exceeded');
  });

  it('should verify OTP and mint custom token for the server-bound phone number', async () => {
    const phone = '08011111111';

    // 1. Trigger send-otp
    const sendRes = await request(app).post('/v1/auth/send-otp').send({ phone });
    expect(sendRes.status).toBe(200);
    const pinId = sendRes.body.pinId;

    // 2. Verify OTP with valid mock PIN 123456
    const verifyRes = await request(app)
      .post('/v1/auth/verify-otp')
      .send({ pinId, pin: '123456' });

    expect(verifyRes.status).toBe(200);
    expect(verifyRes.body.phone).toBe('+2348011111111');
    expect(verifyRes.body.customToken).toBe('custom_token_for_+2348011111111');
  });

  it('SECURITY TEST: verify-otp MUST mint custom token for server-known phone A, ignoring spoofed phone B in request body', async () => {
    const phoneA = '08011111111'; // Phone A
    const phoneB = '+2348022222222'; // Phone B (Spoofed in body)

    // 1. Send OTP for Phone A
    const sendRes = await request(app).post('/v1/auth/send-otp').send({ phone: phoneA });
    expect(sendRes.status).toBe(200);
    const pinIdA = sendRes.body.pinId;

    // 2. Verify OTP passing pinIdA, pin: 123456 AND phone: Phone B in body
    const verifyRes = await request(app)
      .post('/v1/auth/verify-otp')
      .send({
        pinId: pinIdA,
        pin: '123456',
        phone: phoneB, // Client attempts to claim custom token for Phone B!
      });

    expect(verifyRes.status).toBe(200);
    // Verified that custom token is minted strictly for Phone A (+2348011111111), ignoring Phone B
    expect(verifyRes.body.phone).toBe('+2348011111111');
    expect(verifyRes.body.customToken).toBe('custom_token_for_+2348011111111');
  });

  it('SECURITY TEST: live session MUST return 500 and never mint fake mock token if createCustomToken fails', async () => {
    // Inject a live session into otpSessionMap
    otpSessionMap.set('live_test_pin_id_adc_fail', {
      phone: '+2348011111111',
      createdAt: Date.now(),
      mode: 'live',
    });

    const axios = require('axios');
    const origPost = axios.post;
    axios.post = jest.fn().mockResolvedValue({
      status: 200,
      data: { verified: true, pinId: 'live_test_pin_id_adc_fail' },
    });

    // Temporarily make auth.createCustomToken throw (simulating missing ADC credentials)
    const firebaseAdmin = require('../src/firebase');
    const origCreateCustomToken = firebaseAdmin.auth.createCustomToken;
    firebaseAdmin.auth.createCustomToken = jest.fn().mockRejectedValue(new Error('Could not load default credentials'));

    try {
      const verifyRes = await request(app)
        .post('/v1/auth/verify-otp')
        .send({ pinId: 'live_test_pin_id_adc_fail', pin: '654321' });

      expect(verifyRes.status).toBe(500);
      expect(verifyRes.body.error).toContain('Failed to generate Firebase authentication token for verified live session');
      // Ensure NO mock token was ever returned
      expect(verifyRes.body.customToken).toBeUndefined();
    } finally {
      axios.post = origPost;
      firebaseAdmin.auth.createCustomToken = origCreateCustomToken;
    }
  });

  it('SECURITY TEST: mock session MUST return 500 when createCustomToken fails if ALLOW_MOCK_TOKENS is disabled (default)', async () => {
    // Inject a mock session into otpSessionMap
    otpSessionMap.set('mock_test_pin_id_adc_fail', {
      phone: '+2348011111111',
      createdAt: Date.now(),
      mode: 'mock',
    });

    const { config } = require('../src/config');
    const origAllowMockTokens = config.allowMockTokens;
    config.allowMockTokens = false;

    const firebaseAdmin = require('../src/firebase');
    const origCreateCustomToken = firebaseAdmin.auth.createCustomToken;
    firebaseAdmin.auth.createCustomToken = jest.fn().mockRejectedValue(new Error('Could not load default credentials'));

    try {
      const verifyRes = await request(app)
        .post('/v1/auth/verify-otp')
        .send({ pinId: 'mock_test_pin_id_adc_fail', pin: '123456' });

      expect(verifyRes.status).toBe(500);
      expect(verifyRes.body.error).toContain('Failed to generate Firebase authentication token for verified mock session');
      expect(verifyRes.body.error).toContain('Set GOOGLE_APPLICATION_CREDENTIALS to a valid service account JSON key file path');
      // Ensure NO fake mock token was ever minted
      expect(verifyRes.body.customToken).toBeUndefined();
    } finally {
      config.allowMockTokens = origAllowMockTokens;
      firebaseAdmin.auth.createCustomToken = origCreateCustomToken;
    }
  });

  it('OPT-IN DEV FEATURE: mock session generates mock custom token ONLY when allowMockTokens is explicitly enabled', async () => {
    // Inject a mock session into otpSessionMap
    otpSessionMap.set('mock_test_pin_id_opt_in', {
      phone: '+2348011111111',
      createdAt: Date.now(),
      mode: 'mock',
    });

    const { config } = require('../src/config');
    const origAllowMockTokens = config.allowMockTokens;
    config.allowMockTokens = true; // Explicit opt-in

    const firebaseAdmin = require('../src/firebase');
    const origCreateCustomToken = firebaseAdmin.auth.createCustomToken;
    firebaseAdmin.auth.createCustomToken = jest.fn().mockRejectedValue(new Error('Could not load default credentials'));

    try {
      const verifyRes = await request(app)
        .post('/v1/auth/verify-otp')
        .send({ pinId: 'mock_test_pin_id_opt_in', pin: '123456' });

      expect(verifyRes.status).toBe(200);
      expect(verifyRes.body.customToken).toBeDefined();
      expect(verifyRes.body.customToken).toContain('mock_custom_token_');
      expect(verifyRes.body.phone).toBe('+2348011111111');
    } finally {
      config.allowMockTokens = origAllowMockTokens;
      firebaseAdmin.auth.createCustomToken = origCreateCustomToken;
    }
  });

  it('should reject POST /v1/auth/verify-otp when PIN code is invalid', async () => {
    const sendRes = await request(app).post('/v1/auth/send-otp').send({ phone: '08011111111' });
    const pinId = sendRes.body.pinId;

    const verifyRes = await request(app)
      .post('/v1/auth/verify-otp')
      .send({ pinId, pin: '999999' });

    expect(verifyRes.status).toBe(400);
    expect(verifyRes.body.error).toContain('Invalid');
  });

  it('should return 404 for removed POST /v1/auth/custom-token endpoint to prevent auth bypass', async () => {
    const res = await request(app)
      .post('/v1/auth/custom-token')
      .send({ phone: '08012345678' });

    expect(res.status).toBe(404);
  });

  it('should reject unauthenticated request to /v1/wallet/transfer with 401', async () => {
    const res = await request(app)
      .post('/v1/wallet/transfer')
      .send({
        toPhone: '+2348022222222',
        amount_kobo: 10000,
        reference: 'REF-UNAUTH-001',
      });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('should reject unauthenticated request to /v1/payments/paystack/initialize with 401', async () => {
    const res = await request(app)
      .post('/v1/payments/paystack/initialize')
      .send({
        reference: 'PST-UNAUTH-001',
        amount_in_kobo: 50000,
      });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('should reject invalid Bearer token with 401', async () => {
    const res = await request(app)
      .post('/v1/wallet/transfer')
      .set('Authorization', 'Bearer invalid_bogus_token')
      .send({
        toPhone: '+2348022222222',
        amount_kobo: 10000,
        reference: 'REF-BOGUS-001',
      });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('should derive sender from User A token so User A cannot spend User B funds', async () => {
    // User A attempts to send transfer. Server MUST resolve fromPhone to User A (+2348011111111)
    const res = await request(app)
      .post('/v1/wallet/transfer')
      .set('Authorization', 'Bearer valid_user_a_token')
      .send({
        fromPhone: '+2348022222222', // Client attempts spoofing User B in body!
        toPhone: '+2348033333333',
        amount_kobo: 20000,
        reference: 'REF-SPOOF-001',
      });

    expect(res.status).toBe(200);
    // Verified that fromPhone is User A's token phone, ignoring body spoof attempt
    expect(res.body.fromPhone).toBe('+2348011111111');
    expect(res.body.toPhone).toBe('+2348033333333');
  });

  it('should resolve sender identity strictly from req.user.uid without fallback even if phone_number claim differs', async () => {
    // Mock token has uid: '+2348011111111' but a mismatched/stale phone_number claim: '+2348099999999'
    const res = await request(app)
      .post('/v1/wallet/transfer')
      .set('Authorization', 'Bearer stale_claim_user_token')
      .send({
        toPhone: '+2348044444444',
        amount_kobo: 10000,
        reference: 'REF-STRICT-UID-001',
      });

    expect(res.status).toBe(200);
    // Verified sender identity resolves strictly to req.user.uid (+2348011111111), ignoring stale phone_number (+2348099999999)
    expect(res.body.fromPhone).toBe('+2348011111111');
  });

  describe('normalizePhone Phone Number Normalization Tests', () => {
    it('1. should normalize 11 digits with leading 0 (08123456789 -> +2348123456789)', () => {
      expect(normalizePhone('08123456789')).toBe('+2348123456789');
    });

    it('2. should normalize bare 10 digits without leading 0 (8123456789 -> +2348123456789)', () => {
      expect(normalizePhone('8123456789')).toBe('+2348123456789');
    });

    it('3. should normalize 13 digits starting with 234 without + (2348123456789 -> +2348123456789)', () => {
      expect(normalizePhone('2348123456789')).toBe('+2348123456789');
    });

    it('4. should leave already formatted +234 number unchanged (+2348123456789 -> +2348123456789)', () => {
      expect(normalizePhone('+2348123456789')).toBe('+2348123456789');
    });

    it('should strip spaces, dashes, and parentheses while normalizing', () => {
      expect(normalizePhone('081-234-56789')).toBe('+2348123456789');
      expect(normalizePhone('(081) 234 56789')).toBe('+2348123456789');
      expect(normalizePhone('812 345 6789')).toBe('+2348123456789');
    });

    it('should accept 10-digit bare phone in /v1/auth/send-otp and normalize to +234 for verification', async () => {
      // Test end-to-end OTP flow with 10-digit input like the mobile app produces
      const sendRes = await request(app).post('/v1/auth/send-otp').send({ phone: '8123456789' });
      expect(sendRes.status).toBe(200);
      expect(sendRes.body.status).toBe('success');
      expect(sendRes.body.pinId).toBeDefined();

      const verifyRes = await request(app)
        .post('/v1/auth/verify-otp')
        .send({ pinId: sendRes.body.pinId, pin: '123456' });
      expect(verifyRes.status).toBe(200);
      expect(verifyRes.body.phone).toBe('+2348123456789');
      expect(verifyRes.body.customToken).toBe('custom_token_for_+2348123456789');
    });
  });

  describe('Transaction PIN Verification & Configuration Tests', () => {
    it('should reject PIN verification when PIN is missing', async () => {
      const res = await request(app)
        .post('/v1/auth/verify-pin')
        .set('Authorization', 'Bearer valid_user_a_token')
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('PIN is required');
    });

    it('should verify default dev PIN 1234 in non-production mode when no PIN is set', async () => {
      const res = await request(app)
        .post('/v1/auth/verify-pin')
        .set('Authorization', 'Bearer valid_user_a_token')
        .send({ pin: '1234' });

      expect(res.status).toBe(200);
      expect(res.body.verified).toBe(true);
    });

    it('should allow setting a custom 4-digit PIN via POST /v1/auth/set-pin', async () => {
      const setRes = await request(app)
        .post('/v1/auth/set-pin')
        .set('Authorization', 'Bearer valid_user_a_token')
        .send({ pin: '5678' });

      expect(setRes.status).toBe(200);
      expect(setRes.body.status).toBe('success');

      // Now verify with the new PIN
      const verifyRes = await request(app)
        .post('/v1/auth/verify-pin')
        .set('Authorization', 'Bearer valid_user_a_token')
        .send({ pin: '5678' });

      expect(verifyRes.status).toBe(200);
      expect(verifyRes.body.verified).toBe(true);
    });

    it('should reject invalid PIN when it does not match', async () => {
      const res = await request(app)
        .post('/v1/auth/verify-pin')
        .set('Authorization', 'Bearer valid_user_a_token')
        .send({ pin: '9999' });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('Incorrect PIN');
    });
  });
});



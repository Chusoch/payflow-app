/// <reference types="jest" />

import request from 'supertest';
import app from '../src/app';

jest.mock('../src/firebase', () => {
  const mockAuth = {
    verifyIdToken: async (token: string) => {
      if (token === 'valid_token') {
        return { uid: '+2348011111111', phone_number: '+2348011111111' };
      }
      throw new Error('Invalid token');
    },
    getUser: async (uid: string) => ({ uid, phoneNumber: uid }),
  };

  const createDocMock = (collName: string, docId: string) => ({
    id: docId,
    get: async () => {
      if (collName === 'users' && docId === '+2348011111111') {
        return {
          exists: true,
          id: docId,
          data: () => ({
            fullName: 'Tunde Bakare',
            walletBalance: 1000000,
            balanceInKobo: 1000000,
            balance: 1000000,
          }),
        };
      }
      return { exists: false, id: docId, data: () => null };
    },
    set: async () => ({}),
    update: async () => ({}),
    collection: () => ({
      doc: () => ({
        get: async () => ({ exists: false, data: () => null }),
        set: async () => ({}),
      }),
    }),
  });

  const mockDb = {
    collection: (collName: string) => ({
      doc: (docId: string) => createDocMock(collName, docId),
    }),
    runTransaction: async (cb: (tx: any) => Promise<any>) => {
      const tx = {
        get: async (docRef: any) => {
          if (docRef && typeof docRef.get === 'function') {
            return docRef.get();
          }
          return { exists: false, data: () => null };
        },
        set: () => {},
        update: () => {},
      };
      return cb(tx);
    },
  };

  return {
    db: mockDb,
    auth: mockAuth,
    admin: { auth: () => mockAuth },
  };
});

describe('Users & External Transfers Endpoints', () => {
  const { config } = require('../src/config');
  let origKey: string;

  beforeEach(() => {
    origKey = config.paystackSecretKey;
    config.paystackSecretKey = '';
  });

  afterEach(() => {
    config.paystackSecretKey = origKey;
  });

  it('GET /v1/users/:phone/profile returns user displayName when authenticated', async () => {
    const res = await request(app)
      .get('/v1/users/08011111111/profile')
      .set('Authorization', 'Bearer valid_token');

    expect(res.status).toBe(200);
    expect(res.body.phone).toBe('+2348011111111');
    expect(res.body.displayName).toBe('Tunde Bakare');
  });

  it('GET /v1/users/:phone/profile returns 404 for non-existent user phone', async () => {
    const res = await request(app)
      .get('/v1/users/08099999999/profile')
      .set('Authorization', 'Bearer valid_token');

    expect(res.status).toBe(404);
    expect(res.body.error).toContain('No PayFlow user found with this number');
  });

  it('GET /v1/users/:phone/profile rejects unauthenticated request with 401', async () => {
    const res = await request(app).get('/v1/users/08011111111/profile');
    expect(res.status).toBe(401);
  });

  it('GET /v1/transfers/banks returns bank list with name, code, slug, and id', async () => {
    const res = await request(app)
      .get('/v1/transfers/banks')
      .set('Authorization', 'Bearer valid_token');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThan(0);

    const firstBank = res.body.data[0];
    expect(firstBank).toHaveProperty('name');
    expect(firstBank).toHaveProperty('code');
    expect(firstBank).toHaveProperty('slug');
    expect(firstBank).toHaveProperty('id');
  });

  it('GET /v1/transfers/banks rejects unauthenticated request with 401', async () => {
    const res = await request(app).get('/v1/transfers/banks');
    expect(res.status).toBe(401);
  });

  it('GET /v1/transfers/resolve-account resolves NUBAN account name via query params', async () => {
    const res = await request(app)
      .get('/v1/transfers/resolve-account?accountNumber=0123456789&bankCode=058')
      .set('Authorization', 'Bearer valid_token');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);
    expect(res.body.account_number).toBe('0123456789');
    expect(res.body.account_name).toBeDefined();
  });

  it('GET /v1/transfers/resolve-account returns 400 when query params are missing', async () => {
    const res = await request(app)
      .get('/v1/transfers/resolve-account')
      .set('Authorization', 'Bearer valid_token');

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('accountNumber and bankCode are required');
  });

  it('POST /v1/transfers/resolve-account resolves account name when authenticated', async () => {
    const res = await request(app)
      .post('/v1/transfers/resolve-account')
      .set('Authorization', 'Bearer valid_token')
      .send({
        account_number: '0123456789',
        bank_code: '058',
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);
    expect(res.body.data.account_number).toBe('0123456789');
    expect(res.body.data.account_name).toBeDefined();
  });

  it('POST /v1/transfers/resolve-account rejects unauthenticated request with 401', async () => {
    const res = await request(app)
      .post('/v1/transfers/resolve-account')
      .send({ account_number: '0123456789', bank_code: '058' });
    expect(res.status).toBe(401);
  });

  it('POST /v1/transfers/bank executes external bank transfer with balance check and Firestore debit', async () => {
    const res = await request(app)
      .post('/v1/transfers/bank')
      .set('Authorization', 'Bearer valid_token')
      .send({
        accountNumber: '0123456789',
        bankCode: '058',
        bankName: 'GTBank',
        amount: 50000,
        narration: 'Supplier Payment',
        accountName: 'ALEX CHUKWU',
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);
    expect(res.body.data.recipient.account_number).toBe('0123456789');
    expect(res.body.data.recipient.bank_name).toBe('GTBank');
    expect(res.body.data.destinationBank).toBe('GTBank');
    expect(res.body.data.newBalance).toBe(950000);
  });

  it('POST /v1/transfers/bank rejects transfer when sender has insufficient balance', async () => {
    const res = await request(app)
      .post('/v1/transfers/bank')
      .set('Authorization', 'Bearer valid_token')
      .send({
        accountNumber: '0123456789',
        bankCode: '058',
        bankName: 'GTBank',
        amount: 99999999,
        narration: 'Huge amount',
        accountName: 'ALEX CHUKWU',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Insufficient balance');
  });

  it('POST /v1/transfers/bank rejects missing required parameters', async () => {
    const res = await request(app)
      .post('/v1/transfers/bank')
      .set('Authorization', 'Bearer valid_token')
      .send({
        accountNumber: '0123456789',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('accountNumber, bankCode, and amount are required');
  });

  it('POST /v1/transfers/bank rejects unauthenticated request with 401', async () => {
    const res = await request(app)
      .post('/v1/transfers/bank')
      .send({
        accountNumber: '0123456789',
        bankCode: '058',
        amount: 50000,
      });

    expect(res.status).toBe(401);
  });

  it('POST /v1/transfers/initiate executes external transfer when authenticated', async () => {
    const res = await request(app)
      .post('/v1/transfers/initiate')
      .set('Authorization', 'Bearer valid_token')
      .send({
        bank_code: '058',
        account_number: '0123456789',
        amount_kobo: 500000,
        reference: 'TRF-BANK-001',
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);
    expect(res.body.data.reference).toBe('TRF-BANK-001');
  });

  it('POST /v1/transfers/initiate rejects unauthenticated request with 401', async () => {
    const res = await request(app)
      .post('/v1/transfers/initiate')
      .send({
        bank_code: '058',
        account_number: '0123456789',
        amount_kobo: 500000,
        reference: 'TRF-BANK-001',
      });
    expect(res.status).toBe(401);
  });

  it('GET /v1/transfers/verify/:reference verifies transfer status when authenticated', async () => {
    const res = await request(app)
      .get('/v1/transfers/verify/TRF-BANK-001')
      .set('Authorization', 'Bearer valid_token');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);
    expect(res.body.data.reference).toBe('TRF-BANK-001');
  });

  it('GET /v1/transfers/verify/:reference rejects unauthenticated request with 401', async () => {
    const res = await request(app).get('/v1/transfers/verify/TRF-BANK-001');
    expect(res.status).toBe(401);
  });

  it('GET /v1/transfers/resolve-account falls back to TEST USER (SANDBOX) in test mode on Paystack limit error', async () => {
    config.paystackSecretKey = 'sk_test_1234567890abcdef';
    const originalFetch = global.fetch;

    global.fetch = jest.fn().mockImplementation(async () => ({
      ok: false,
      status: 400,
      json: async () => ({
        status: false,
        message: 'Test mode daily limit of 3 live bank resolves exceeded. Use test bank codes 001 or upgrade to live mode.',
      }),
    })) as any;

    try {
      const res = await request(app)
        .get('/v1/transfers/resolve-account?accountNumber=0123456789&bankCode=058')
        .set('Authorization', 'Bearer valid_token');

      expect(res.status).toBe(200);
      expect(res.body.status).toBe(true);
      expect(res.body.account_name).toBe('TEST USER (SANDBOX)');
      expect(res.body.data.account_name).toBe('TEST USER (SANDBOX)');
      expect(res.body.account_number).toBe('0123456789');
    } finally {
      global.fetch = originalFetch;
    }
  });

  it('POST /v1/transfers/bank gracefully succeeds with internal wallet debit when Paystack transfer fails in test mode', async () => {
    config.paystackSecretKey = 'sk_test_1234567890abcdef';
    const originalNodeEnv = config.nodeEnv;
    config.nodeEnv = 'development';
    const originalFetch = global.fetch;

    global.fetch = jest.fn().mockImplementation(async (url: string) => {
      if (url.includes('transferrecipient')) {
        return {
          ok: false,
          status: 400,
          json: async () => ({
            status: false,
            message: 'Test mode daily limit exceeded or test balance unavailable',
          }),
        };
      }
      return {
        ok: true,
        status: 200,
        json: async () => ({ status: true, data: { status: 'success' } }),
      };
    }) as any;

    try {
      const res = await request(app)
        .post('/v1/transfers/bank')
        .set('Authorization', 'Bearer valid_token')
        .send({
          accountNumber: '0123456789',
          bankCode: '058',
          bankName: 'GTBank',
          amount: 25000,
          narration: 'Sandbox fallback transfer',
          accountName: 'TEST USER (SANDBOX)',
        });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe(true);
      expect(res.body.data.recipient.account_number).toBe('0123456789');
      expect(res.body.data.newBalance).toBe(975000);
    } finally {
      config.nodeEnv = originalNodeEnv;
      global.fetch = originalFetch;
    }
  });
});


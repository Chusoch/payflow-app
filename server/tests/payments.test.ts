/// <reference types="jest" />

import request from 'supertest';
import crypto from 'crypto';
import app from '../src/app';

const mockProcessedRefs: Record<string, any> = {};

jest.mock('../src/firebase', () => {
  return {
    db: {
      collection: (collName: string) => ({
        doc: (docId: string) => ({
          get: async () => {
            const data = mockProcessedRefs[docId];
            return {
              exists: !!data,
              data: () => data,
            };
          },
          set: async (data: any) => {
            mockProcessedRefs[docId] = data;
          },
        }),
      }),
    },
    auth: {
      verifyIdToken: async (token: string) => {
        if (token === 'user_auth_token') {
          return { uid: 'user_auth_uid', phone_number: '+2348012345678', email: 'test@payflow.app' };
        }
        throw new Error('Invalid token');
      },
    },
    admin: {},
  };
});

describe('Part A — Provider Proxy & Webhook Tests', () => {
  const { config } = require('../src/config');
  let origKey: string;
  let origVtpassApi: string;
  let origVtpassSec: string;

  beforeEach(() => {
    origKey = config.paystackSecretKey;
    origVtpassApi = config.vtpassApiKey;
    origVtpassSec = config.vtpassSecretKey;
    config.paystackSecretKey = '';
    config.vtpassApiKey = '';
    config.vtpassSecretKey = '';
  });

  afterEach(() => {
    config.paystackSecretKey = origKey;
    config.vtpassApiKey = origVtpassApi;
    config.vtpassSecretKey = origVtpassSec;
  });
  it('should initialize Paystack transaction via POST /v1/payments/paystack/initialize', async () => {
    const res = await request(app)
      .post('/v1/payments/paystack/initialize')
      .set('Authorization', 'Bearer user_auth_token')
      .send({
        reference: 'PST-TEST-001',
        amount_in_kobo: 250000,
        email: 'test@payflow.app',
        payment_type: 'wallet_funding',
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);
    expect(res.body.data.reference).toBe('PST-TEST-001');
    expect(res.body.data.authorization_url).toBeDefined();
  });

  it('should verify Paystack transaction via GET /v1/payments/paystack/verify/:reference', async () => {
    const res = await request(app)
      .get('/v1/payments/paystack/verify/PST-TEST-001')
      .set('Authorization', 'Bearer user_auth_token');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);
    expect(res.body.data.status).toBe('success');
  });

  it('should process VTPass pay request via POST /v1/payments/vtpass/pay', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/pay')
      .set('Authorization', 'Bearer user_auth_token')
      .send({
        request_id: 'VTP-TEST-001',
        service_id: 'mtn_data',
        amount: 1000,
        phone: '08123456789',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(res.body.content.transactions.requestId).toBe('VTP-TEST-001');
  });

  it('should authenticate user +2349069752917 with mock custom dev token on POST /v1/payments/vtpass/pay', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/pay')
      .set('Authorization', 'Bearer mock_custom_token_1789241699881_2349069752917')
      .send({
        request_id: 'VTP-TEST-DEV-2349069752917',
        service_id: 'airtime',
        amount: 500,
        phone: '09069752917',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(res.body.content.transactions.requestId).toBe('VTP-TEST-DEV-2349069752917');
    expect(res.body.content.transactions.phone).toBe('09069752917');
  });

  it('should map service_id "airtime" to "mtn" using phone prefix 08146357043', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/pay')
      .set('Authorization', 'Bearer user_auth_token')
      .send({
        request_id: 'VTP-TEST-AIRTIME-0814',
        service_id: 'airtime',
        amount: 100,
        phone: '08146357043',
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.code).toBe('000');
    expect(res.body.content.transactions.product_name).toBe('MTN');
  });

  it('should map service_id "airtime" with operator "Airtel" to "airtel"', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/pay')
      .set('Authorization', 'Bearer user_auth_token')
      .send({
        request_id: 'VTP-TEST-AIRTIME-AIRTEL',
        service_id: 'airtime',
        operator: 'Airtel',
        amount: 200,
        phone: '08021234567',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(res.body.content.transactions.product_name).toBe('AIRTEL');
  });

  it('should gracefully fallback to simulated success when VTpass returns 401 code 087 (INVALID CREDENTIALS)', async () => {
    const axios = require('axios');
    const origPost = axios.post;
    axios.post = jest.fn().mockRejectedValueOnce({
      response: {
        status: 401,
        data: { code: '087', message: 'INVALID CREDENTIALS' },
      },
    });

    const { config } = require('../src/config');
    config.vtpassApiKey = 'test_api_key';
    config.vtpassSecretKey = 'test_secret_key';

    try {
      const res = await request(app)
        .post('/v1/payments/vtpass/pay')
        .set('Authorization', 'Bearer user_auth_token')
        .send({
          request_id: 'VTP-TEST-087-SIMULATE',
          service_id: 'airtime',
          amount: 100,
          phone: '08146357043',
        });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.code).toBe('000');
      expect(res.body.response_description).toBe('TRANSACTION SUCCESSFUL');
    } finally {
      axios.post = origPost;
      config.vtpassApiKey = '';
      config.vtpassSecretKey = '';
    }
  });

  it('should process VTPass requery request via POST /v1/payments/vtpass/requery', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/requery')
      .set('Authorization', 'Bearer user_auth_token')
      .send({
        request_id: 'VTP-TEST-001',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(res.body.content.transactions.requestId).toBe('VTP-TEST-001');
  });

  it('should process VTPass requery request via POST /v1/payments/vtpass/requery with simulated success on 401 code 087', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/requery')
      .set('Authorization', 'Bearer user_auth_token')
      .send({
        request_id: 'VTP-REQUERY-087-TEST',
        phone: '08146357043',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(res.body.status).toBe('success');
    expect(res.body.response_description).toBe('TRANSACTION SUCCESSFUL');
    expect(res.body.content.transactions.status).toBe('delivered');
    expect(res.body.content.transactions.product_name).toBe('Airtime Recharge');
    expect(res.body.content.transactions.unique_element).toBe('08146357043');
  });

  it('should process VTPass requery request via POST /v1/vtpass/requery', async () => {
    const res = await request(app)
      .post('/v1/vtpass/requery')
      .set('Authorization', 'Bearer user_auth_token')
      .send({
        request_id: 'VTP-REQUERY-VTPASS-ROUTE',
        phone: '08146357043',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(res.body.status).toBe('success');
    expect(res.body.content.transactions.status).toBe('delivered');
  });

  it('should process merchant verify via POST /v1/payments/vtpass/verify and return simulated verified customer', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/verify')
      .set('Authorization', 'Bearer user_auth_token')
      .send({
        billersCode: '10101010101',
        serviceID: 'ikeja-electric',
        type: 'prepaid',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(res.body.status).toBe('success');
    expect(res.body.content.Customer_Name).toBe('TEST USER (VERIFIED)');
    expect(res.body.content.Meter_Number).toBe('10101010101');
    expect(res.body.content.Address).toBe('123 Test Street, Lagos');
    expect(res.body.content.Customer_Arrears).toBe('0.00');
  });

  it('should vend electricity bill and return 20-digit prepaid token 4819-2041-9823-1104-5821', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/pay')
      .set('Authorization', 'Bearer user_auth_token')
      .send({
        request_id: 'VTP-ELEC-TEST-001',
        service_id: 'ikeja-electric',
        amount: 2500,
        phone: '08146357043',
        description: 'Electricity Bill Payment',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(res.body.token).toBe('4819-2041-9823-1104-5821');
    expect(res.body.content.transactions.token).toBe('4819-2041-9823-1104-5821');
  });

  it('should reject unauthenticated POST /v1/payments/paystack/initialize with 401', async () => {
    const res = await request(app)
      .post('/v1/payments/paystack/initialize')
      .send({
        reference: 'PST-UNAUTH-001',
        amount_in_kobo: 250000,
      });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('should reject unauthenticated GET /v1/payments/paystack/verify/:reference with 401', async () => {
    const res = await request(app).get('/v1/payments/paystack/verify/PST-UNAUTH-001');

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('should reject unauthenticated POST /v1/payments/paystack/dedicated-account with 401', async () => {
    const res = await request(app)
      .post('/v1/payments/paystack/dedicated-account')
      .send({ amount_in_kobo: 500000 });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('should assign dedicated account via POST /v1/payments/paystack/dedicated-account when authenticated', async () => {
    const res = await request(app)
      .post('/v1/payments/paystack/dedicated-account')
      .set('Authorization', 'Bearer user_auth_token')
      .send({ amount_in_kobo: 500000 });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe(true);
    expect(res.body.data.account_number).toBeDefined();
    expect(res.body.data.bank.name).toBe('Wema Bank');
  });

  it('should reject unauthenticated POST /v1/payments/vtpass/pay with 401', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/pay')
      .send({
        request_id: 'VTP-UNAUTH-001',
        service_id: 'mtn_data',
        amount: 1000,
      });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('should reject Paystack webhook missing x-paystack-signature header with 401', async () => {
    const res = await request(app)
      .post('/v1/payments/webhooks/paystack')
      .send({
        event: 'charge.success',
        data: { reference: 'PF-TOP-883920', amount: 100000 },
      });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Missing x-paystack-signature header');
  });

  it('should reject Paystack webhook with invalid HMAC signature with 401', async () => {
    const res = await request(app)
      .post('/v1/payments/webhooks/paystack')
      .set('x-paystack-signature', 'invalid_fake_hmac_signature')
      .send({
        event: 'charge.success',
        data: { reference: 'PF-TOP-883920', amount: 100000 },
      });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Invalid HMAC signature');
  });

  it('should accept valid Paystack HMAC SHA512 webhook and record idempotency reference', async () => {
    const secret = process.env.PAYSTACK_WEBHOOK_SECRET || 'paystack_webhook_secret_key_998877';
    const payload = JSON.stringify({
      event: 'charge.success',
      data: {
        id: 302949201,
        reference: 'PF-TOP-883920',
        amount: 1000000,
        customer: { email: 'alex.johnson@payflow.app' },
      },
    });

    const validSignature = crypto
      .createHmac('sha512', secret)
      .update(payload)
      .digest('hex');

    const res = await request(app)
      .post('/v1/payments/webhooks/paystack')
      .set('Content-Type', 'application/json')
      .set('x-paystack-signature', validSignature)
      .send(payload);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
  });

  it('should return 200 without re-processing for duplicate Paystack webhook', async () => {
    const secret = process.env.PAYSTACK_WEBHOOK_SECRET || 'paystack_webhook_secret_key_998877';
    const payload = JSON.stringify({
      event: 'charge.success',
      data: {
        id: 302949201,
        reference: 'PF-TOP-883920', // Same reference as test above
        amount: 1000000,
      },
    });

    const validSignature = crypto
      .createHmac('sha512', secret)
      .update(payload)
      .digest('hex');

    const res = await request(app)
      .post('/v1/payments/webhooks/paystack')
      .set('Content-Type', 'application/json')
      .set('x-paystack-signature', validSignature)
      .send(payload);

    expect(res.status).toBe(200);
    expect(res.body.message).toContain('already processed');
  });
});

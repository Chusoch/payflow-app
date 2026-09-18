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

  const mockDb = {
    collection: (_collName: string) => ({
      doc: (_docId: string) => ({
        get: async () => ({ exists: false, data: () => null }),
      }),
    }),
  };

  return {
    db: mockDb,
    auth: mockAuth,
    admin: { auth: () => mockAuth, firestore: () => mockDb },
  };
});

describe('VTPass Services & Data Plans Proxy Endpoints', () => {
  const { config } = require('../src/config');
  let origApiKey: string;
  let origSecretKey: string;

  beforeEach(() => {
    origApiKey = config.vtpassApiKey;
    origSecretKey = config.vtpassSecretKey;
    config.vtpassApiKey = '';
    config.vtpassSecretKey = '';
  });

  afterEach(() => {
    config.vtpassApiKey = origApiKey;
    config.vtpassSecretKey = origSecretKey;
  });
  it('GET /v1/vtpass/services rejects unauthenticated request with 401 (no auth header)', async () => {
    const res = await request(app).get('/v1/vtpass/services?identifier=airtime');

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('GET /v1/vtpass/data-plans rejects unauthenticated request with 401 (no auth header)', async () => {
    const res = await request(app).get('/v1/vtpass/data-plans?network=mtn');

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('POST /v1/vtpass/verify-meter rejects unauthenticated request with 401 (no auth header)', async () => {
    const res = await request(app)
      .post('/v1/vtpass/verify-meter')
      .send({ billersCode: '10101010101', serviceID: 'ikeja-electric', type: 'prepaid' });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('POST /v1/vtpass/verify-smartcard rejects unauthenticated request with 401 (no auth header)', async () => {
    const res = await request(app)
      .post('/v1/vtpass/verify-smartcard')
      .send({ billersCode: '1212121212', serviceID: 'dstv' });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('GET /v1/vtpass/billers rejects unauthenticated request with 401 (no auth header)', async () => {
    const res = await request(app).get('/v1/vtpass/billers?category=electricity');

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('POST /v1/payments/vtpass/requery rejects unauthenticated request with 401 (no auth header)', async () => {
    const res = await request(app)
      .post('/v1/payments/vtpass/requery')
      .send({ request_id: 'VTP-REQ-001' });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('GET /v1/vtpass/services returns service categories when authenticated', async () => {
    const res = await request(app)
      .get('/v1/vtpass/services?identifier=data')
      .set('Authorization', 'Bearer valid_token');

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(Array.isArray(res.body.content)).toBe(true);
    expect(res.body.content.length).toBeGreaterThan(0);
  });

  it('GET /v1/vtpass/data-plans returns data plans for network when authenticated', async () => {
    const res = await request(app)
      .get('/v1/vtpass/data-plans?network=glo')
      .set('Authorization', 'Bearer valid_token');

    expect(res.status).toBe(200);
    expect(res.body.response_description).toBe('000');
    expect(res.body.content.serviceID).toBe('glo-data');
    expect(Array.isArray(res.body.content.varations)).toBe(true);
    expect(res.body.content.varations.length).toBeGreaterThan(0);
  });

  it('POST /v1/vtpass/verify-meter returns customer details when authenticated', async () => {
    const res = await request(app)
      .post('/v1/vtpass/verify-meter')
      .set('Authorization', 'Bearer valid_token')
      .send({ billersCode: '10101010101', serviceID: 'ikeja-electric', type: 'prepaid' });

    expect(res.status).toBe(200);
    expect(res.body.response_description).toBe('SUCCESSFUL');
    expect(res.body.content.Customer_Name).toBe('TEST USER (VERIFIED)');
    expect(res.body.content.Meter_Number).toBe('10101010101');
    expect(res.body.content.Address).toBe('123 Test Street, Lagos');
  });

  it('POST /v1/vtpass/verify-smartcard returns customer details when authenticated', async () => {
    const res = await request(app)
      .post('/v1/vtpass/verify-smartcard')
      .set('Authorization', 'Bearer valid_token')
      .send({ billersCode: '1212121212', serviceID: 'dstv' });

    expect(res.status).toBe(200);
    expect(res.body.response_description).toBe('SUCCESSFUL');
    expect(res.body.content.Customer_Name).toBe('TEST USER (VERIFIED)');
    expect(res.body.content.Customer_Number).toBe('1212121212');
  });

  it('GET /v1/vtpass/billers returns biller categories when authenticated', async () => {
    const res = await request(app)
      .get('/v1/vtpass/billers?category=tv')
      .set('Authorization', 'Bearer valid_token');

    expect(res.status).toBe(200);
    expect(res.body.response_description).toBe('SUCCESSFUL');
    expect(Array.isArray(res.body.content)).toBe(true);
    expect(res.body.content.length).toBeGreaterThan(0);
  });

  it('routes HTTP calls to https://sandbox.vtpass.com/api when credentials are set', async () => {
    const { config } = require('../src/config');
    config.vtpassApiKey = 'real_sandbox_api_key';
    config.vtpassSecretKey = 'real_sandbox_secret_key';

    const globalFetch = global.fetch;
    let fetchedUrl = '';

    global.fetch = (async (url: string, init?: any) => {
      fetchedUrl = url;
      return {
        ok: true,
        status: 200,
        json: async () => ({ code: '000', content: [] }),
      } as any;
    }) as any;

    try {
      const res = await request(app)
        .get('/v1/vtpass/services?identifier=data')
        .set('Authorization', 'Bearer valid_token');

      expect(res.status).toBe(200);
      expect(fetchedUrl).toContain('https://sandbox.vtpass.com/api/service-categories');
    } finally {
      global.fetch = globalFetch;
      config.vtpassApiKey = '';
      config.vtpassSecretKey = '';
    }
  });

  it('POST /v1/vtpass/pay rejects unauthenticated request with 401', async () => {
    const res = await request(app)
      .post('/v1/vtpass/pay')
      .send({
        request_id: 'VTP-UNAUTH-999',
        service_id: 'airtime',
        amount: 1000,
      });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('POST /v1/vtpass/pay processes vending request when authenticated', async () => {
    const res = await request(app)
      .post('/v1/vtpass/pay')
      .set('Authorization', 'Bearer valid_token')
      .send({
        request_id: 'VTP-AUTH-999',
        service_id: 'airtime',
        amount: 1000,
        phone: '09069752917',
      });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe('000');
    expect(res.body.content.transactions.requestId).toBe('VTP-AUTH-999');
  });
});

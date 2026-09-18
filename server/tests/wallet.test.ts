/// <reference types="jest" />

import request from 'supertest';
import app from '../src/app';
import * as ledger from '../src/services/ledger';

// In-Memory Data Store simulating Firestore for integration testing
const mockUsers: Record<string, { walletBalance: number }> = {
  '+2348011111111': { walletBalance: 100000 }, // ₦1,000.00 (100,000 kobo)
  '+2348022222222': { walletBalance: 20000 },  // ₦200.00 (20,000 kobo)
};

const mockProcessedRefs: Record<string, any> = {};

const mockTransactions: Record<string, any> = {};

jest.mock('../src/firebase', () => {
  return {
    db: {
      collection: (collName: string) => ({
        doc: (docId: string) => ({
          collection: (subCollName: string) => {
            const sub = {
              doc: (subDocId: string) => ({
                get: async () => {
                  const key = `${collName}/${docId}/${subCollName}/${subDocId}`;
                  const data = mockTransactions[key];
                  return { exists: !!data, data: () => data };
                },
                set: async (data: any) => {
                  const key = `${collName}/${docId}/${subCollName}/${subDocId}`;
                  mockTransactions[key] = data;
                },
              }),
              add: async (data: any) => {
                const subDocId = `mock-doc-${Date.now()}-${Math.random()}`;
                const key = `${collName}/${docId}/${subCollName}/${subDocId}`;
                mockTransactions[key] = data;
                return { id: subDocId };
              },
              orderBy: (field: string, dir?: string) => sub,
              limit: (n: number) => sub,
              get: async () => {
                const prefix = `${collName}/${docId}/${subCollName}/`;
                const docs = Object.keys(mockTransactions)
                  .filter((k) => k.startsWith(prefix))
                  .map((k) => ({
                    id: k.replace(prefix, ''),
                    data: () => mockTransactions[k],
                  }));
                return { empty: docs.length === 0, docs };
              },
            };
            return sub;
          },
          get: async () => {
            if (collName === 'users') {
              const data = mockUsers[docId];
              return {
                exists: !!data,
                data: () => data,
              };
            }
            if (collName === 'processed_references') {
              const data = mockProcessedRefs[docId];
              return {
                exists: !!data,
                data: () => data,
              };
            }
            return { exists: false, data: () => null };
          },
          set: async (data: any) => {
            if (collName === 'users') mockUsers[docId] = data;
            if (collName === 'processed_references') mockProcessedRefs[docId] = data;
          },
          update: async (data: any) => {
            if (collName === 'users' && mockUsers[docId]) {
              mockUsers[docId] = { ...mockUsers[docId], ...data };
            }
          },
        }),
      }),
      runTransaction: async (updateFunction: (transaction: any) => Promise<any>) => {
        const transactionMock = {
          get: async (docRef: any) => docRef.get(),
          update: (docRef: any, data: any) => docRef.update(data),
          set: (docRef: any, data: any) => docRef.set(data),
        };
        return updateFunction(transactionMock);
      },
    },
    auth: {
      verifyIdToken: async (token: string) => {
        if (token === 'user_a_token') {
          return { uid: '+2348011111111', phone_number: '+2348011111111', email: 'a@payflow.app' };
        }
        if (token === 'user_b_token') {
          return { uid: '+2348022222222', phone_number: '+2348022222222', email: 'b@payflow.app' };
        }
        throw new Error('Invalid token');
      },
      getUser: async (uid: string) => ({ uid, phoneNumber: uid }),
    },
    admin: {},
  };
});

describe('Part B — P2P Wallet Ledger Integration Tests', () => {
  it('should reject transfer when sender has insufficient balance', async () => {
    // User B only has 20,000 kobo (₦200). Attempting transfer of 50,000 kobo (₦500)
    const res = await request(app)
      .post('/v1/wallet/transfer')
      .set('Authorization', 'Bearer user_b_token')
      .send({
        toPhone: '+2348033333333',
        amount_kobo: 50000,
        reference: 'REF-INSUFFICIENT-001',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('Insufficient balance');
  });

  it('should reject duplicate transaction reference with 409 Conflict', async () => {
    const ref = 'REF-DUP-TEST-001';

    // First Transfer succeeds
    const res1 = await request(app)
      .post('/v1/wallet/transfer')
      .set('Authorization', 'Bearer user_a_token')
      .send({
        toPhone: '+2348022222222',
        amount_kobo: 10000,
        reference: ref,
      });

    expect(res1.status).toBe(200);

    // Second Transfer with same reference fails with 409 Conflict
    const res2 = await request(app)
      .post('/v1/wallet/transfer')
      .set('Authorization', 'Bearer user_a_token')
      .send({
        toPhone: '+2348022222222',
        amount_kobo: 10000,
        reference: ref,
      });

    expect(res2.status).toBe(409);
    expect(res2.body.error).toContain('already been processed');
  });

  it('should handle concurrent transfer race condition (only one succeeds if balance covers only one)', async () => {
    // Set User B balance to 15,000 kobo (₦150)
    mockUsers['+2348022222222'].walletBalance = 15000;

    // Fire two simultaneous transfers of 10,000 kobo each (Total required: 20,000 kobo)
    const transfer1 = request(app)
      .post('/v1/wallet/transfer')
      .set('Authorization', 'Bearer user_b_token')
      .send({ toPhone: '+2348033333333', amount_kobo: 10000, reference: 'REF-RACE-A' });

    const transfer2 = request(app)
      .post('/v1/wallet/transfer')
      .set('Authorization', 'Bearer user_b_token')
      .send({ toPhone: '+2348044444444', amount_kobo: 10000, reference: 'REF-RACE-B' });

    const [res1, res2] = await Promise.all([transfer1, transfer2]);

    const statusCodes = [res1.status, res2.status].sort();
    // Exactly one transaction succeeds (200) and one fails due to insufficient balance (400)
    expect(statusCodes).toEqual([200, 400]);
  });

  it('should return balance for authenticated user via GET /v1/wallet/balance/me', async () => {
    const res = await request(app)
      .get('/v1/wallet/balance/me')
      .set('Authorization', 'Bearer user_a_token');

    expect(res.status).toBe(200);
    expect(res.body.phone).toBe('+2348011111111');
    expect(typeof res.body.walletBalance).toBe('number');
  });

  it('should return 404 for removed GET /v1/wallet/balance/:phone endpoint', async () => {
    const res = await request(app)
      .get('/v1/wallet/balance/+2348011111111')
      .set('Authorization', 'Bearer user_a_token');

    expect(res.status).toBe(404);
  });

  it('should reject unauthenticated POST /v1/wallet/transfer with 401', async () => {
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

  it('should reject unauthenticated GET /v1/wallet/balance/me with 401', async () => {
    const res = await request(app).get('/v1/wallet/balance/me');

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('should reject unauthenticated POST /v1/wallet/seed with 401', async () => {
    const res = await request(app)
      .post('/v1/wallet/seed')
      .send({
        phone: '+2348099999999',
        amount_kobo: 500000,
      });

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Unauthorized');
  });

  it('should allow dev seeding via POST /v1/wallet/seed when authenticated', async () => {
    const res = await request(app)
      .post('/v1/wallet/seed')
      .set('Authorization', 'Bearer user_a_token')
      .send({
        phone: '+2348099999999',
        amount_kobo: 500000,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.phone).toBe('+2348099999999');
    expect(res.body.walletBalance).toBe(500000);
  });
});

describe('Part C — Paystack Wallet Funding Integration Tests', () => {
  const testPhone = '+2348011111111';

  it('should validate inputs for /v1/wallet/initialize-funding', async () => {
    // Missing amount
    const res1 = await request(app)
      .post('/v1/wallet/initialize-funding')
      .send({ phoneNumber: testPhone });
    expect(res1.status).toBe(400);
    expect(res1.body.error).toContain('Valid positive amount');

    // Missing phoneNumber
    const res2 = await request(app)
      .post('/v1/wallet/initialize-funding')
      .send({ amount: 1000 });
    expect(res2.status).toBe(400);
    expect(res2.body.error).toContain('phoneNumber is required');
  });

  it('should initialize funding and return authorization_url and reference', async () => {
    const res = await request(app)
      .post('/v1/wallet/initialize-funding')
      .send({
        email: 'tester@payflow.app',
        amount: 2500, // ₦2,500
        phoneNumber: testPhone,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.authorization_url).toBeDefined();
    expect(res.body.reference).toBeDefined();
    expect(res.body.reference).toMatch(/^PF_FUND_\d+_/);
  });

  it('should validate inputs for /v1/wallet/verify-funding', async () => {
    // Missing reference
    const res1 = await request(app)
      .post('/v1/wallet/verify-funding')
      .send({ phoneNumber: testPhone });
    expect(res1.status).toBe(400);
    expect(res1.body.error).toContain('reference is required');

    // Missing phoneNumber
    const res2 = await request(app)
      .post('/v1/wallet/verify-funding')
      .send({ reference: 'PF_FUND_123456_2348011111111' });
    expect(res2.status).toBe(400);
    expect(res2.body.error).toContain('phoneNumber is required');
  });

  it('should verify funding, increment wallet balance, and record transaction', async () => {
    const initialBalance = mockUsers[testPhone]?.walletBalance || 0;
    const testRef = `PF_FUND_TEST_${Date.now()}_${testPhone.replace(/\+/g, '')}`;

    const res = await request(app)
      .post('/v1/wallet/verify-funding')
      .send({
        reference: testRef,
        phoneNumber: testPhone,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.status).toBe('success');
    expect(res.body.reference).toBe(testRef);
    expect(res.body.walletBalance).toBeGreaterThan(initialBalance);

    // Verify transaction recorded
    const txKey = `users/${testPhone}/transactions/${testRef}`;
    expect(mockTransactions[txKey]).toBeDefined();
    expect(mockTransactions[txKey].status).toBe('successful');
    expect(mockTransactions[txKey].type).toBe('credit');
    expect(mockTransactions[txKey].channel).toBe('paystack');

    // Test idempotency: calling again should return alreadyProcessed: true without double credit
    const resIdempotent = await request(app)
      .post('/v1/wallet/verify-funding')
      .send({
        reference: testRef,
        phoneNumber: testPhone,
      });

    expect(resIdempotent.status).toBe(200);
    expect(resIdempotent.body.alreadyProcessed).toBe(true);
    expect(resIdempotent.body.walletBalance).toBe(res.body.walletBalance);
  });
});

describe('Part D — Standardized Balance & Phone Normalization Unit Tests', () => {
  it('should normalize varied Nigerian phone formats to standard E.164 (+234...)', () => {
    expect(ledger.normalizePhone('08012345678')).toBe('+2348012345678');
    expect(ledger.normalizePhone('8012345678')).toBe('+2348012345678');
    expect(ledger.normalizePhone('2348012345678')).toBe('+2348012345678');
    expect(ledger.normalizePhone('+2348012345678')).toBe('+2348012345678');
    expect(ledger.normalizePhone('+23408012345678')).toBe('+2348012345678');
    expect(ledger.normalizePhone('23408012345678')).toBe('+2348012345678');
  });

  it('should extract balance in integer kobo using getBalanceKobo across all field variants', () => {
    expect(ledger.getBalanceKobo({ walletBalance: 100000 })).toBe(100000);
    expect(ledger.getBalanceKobo({ balanceInKobo: 75000 })).toBe(75000);
    expect(ledger.getBalanceKobo({ balance: 50000 })).toBe(50000);
    expect(ledger.getBalanceKobo({ walletBalance: '100000' })).toBe(100000);
    expect(ledger.getBalanceKobo({ balanceInKobo: '75000' })).toBe(75000);
    expect(ledger.getBalanceKobo({})).toBe(0);
    expect(ledger.getBalanceKobo(null)).toBe(0);
  });

  it('should transfer successfully and atomically set walletBalance, balanceInKobo, and balance', async () => {
    // Seed User A with balance
    mockUsers['+2348011111111'] = {
      walletBalance: 100000,
      balanceInKobo: 100000,
      balance: 100000,
    } as any;

    const ref = `REF-BALANCE-UNIT-${Date.now()}`;
    const result = await ledger.executeTransfer({
      fromPhone: '+2348011111111',
      toPhone: '08022222222', // Local format gets normalized
      amount_kobo: 10000, // ₦100 (10,000 kobo)
      reference: ref,
    });

    expect(result.success).toBe(true);
    expect(result.amount_kobo).toBe(10000);
    expect(result.newBalance).toBe(90000);

    // Verify standardized balance fields on sender
    expect(mockUsers['+2348011111111'].walletBalance).toBe(90000);
    expect((mockUsers['+2348011111111'] as any).balanceInKobo).toBe(90000);
    expect((mockUsers['+2348011111111'] as any).balance).toBe(90000);

    // Verify standardized balance fields on recipient
    expect(mockUsers['+2348022222222'].walletBalance).toBeGreaterThanOrEqual(10000);
  });

  it('should support sender document with balance under balanceInKobo or balance alias', async () => {
    // Setup sender whose balance is in balanceInKobo
    mockUsers['+2348055555555'] = {
      balanceInKobo: 50000,
    } as any;

    const ref = `REF-ALIAS-TEST-${Date.now()}`;
    const result = await ledger.executeTransfer({
      fromPhone: '+2348055555555',
      toPhone: '+2348066666666',
      amount_kobo: 15000,
      reference: ref,
    });

    expect(result.success).toBe(true);
    expect(result.newBalance).toBe(35000);
    expect(mockUsers['+2348055555555'].walletBalance).toBe(35000);
  });
});

describe('Part E — Transfer History Logging & Real-Time Feed Tests', () => {
  it('should log transaction to sender and recipient sub-collections on executeTransfer', async () => {
    // Seed sender with sufficient balance
    mockUsers['+2348011111111'] = {
      walletBalance: 100000,
      fullName: 'Sender User',
    } as any;
    mockUsers['+2348022222222'] = {
      walletBalance: 50000,
      fullName: 'Recipient User',
    } as any;

    const ref = `PF-TRF-HIST-${Date.now()}`;
    const result = await ledger.executeTransfer({
      fromPhone: '+2348011111111',
      toPhone: '+2348022222222',
      amount_kobo: 25000,
      reference: ref,
      recipientName: 'Ugobueze Sochima',
    });

    expect(result.success).toBe(true);

    // Verify sender transaction record
    const senderTxKey = `users/+2348011111111/transactions/${ref}`;
    const senderTx = mockTransactions[senderTxKey];
    expect(senderTx).toBeDefined();
    expect(senderTx.id).toBe(ref);
    expect(senderTx.title).toBe('Transfer to Ugobueze Sochima');
    expect(senderTx.amount).toBe(25000);
    expect(senderTx.amountInKobo).toBe(25000);
    expect(senderTx.amountNaira).toBe(250);
    expect(senderTx.type).toBe('debit');
    expect(senderTx.category).toBe('transfer');
    expect(senderTx.status).toBe('Completed');
    expect(senderTx.createdAt).toBeDefined();
    expect(senderTx.timestamp).toBeDefined();

    // Verify recipient transaction record
    const recipientTxKey = `users/+2348022222222/transactions/${ref}`;
    const recipientTx = mockTransactions[recipientTxKey];
    expect(recipientTx).toBeDefined();
    expect(recipientTx.id).toBe(ref);
    expect(recipientTx.title).toContain('Transfer from');
    expect(recipientTx.amount).toBe(25000);
    expect(recipientTx.type).toBe('credit');
    expect(recipientTx.category).toBe('transfer');
    expect(recipientTx.status).toBe('Completed');
    expect(recipientTx.createdAt).toBeDefined();

    // Verify recipient notification record in Firestore
    const recipientNotifKeys = Object.keys(mockTransactions).filter((k) =>
      k.startsWith('users/+2348022222222/notifications/')
    );
    expect(recipientNotifKeys.length).toBeGreaterThan(0);
    const recipientNotif = mockTransactions[recipientNotifKeys[recipientNotifKeys.length - 1]];
    expect(recipientNotif.title).toBe('Transfer Received');
    expect(recipientNotif.body).toContain('received from');
    expect(recipientNotif.type).toBe('transfer_credit');
    expect(recipientNotif.amount).toBe(250);
    expect(recipientNotif.read).toBe(false);

    // Verify sender notification record in Firestore
    const senderNotifKeys = Object.keys(mockTransactions).filter((k) =>
      k.startsWith('users/+2348011111111/notifications/')
    );
    expect(senderNotifKeys.length).toBeGreaterThan(0);
    const senderNotif = mockTransactions[senderNotifKeys[senderNotifKeys.length - 1]];
    expect(senderNotif.title).toBe('Transfer Successful');
    expect(senderNotif.body).toContain('sent to');
    expect(senderNotif.type).toBe('transfer_debit');
    expect(senderNotif.amount).toBe(250);
    expect(senderNotif.read).toBe(false);
  });

  it('GET /v1/wallet/transactions returns authenticated user transactions ordered and limited to 20', async () => {
    // Seed 25 transactions for User A in mockTransactions
    const baseTime = Date.now();
    for (let i = 1; i <= 25; i++) {
      const txRef = `PF-TEST-TX-${i}`;
      mockTransactions[`users/+2348011111111/transactions/${txRef}`] = {
        id: txRef,
        reference: txRef,
        title: `Test Transaction ${i}`,
        amount: i * 1000,
        amountInKobo: i * 1000,
        amountNaira: i * 10,
        type: i % 2 === 0 ? 'credit' : 'debit',
        category: 'transfer',
        status: 'Completed',
        createdAt: new Date(baseTime + i * 1000).toISOString(),
        timestamp: new Date(baseTime + i * 1000).toISOString(),
      };
    }

    const res = await request(app)
      .get('/v1/wallet/transactions')
      .set('Authorization', 'Bearer user_a_token');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.transactions)).toBe(true);
    // Limit to 20
    expect(res.body.transactions.length).toBe(20);

    // Verify descending order: first item should have higher timestamp than second item
    const firstDate = new Date(res.body.transactions[0].createdAt).getTime();
    const secondDate = new Date(res.body.transactions[1].createdAt).getTime();
    expect(firstDate).toBeGreaterThanOrEqual(secondDate);

    // Verify standardized fields
    const firstTx = res.body.transactions[0];
    expect(firstTx.id).toBeDefined();
    expect(firstTx.title).toBeDefined();
    expect(firstTx.amount).toBeDefined();
    expect(firstTx.amountNaira).toBeDefined();
    expect(firstTx.type).toBeDefined();
    expect(firstTx.category).toBeDefined();
    expect(firstTx.status).toBe('Completed');
  });

  it('GET /v1/wallet/transactions rejects unauthenticated request with 401', async () => {
    const res = await request(app).get('/v1/wallet/transactions');
    expect(res.status).toBe(401);
  });
});


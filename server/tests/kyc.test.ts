import crypto from 'crypto';
import request from 'supertest';
import app from '../src/app';
import { resetKycRateLimits } from '../src/routes/kyc';
import { config } from '../src/config';

const ninHash222 = crypto.createHash('sha256').update('22222222222').digest('hex');
const bvnHash222 = crypto.createHash('sha256').update('22222222222').digest('hex');

const mockFirestoreUsers: Record<string, any> = {
  '+2348011111111': {
    phoneNumber: '+2348011111111',
    fullName: 'Chukwuma Ugobueze',
    ninHash: ninHash222,
    bvnHash: bvnHash222,
    isKycVerified: true,
    kycProvider: 'dojah',
  },
};

jest.mock('../src/firebase', () => {
  const mockAuth = {
    verifyIdToken: async (token: string) => {
      if (token === 'valid_user_token') {
        return { uid: '+2348011111111', phone_number: '+2348011111111' };
      }
      throw new Error('Invalid authentication token');
    },
  };

  const mockDb = {
    collection: (collName: string) => ({
      doc: (docId: string) => ({
        get: async () => {
          if (collName === 'users' && mockFirestoreUsers[docId]) {
            return {
              exists: true,
              data: () => ({ ...mockFirestoreUsers[docId] }),
            };
          }
          return { exists: false, data: () => null };
        },
        set: async (data: any, options?: any) => {
          if (collName === 'users') {
            if (options?.merge && mockFirestoreUsers[docId]) {
              mockFirestoreUsers[docId] = { ...mockFirestoreUsers[docId], ...data };
            } else {
              mockFirestoreUsers[docId] = { ...data };
            }
          }
        },
      }),
      where: (field: string, _op: string, val: string) => ({
        limit: (_n: number) => ({
          get: async () => {
            if (collName === 'users') {
              const matched = Object.values(mockFirestoreUsers).find((u) => u[field] === val);
              if (matched) {
                return {
                  empty: false,
                  docs: [
                    {
                      id: matched.phoneNumber,
                      data: () => ({ ...matched }),
                    },
                  ],
                };
              }
            }
            return { empty: true, docs: [] };
          },
        }),
      }),
    }),
  };

  return {
    db: mockDb,
    auth: mockAuth,
  };
});

describe('KYC Identity Lookup Endpoints (/v1/kyc)', () => {
  beforeEach(() => {
    resetKycRateLimits();
  });

  describe('POST /v1/kyc/nin-lookup', () => {
    it('should reject missing or invalid length NIN with 400', async () => {
      const res1 = await request(app).post('/v1/kyc/nin-lookup').send({});
      expect(res1.status).toBe(400);
      expect(res1.body.error).toContain('11-digit numeric value');

      const res2 = await request(app).post('/v1/kyc/nin-lookup').send({ nin: '12345' });
      expect(res2.status).toBe(400);

      const res3 = await request(app).post('/v1/kyc/nin-lookup').send({ nin: '1234567890a' });
      expect(res3.status).toBe(400);
    });

    it('should return 404 for simulated non-existent NIN (00000000000)', async () => {
      const res = await request(app).post('/v1/kyc/nin-lookup').send({ nin: '00000000000' });
      expect(res.status).toBe(404);
      expect(res.body.error).toContain('No identity record found');
    });

    it('should resolve verified identity with isExistingCustomer: false for new customer and persist hashed identity', async () => {
      const res = await request(app).post('/v1/kyc/nin-lookup').send({ nin: '12345678901' });
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.status).toBe('success');
      expect(res.body.entity).toBeDefined();
      expect(res.body.entity.firstName).toBe('Amaka');
      expect(res.body.entity.lastName).toBe('Nnamdi');
      expect(res.body.entity.dateOfBirth).toBe('2001-08-23');
      expect(res.body.entity.gender).toBe('Female');
      expect(res.body.data).toBeDefined();
      expect(res.body.data.isExistingCustomer).toBe(false);
      expect(res.body.data.isExistingUser).toBe(false);
      expect(res.body.data.nin).toBe('12345678901');
      expect(res.body.data.ninHash).toBe(crypto.createHash('sha256').update('12345678901').digest('hex'));
      expect(res.body.data.isKycVerified).toBe(true);
      expect(res.body.data.kycProvider).toBe('dojah');
      expect(res.body.data.fullName).toBe('Amaka Nnamdi');
      expect(res.body.data.phoneNumber).toBe('+2348011111111');

      // Verify Firestore persisted hashed identity without raw plaintext
      const userRecord = mockFirestoreUsers['+2348011111111'];
      expect(userRecord).toBeDefined();
      expect(userRecord.ninHash).toBe(res.body.data.ninHash);
      expect(userRecord.isKycVerified).toBe(true);
      expect(userRecord.kycProvider).toBe('dojah');
      expect(userRecord.nin).toBeUndefined();
    });

    it('should flag isExistingCustomer: true for pre-seeded existing customer (22222222222) in test environment', async () => {
      const res = await request(app).post('/v1/kyc/nin-lookup').send({ nin: '22222222222' });
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.data.isExistingCustomer).toBe(true);
      expect(res.body.data.isExistingUser).toBe(true);
      expect(res.body.data.fullName).toBe('Chukwuma Ugobueze');
      expect(res.body.data.phoneNumber).toBe('+2348011111111');
    });

    it('should return isExistingUser: false in development mode unless matching hash exists in Firestore', async () => {
      const originalEnv = config.nodeEnv;
      try {
        // Switch config.nodeEnv to development
        (config as any).nodeEnv = 'development';
        (process.env as any).NODE_ENV = 'development';

        // 99999999999 has no record in Firestore -> proceeds as new user
        const res = await request(app).post('/v1/kyc/nin-lookup').send({ nin: '99999999999' });
        expect(res.status).toBe(200);
        expect(res.body.data.isExistingCustomer).toBe(false);
        expect(res.body.data.isExistingUser).toBe(false);
      } finally {
        (config as any).nodeEnv = originalEnv;
        (process.env as any).NODE_ENV = 'test';
      }
    });

    it('should reject invalid Bearer token with 401 when token is provided', async () => {
      const res = await request(app)
        .post('/v1/kyc/nin-lookup')
        .set('Authorization', 'Bearer invalid_token_xyz')
        .send({ nin: '12345678901' });
      expect(res.status).toBe(401);
      expect(res.body.error).toContain('Unauthorized');
    });

    it('should accept valid Bearer token when provided', async () => {
      const res = await request(app)
        .post('/v1/kyc/nin-lookup')
        .set('Authorization', 'Bearer valid_user_token')
        .send({ nin: '12345678901' });
      expect(res.status).toBe(200);
      expect(res.body.data.isExistingCustomer).toBe(false);
    });

    it('should enforce rate limit defense when lookup is repeatedly called', async () => {
      // 5 rapid requests are allowed
      for (let i = 0; i < 5; i++) {
        const res = await request(app).post('/v1/kyc/nin-lookup').send({ nin: '98765432109' });
        expect(res.status).toBe(200);
      }

      // 6th request triggers rate limit 429
      const limitRes = await request(app).post('/v1/kyc/nin-lookup').send({ nin: '98765432109' });
      expect(limitRes.status).toBe(429);
      expect(limitRes.body.error).toContain('Too many verification attempts');
    });
  });

  describe('POST /v1/kyc/bvn-lookup', () => {
    it('should reject invalid length BVN with 400', async () => {
      const res = await request(app).post('/v1/kyc/bvn-lookup').send({ bvn: '123' });
      expect(res.status).toBe(400);
      expect(res.body.error).toContain('11-digit numeric value');
    });

    it('should return 404 for simulated non-existent BVN (00000000000)', async () => {
      const res = await request(app).post('/v1/kyc/bvn-lookup').send({ bvn: '00000000000' });
      expect(res.status).toBe(404);
    });

    it('should resolve verified BVN identity for new customer and persist hashed identity', async () => {
      const res = await request(app).post('/v1/kyc/bvn-lookup').send({ bvn: '12345678901' });
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.status).toBe('success');
      expect(res.body.entity).toBeDefined();
      expect(res.body.entity.firstName).toBe('Amaka');
      expect(res.body.entity.lastName).toBe('Nnamdi');
      expect(res.body.entity.dateOfBirth).toBe('2001-08-23');
      expect(res.body.entity.gender).toBe('Female');
      expect(res.body.data.isExistingCustomer).toBe(false);
      expect(res.body.data.isExistingUser).toBe(false);
      expect(res.body.data.bvn).toBe('12345678901');
      expect(res.body.data.bvnHash).toBe(crypto.createHash('sha256').update('12345678901').digest('hex'));
      expect(res.body.data.isKycVerified).toBe(true);
      expect(res.body.data.kycProvider).toBe('dojah');
      expect(res.body.data.fullName).toBe('Amaka Nnamdi');

      const userRecord = mockFirestoreUsers['+2348011111111'];
      expect(userRecord).toBeDefined();
      expect(userRecord.bvnHash).toBe(res.body.data.bvnHash);
      expect(userRecord.isKycVerified).toBe(true);
      expect(userRecord.kycProvider).toBe('dojah');
      expect(userRecord.bvn).toBeUndefined();
    });

    it('should identify existing customer via BVN (22222222222)', async () => {
      const res = await request(app).post('/v1/kyc/bvn-lookup').send({ bvn: '22222222222' });
      expect(res.status).toBe(200);
      expect(res.body.data.isExistingCustomer).toBe(true);
      expect(res.body.data.isExistingUser).toBe(true);
      expect(res.body.data.fullName).toBe('Chukwuma Ugobueze');
    });

    it('should generate tertiary persona (Babajide Adeyemi) when identifier ends in 3', async () => {
      const res = await request(app).post('/v1/kyc/bvn-lookup').send({ bvn: '12345678903' });
      expect(res.status).toBe(200);
      expect(res.body.entity.firstName).toBe('Babajide');
      expect(res.body.entity.lastName).toBe('Adeyemi');
      expect(res.body.entity.dateOfBirth).toBe('1995-11-05');
      expect(res.body.entity.gender).toBe('Male');
    });

    it('should generate primary persona (Chukwuma Ugobueze) by default for even ending digits', async () => {
      const res = await request(app).post('/v1/kyc/bvn-lookup').send({ bvn: '12345678904' });
      expect(res.status).toBe(200);
      expect(res.body.entity.firstName).toBe('Chukwuma');
      expect(res.body.entity.lastName).toBe('Ugobueze');
      expect(res.body.entity.dateOfBirth).toBe('1998-04-12');
      expect(res.body.entity.gender).toBe('Male');
    });
  });
});

/// <reference types="jest" />

import request from 'supertest';
import app from '../src/app';

const mockFirestoreData: Record<string, any> = {
  '+2348011111111': {
    phoneNumber: '+2348011111111',
    fullName: 'Chukwuma Ugobueze',
    email: 'chukwuma@payflow.app',
    displayName: 'Chukwuma Ugobueze',
  },
  '+2348022222222': {
    phoneNumber: '+2348022222222',
    walletBalance: 0,
    // No fullName or email set (simulating account created before name entry)
  },
};

jest.mock('../src/firebase', () => {
  const mockAuth = {
    verifyIdToken: async (token: string) => {
      if (token === 'valid_user_1_token') {
        return { uid: '+2348011111111', phone_number: '+2348011111111' };
      }
      if (token === 'valid_user_2_token') {
        return { uid: '+2348022222222', phone_number: '+2348022222222' };
      }
      if (token === 'valid_new_user_token') {
        return { uid: '+2348033333333', phone_number: '+2348033333333' };
      }
      throw new Error('Invalid token');
    },
    getUser: async (uid: string) => ({ uid, phoneNumber: uid }),
  };

const mockBeneficiaries: Record<string, Record<string, any>> = {};

const mockDb = {
    collection: (collName: string) => ({
      doc: (docId: string) => ({
        get: async () => {
          if (collName === 'users' && mockFirestoreData[docId]) {
            return {
              exists: true,
              data: () => ({ ...mockFirestoreData[docId] }),
            };
          }
          return { exists: false, data: () => null };
        },
        set: async (payload: any, options?: any) => {
          if (collName === 'users') {
            mockFirestoreData[docId] = {
              ...(options?.merge ? mockFirestoreData[docId] || {} : {}),
              ...payload,
            };
          }
          return { writeTime: new Date() };
        },
        update: async (payload: any) => {
          if (collName === 'users') {
            if (!mockFirestoreData[docId]) {
              throw new Error('Document does not exist');
            }
            mockFirestoreData[docId] = {
              ...mockFirestoreData[docId],
              ...payload,
            };
          }
          return { writeTime: new Date() };
        },
        collection: (subCollName: string) => ({
          doc: (subDocId: string) => ({
            get: async () => {
              const data = mockBeneficiaries[docId]?.[subDocId];
              return { exists: Boolean(data), id: subDocId, data: () => data ? { ...data } : null };
            },
            set: async (payload: any, options?: any) => {
              if (!mockBeneficiaries[docId]) mockBeneficiaries[docId] = {};
              mockBeneficiaries[docId][subDocId] = {
                ...(options?.merge ? mockBeneficiaries[docId][subDocId] || {} : {}),
                ...payload,
              };
              return { writeTime: new Date() };
            },
          }),
          where: (field: string, op: string, val: any) => ({
            get: async () => {
              const userBens = Object.values(mockBeneficiaries[docId] || {});
              const filtered = userBens.filter((b: any) => b[field] === val);
              return {
                docs: filtered.map((b: any) => ({
                  id: b.id,
                  data: () => ({ ...b }),
                })),
              };
            },
          }),
          get: async () => {
            const userBens = Object.values(mockBeneficiaries[docId] || {});
            return {
              docs: userBens.map((b: any) => ({
                id: b.id,
                data: () => ({ ...b }),
              })),
            };
          },
        }),
      }),
    }),
  };

  return {
    db: mockDb,
    auth: mockAuth,
    admin: { auth: () => mockAuth },
  };
});

describe('User Profile API (/v1/users/:phone/profile)', () => {
  it('GET /v1/users/:phone/profile returns full profile with real name and email', async () => {
    const res = await request(app)
      .get('/v1/users/08011111111/profile')
      .set('Authorization', 'Bearer valid_user_1_token');

    expect(res.status).toBe(200);
    expect(res.body.phone).toBe('+2348011111111');
    expect(res.body.displayName).toBe('Chukwuma Ugobueze');
    expect(res.body.fullName).toBe('Chukwuma Ugobueze');
    expect(res.body.email).toBe('chukwuma@payflow.app');
  });

  it('GET /v1/users/:phone/profile returns honest fallback (User +234...) when user has no name set', async () => {
    const res = await request(app)
      .get('/v1/users/08022222222/profile')
      .set('Authorization', 'Bearer valid_user_2_token');

    expect(res.status).toBe(200);
    expect(res.body.phone).toBe('+2348022222222');
    expect(res.body.displayName).toBe('User +2348022222222');
    expect(res.body.fullName).toBeNull();
  });

  it('GET /v1/users/:phone/profile returns honest fallback for self even if document does not exist yet', async () => {
    const res = await request(app)
      .get('/v1/users/08033333333/profile')
      .set('Authorization', 'Bearer valid_new_user_token');

    expect(res.status).toBe(200);
    expect(res.body.phone).toBe('+2348033333333');
    expect(res.body.displayName).toBe('User +2348033333333');
    expect(res.body.fullName).toBeNull();
  });

  it('GET /v1/users/:phone/profile returns 404 when querying an unknown recipient', async () => {
    const res = await request(app)
      .get('/v1/users/08099999999/profile')
      .set('Authorization', 'Bearer valid_user_1_token');

    expect(res.status).toBe(404);
    expect(res.body.error).toContain('No PayFlow user found with this number');
  });

  it('PUT /v1/users/:phone/profile updates and persists fullName and email', async () => {
    const res = await request(app)
      .put('/v1/users/08022222222/profile')
      .set('Authorization', 'Bearer valid_user_2_token')
      .send({
        fullName: 'Amina Bello',
        email: 'amina.bello@example.com',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.fullName).toBe('Amina Bello');
    expect(res.body.displayName).toBe('Amina Bello');
    expect(res.body.email).toBe('amina.bello@example.com');

    // Verify subsequent GET returns the persisted data
    const getRes = await request(app)
      .get('/v1/users/08022222222/profile')
      .set('Authorization', 'Bearer valid_user_2_token');

    expect(getRes.status).toBe(200);
    expect(getRes.body.fullName).toBe('Amina Bello');
    expect(getRes.body.displayName).toBe('Amina Bello');
    expect(getRes.body.email).toBe('amina.bello@example.com');
  });

  it('PUT /v1/users/:phone/profile creates new user profile document on signup completion', async () => {
    const res = await request(app)
      .put('/v1/users/08033333333/profile')
      .set('Authorization', 'Bearer valid_new_user_token')
      .send({
        fullName: 'New Signup User',
        email: 'newuser@payflow.app',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.fullName).toBe('New Signup User');

    // Verify persisted
    const getRes = await request(app)
      .get('/v1/users/08033333333/profile')
      .set('Authorization', 'Bearer valid_new_user_token');

    expect(getRes.status).toBe(200);
    expect(getRes.body.fullName).toBe('New Signup User');
  });

  it('PUT /v1/users/:phone/profile rejects updating another users profile with 403', async () => {
    const res = await request(app)
      .put('/v1/users/08011111111/profile')
      .set('Authorization', 'Bearer valid_user_2_token')
      .send({
        fullName: 'Hacker Name',
      });

    expect(res.status).toBe(403);
    expect(res.body.error).toContain('Forbidden');
  });

  it('PUT /v1/users/:phone/profile validates fullName is non-empty', async () => {
    const res = await request(app)
      .put('/v1/users/08011111111/profile')
      .set('Authorization', 'Bearer valid_user_1_token')
      .send({
        fullName: '   ',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('fullName is required');
  });

  it('PUT /v1/users/:phone/profile rejects unauthenticated request with 401', async () => {
    const res = await request(app)
      .put('/v1/users/08011111111/profile')
      .send({ fullName: 'Test' });

    expect(res.status).toBe(401);
  });

  describe('Beneficiaries API (/v1/users/beneficiaries)', () => {
    it('POST /v1/users/beneficiaries saves a bank beneficiary successfully', async () => {
      const res = await request(app)
        .post('/v1/users/beneficiaries')
        .set('Authorization', 'Bearer valid_user_1_token')
        .send({
          name: 'Sarah Connor',
          accountNumber: '0123456789',
          bankCode: '058',
          bankName: 'GTBank',
          category: 'bank',
        });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.beneficiary.name).toBe('Sarah Connor');
      expect(res.body.beneficiary.accountNumber).toBe('0123456789');
      expect(res.body.beneficiary.bankCode).toBe('058');
    });

    it('GET /v1/users/beneficiaries returns saved beneficiaries', async () => {
      const res = await request(app)
        .get('/v1/users/beneficiaries')
        .set('Authorization', 'Bearer valid_user_1_token');

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(Array.isArray(res.body.beneficiaries)).toBe(true);
      expect(res.body.beneficiaries.length).toBeGreaterThanOrEqual(1);
      expect(res.body.beneficiaries[0].name).toBe('Sarah Connor');
    });

    it('POST /v1/users/beneficiaries rejects missing name and account', async () => {
      const res = await request(app)
        .post('/v1/users/beneficiaries')
        .set('Authorization', 'Bearer valid_user_1_token')
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('required');
    });

    it('GET /v1/users/beneficiaries filters by category', async () => {
      // Save bills beneficiary
      await request(app)
        .post('/v1/users/beneficiaries')
        .set('Authorization', 'Bearer valid_user_1_token')
        .send({
          name: 'Ikeja Electric',
          accountNumber: '0192837465',
          category: 'bills',
          serviceId: 'ikeja-electric',
        });

      const res = await request(app)
        .get('/v1/users/beneficiaries?category=bills')
        .set('Authorization', 'Bearer valid_user_1_token');

      expect(res.status).toBe(200);
      expect(res.body.beneficiaries.every((b: any) => b.category === 'bills')).toBe(true);
    });
  });
});


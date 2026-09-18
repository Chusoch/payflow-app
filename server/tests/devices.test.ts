import request from 'supertest';
import app from '../src/app';

describe('POST /v1/devices/register', () => {
  it('should reject unauthenticated request with 401 (no auth header)', async () => {
    const res = await request(app)
      .post('/v1/devices/register')
      .send({ fcm_token: 'test_fcm_token_12345' });

    expect(res.status).toBe(401);
  });
});

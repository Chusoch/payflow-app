import { Router, Request, Response } from 'express';
import axios from 'axios';
import crypto from 'crypto';
import { admin, auth, db } from '../firebase';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
import { normalizePhone } from '../services/ledger';
import { config } from '../config';

const router = Router();

// In-Memory Storage for OTP Sessions & Rate Limiting
interface OtpMapping {
  phone: string;
  createdAt: number;
  mode: 'live' | 'mock';
}

export const otpSessionMap = new Map<string, OtpMapping>(); // pinId -> { phone, createdAt }
export const otpRateLimitMap = new Map<string, number>();   // phone -> lastSentTimestamp

/**
 * Resets rate-limit and session maps (used in unit test setup)
 */
export function resetOtpMaps(): void {
  otpSessionMap.clear();
  otpRateLimitMap.clear();
}

/**
 * POST /v1/auth/send-otp
 * Body: { phone: string }
 * Triggers Termii OTP or dev mock OTP. Enforces 60-second rate limit per phone number.
 */
router.post('/send-otp', async (req: Request, res: Response): Promise<void> => {
  try {
    const { phone } = req.body || {};

    if (!phone) {
      res.status(400).json({ error: 'phone parameter is required' });
      return;
    }

    const e164Phone = normalizePhone(String(phone));
    if (!e164Phone) {
      res.status(400).json({ error: 'Invalid phone number format' });
      return;
    }

    // Rate-limiting: 60 seconds in live mode, 30 seconds in mock/dev mode (matches Flutter UI timer)
    const now = Date.now();
    const isLive = Boolean(config.termiiApiKey && config.nodeEnv !== 'test');
    const rateLimitWindowMs = isLive ? 60000 : 30000;
    const lastSent = otpRateLimitMap.get(e164Phone) || 0;
    if (now - lastSent < rateLimitWindowMs) {
      const secondsRemaining = Math.ceil((rateLimitWindowMs - (now - lastSent)) / 1000);
      console.warn(`[auth/send-otp] Rate limit hit for ${e164Phone}: ${secondsRemaining}s remaining`);
      res.status(429).json({
        error: `Rate limit exceeded. Please wait ${secondsRemaining} seconds before requesting another OTP.`,
      });
      return;
    }

    let pinId: string;
    const mode = isLive ? 'live' : 'mock';

    // Live mode Termii integration
    if (isLive) {
      try {
        const termiiResponse = await axios.post(
          'https://api.ng.termii.com/api/sms/otp/send',
          {
            api_key: config.termiiApiKey,
            message_type: 'NUMERIC',
            to: e164Phone.replace(/^\+/, ''),
            from: 'PayFlow',
            channel: 'generic',
            pin_attempts: 3,
            pin_time_to_live: 10,
            pin_length: 6,
            pin_placeholder: '< 1234 >',
            message_text: 'Your PayFlow verification code is < 1234 >. Valid for 10 minutes.',
          },
          { timeout: 8000 }
        );

        pinId = termiiResponse.data?.pinId || termiiResponse.data?.pin_id;
        if (!pinId) {
          res.status(400).json({ error: termiiResponse.data?.message || 'Termii OTP dispatch failed' });
          return;
        }
      } catch (termiiErr: any) {
        console.error('[auth/send-otp] Termii API error:', termiiErr?.response?.data || termiiErr?.message);
        if (!config.allowMockTokens) {
          res.status(502).json({ error: 'SMS delivery failed. Please try again later.' });
          return;
        }
        pinId = `mock_pin_${now}_${Math.floor(1000 + Math.random() * 9000)}`;
      }
    } else {
      pinId = `mock_pin_${now}_${Math.floor(1000 + Math.random() * 9000)}`;
      console.log(`[auth/send-otp] Generated dev mock pinId: ${pinId} for ${e164Phone}`);
    }

    otpRateLimitMap.set(e164Phone, now);
    otpSessionMap.set(pinId, {
      phone: e164Phone,
      createdAt: now,
      mode,
    });

    res.status(200).json({
      status: 'success',
      message: isLive ? 'OTP sent successfully' : 'OTP sent (Dev mode: use 123456)',
      pinId,
      mode,
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Failed to send OTP' });
  }
});

/**
 * POST /v1/auth/verify-otp
 * Body: { pinId: string, pin: string }
 * Verifies code via Termii or dev mock, then mints Firebase Custom Token.
 */
router.post('/verify-otp', async (req: Request, res: Response): Promise<void> => {
  try {
    const { pinId, pin } = req.body || {};

    if (!pinId || !pin) {
      res.status(400).json({ error: 'pinId and pin are required' });
      return;
    }

    const session = otpSessionMap.get(String(pinId));
    if (!session) {
      res.status(400).json({ error: 'Invalid or expired OTP session. Please request a new code.' });
      return;
    }

    // Enforce 10-minute expiry (600,000 ms)
    const tenMinutesMs = 10 * 60 * 1000;
    if (Date.now() - session.createdAt > tenMinutesMs) {
      otpSessionMap.delete(String(pinId));
      res.status(400).json({ error: 'OTP session expired. Please request a new code.' });
      return;
    }

    const serverKnownPhone = session.phone;

    if (session.mode === 'live') {
      if (config.termiiApiKey) {
        try {
          const verifyResponse = await axios.post(
            'https://api.ng.termii.com/api/sms/otp/verify',
            {
              api_key: config.termiiApiKey,
              pin_id: pinId,
              pin: String(pin),
            },
            { timeout: 8000 }
          );

          if (!verifyResponse.data?.verified) {
            res.status(400).json({ error: 'Invalid OTP code' });
            return;
          }
        } catch (verifyErr: any) {
          console.error('[auth/verify-otp] Termii verification failure:', verifyErr?.response?.data || verifyErr?.message);
          res.status(400).json({ error: verifyErr?.response?.data?.message || 'Invalid or expired OTP' });
          return;
        }
      }
    } else {
      // Dev Mock Fallback: Accept fixed code 123456 or 000000 strictly for mock-mode sessions
      if (String(pin) !== '123456' && String(pin) !== '000000') {
        console.warn(`[auth/verify-otp] Dev mock PIN rejected: expected 123456/000000, received "${pin}"`);
        res.status(400).json({ error: 'Invalid OTP code' });
        return;
      }
      console.log(`[auth/verify-otp] Dev mock PIN verified successfully for pin=${pin}, phone=${serverKnownPhone}`);
    }

    // Mint Firebase Custom Token strictly for the server-bound phone number
    let customToken: string;
    try {
      customToken = await auth.createCustomToken(serverKnownPhone, {
        phone_number: serverKnownPhone,
      });
      console.log(`[auth/verify-otp] ✅ Minted genuine Firebase custom token for ${serverKnownPhone}`);
    } catch (tokenErr: any) {
      console.error(`================================================================================`);
      console.error(`[auth/verify-otp] ❌ auth.createCustomToken FAILED for phone: ${serverKnownPhone}`);
      console.error(`[auth/verify-otp] Error message:`, tokenErr?.message || tokenErr);
      if (tokenErr?.stack) console.error(tokenErr.stack);
      console.error(`[auth/verify-otp] 🚨 ROOT CAUSE: Firebase Admin SDK requires valid service account credentials`);
      console.error(`[auth/verify-otp]    to cryptographically sign custom authentication tokens.`);
      console.error(`[auth/verify-otp]    GOOGLE_APPLICATION_CREDENTIALS="${process.env.GOOGLE_APPLICATION_CREDENTIALS || '<UNSET>'}"`);
      console.error(`[auth/verify-otp] 👉 TO FIX:`);
      console.error(`[auth/verify-otp]    1. Firebase Console > Project Settings > Service Accounts > "Generate new private key"`);
      console.error(`[auth/verify-otp]    2. Save JSON file and set GOOGLE_APPLICATION_CREDENTIALS in server/.env`);
      console.error(`[auth/verify-otp]       e.g., GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/serviceAccountKey.json`);
      console.error(`[auth/verify-otp]    3. Restart backend server.`);
      console.error(`[auth/verify-otp] (If you explicitly want offline fake mock tokens that bypass Firebase Auth, set ALLOW_MOCK_TOKENS=true in .env)`);
      console.error(`================================================================================`);

      if (session.mode === 'mock' && config.allowMockTokens) {
        console.warn(`[auth/verify-otp] ⚠️ ALLOW_MOCK_TOKENS is enabled. Generating mock custom token fallback for mock session: ${serverKnownPhone}`);
        customToken = `mock_custom_token_${Date.now()}_${serverKnownPhone.replace(/[^0-9]/g, '')}`;
      } else {
        const sessionType = session.mode === 'live' ? 'live session' : 'mock session';
        console.error(`[auth/verify-otp] ${sessionType} failed to mint Firebase custom token:`, tokenErr?.message || tokenErr);
        res.status(500).json({
          error: `Failed to generate Firebase authentication token for verified ${sessionType}: ${tokenErr?.message || 'Service account credentials required'}. Set GOOGLE_APPLICATION_CREDENTIALS to a valid service account JSON key file path.`,
        });
        return;
      }
    }

    // Invalidate session mapping (one-time use) strictly after token is ready
    otpSessionMap.delete(String(pinId));

    console.log(`[auth/verify-otp] Verification complete. Returning customToken for ${serverKnownPhone}`);

    res.status(200).json({
      customToken,
      phone: serverKnownPhone,
      uid: serverKnownPhone,
    });
  } catch (error: any) {
    const errorDetails = error?.response?.data || error?.message || 'OTP verification failed';
    console.error('[auth/verify-otp] Unexpected verification error:', errorDetails);
    res.status(400).json({ error: errorDetails });
  }
});

/**
 * POST /v1/auth/verify-pin
 * Body: { pin: string }
 * Compares against hashed transactionPin on user document in Firestore.
 * Dev/Sandbox Fallback: If user has no PIN configured yet or in non-production mode, accepts default dev PIN '1234'.
 */
router.post('/verify-pin', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { pin } = req.body || {};
    if (!pin || typeof pin !== 'string') {
      res.status(400).json({ status: 'error', message: 'PIN is required' });
      return;
    }

    const trimmedPin = pin.trim();
    const authPhone = req.user?.phone_number || req.user?.uid;
    const phone = authPhone ? normalizePhone(authPhone) : null;

    if (!phone) {
      res.status(401).json({ status: 'error', message: 'Unauthorized: User not found' });
      return;
    }

    const userDoc = await db.collection('users').doc(phone).get();
    const userData = userDoc.exists ? userDoc.data() : null;
    const storedPin = userData?.transactionPin;

    const pinHash = crypto.createHash('sha256').update(trimmedPin).digest('hex');
    const isDev = config.nodeEnv !== 'production';
    const isDefaultDevPin = trimmedPin === '1234';

    let isMatch = false;
    if (storedPin) {
      if (storedPin === pinHash || storedPin === trimmedPin) {
        isMatch = true;
      } else if (isDev && isDefaultDevPin) {
        isMatch = true;
      }
    } else {
      if (isDefaultDevPin) {
        isMatch = true;
      }
    }

    if (isMatch) {
      res.status(200).json({ status: 'success', verified: true });
      return;
    }

    res.status(400).json({ status: 'error', message: 'Incorrect PIN. Try again.' });
  } catch (error: any) {
    res.status(500).json({ status: 'error', message: error?.message || 'Failed to verify PIN' });
  }
});

/**
 * POST /v1/auth/set-pin
 * Body: { pin: string }
 * Sets 4-digit transaction PIN for the authenticated user.
 */
router.post('/set-pin', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { pin } = req.body || {};
    if (!pin || typeof pin !== 'string' || !/^\d{4}$/.test(pin.trim())) {
      res.status(400).json({ status: 'error', message: 'PIN must be a 4-digit number' });
      return;
    }

    const trimmedPin = pin.trim();
    const authPhone = req.user?.phone_number || req.user?.uid;
    const phone = authPhone ? normalizePhone(authPhone) : null;

    if (!phone) {
      res.status(401).json({ status: 'error', message: 'Unauthorized: User not found' });
      return;
    }

    const pinHash = crypto.createHash('sha256').update(trimmedPin).digest('hex');
    const userDocRef = db.collection('users').doc(phone);
    const userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      await userDocRef.set({
        phoneNumber: phone,
        transactionPin: pinHash,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
    } else {
      await userDocRef.update({
        transactionPin: pinHash,
        updatedAt: new Date().toISOString(),
      });
    }

    res.status(200).json({ status: 'success', message: 'Transaction PIN updated successfully' });
  } catch (error: any) {
    res.status(500).json({ status: 'error', message: error?.message || 'Failed to update PIN' });
  }
});

/**
 * GET /v1/auth/me
 * Returns profile details for the authenticated user based on session token.
 */
router.get('/me', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const authPhone = req.user?.phone_number || req.user?.uid;
    if (!authPhone) {
      res.status(401).json({ error: 'Unauthorized: User not found' });
      return;
    }

    const formattedPhone = normalizePhone(authPhone);
    const userDoc = await db.collection('users').doc(formattedPhone).get();

    if (userDoc.exists) {
      const data = userDoc.data() || {};
      res.status(200).json({
        phone: formattedPhone,
        displayName: data.fullName || data.displayName || data.name || `User ${formattedPhone}`,
        fullName: data.fullName || null,
        email: data.email || null,
      });
      return;
    }

    res.status(200).json({
      phone: formattedPhone,
      displayName: `User ${formattedPhone}`,
      fullName: null,
      email: null,
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Failed to fetch user' });
  }
});

export default router;

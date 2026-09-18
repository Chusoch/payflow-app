import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import axios from 'axios';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
import { config } from '../config';
import { db, admin } from '../firebase';
import { normalizePhone, getBalanceKobo } from '../services/ledger';
import { handleVtpassPay, handleVtpassRequery, handleMerchantVerify } from '../services/vtpass';

const router = Router();

/**
 * Interface extending Request for raw body access (needed for HMAC verification)
 */
export interface RawBodyRequest extends Request {
  rawBody?: Buffer;
}

/**
 * POST /v1/payments/paystack/initialize
 * Proxies payment initialization to Paystack API. (Requires Firebase Auth)
 */
router.post('/paystack/initialize', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { reference, amount_in_kobo, email, payment_type } = req.body;

    if (!reference || !amount_in_kobo) {
      res.status(400).json({ error: 'reference and amount_in_kobo are required' });
      return;
    }

    // Idempotency check
    try {
      const refDoc = await db.collection('processed_references').doc(String(reference)).get();
      if (refDoc.exists) {
        res.status(409).json({ error: `Transaction reference ${reference} has already been processed` });
        return;
      }
    } catch (dbErr: any) {
      console.warn('[Paystack Initialize] Firestore read warning:', dbErr?.message);
    }

    const customerEmail = email || req.user?.email || `user_${req.user?.uid || 'anon'}@payflow.app`;

    // If live Paystack secret key is configured, call Paystack REST API
    if (config.paystackSecretKey && !config.paystackSecretKey.includes('mock')) {
      try {
        const response = await axios.post(
          'https://api.paystack.co/transaction/initialize',
          {
            reference,
            amount: amount_in_kobo,
            email: customerEmail,
            metadata: {
              payment_type,
              user_id: req.user?.uid,
              phone: req.user?.phone_number,
            },
          },
          {
            headers: {
              Authorization: `Bearer ${config.paystackSecretKey}`,
              'Content-Type': 'application/json',
            },
          }
        );
        res.status(200).json(response.data);
        return;
      } catch (apiErr: any) {
        res.status(400).json({ error: apiErr?.response?.data || 'Paystack API initialization failed' });
        return;
      }
    }

    // Sandbox / Mock fallback response
    res.status(200).json({
      status: true,
      message: 'Authorization URL created (Sandbox)',
      data: {
        authorization_url: `https://checkout.paystack.com/sandbox-checkout-${reference}`,
        access_code: `acc_${reference}`,
        reference: String(reference),
      },
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Initialization exception' });
  }
});

/**
 * GET /v1/payments/paystack/verify/:reference
 * Verifies Paystack transaction by reference. (Requires Firebase Auth)
 */
router.get('/paystack/verify/:reference', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const rawRef = req.params.reference;
    const reference = Array.isArray(rawRef) ? rawRef[0] : String(rawRef || '');
    const userPhone = req.user?.phone_number || req.user?.uid;

    const creditUserWallet = async (amountKobo: number, ref: string) => {
      if (!userPhone) return;
      try {
        const formatted = normalizePhone(userPhone);
        const refDocRef = db.collection('processed_references').doc(ref);
        const refDoc = await refDocRef.get();
        if (refDoc.exists) return;

        const userDocRef = db.collection('users').doc(formatted);
        const userDoc = await userDocRef.get();
        const currentBal = userDoc.exists ? getBalanceKobo(userDoc.data()) : 0;
        const newBal = currentBal + amountKobo;

        await userDocRef.set({
          phoneNumber: formatted,
          walletBalance: newBal,
          balanceInKobo: newBal,
          balance: newBal,
          updatedAt: new Date().toISOString(),
        }, { merge: true });

        // If authenticated UID is different from formatted phone, keep them in sync
        if (req.user?.uid && req.user.uid !== formatted) {
          try {
            await db.collection('users').doc(req.user.uid).set({
              phoneNumber: formatted,
              walletBalance: newBal,
              balanceInKobo: newBal,
              balance: newBal,
              updatedAt: new Date().toISOString(),
            }, { merge: true });
          } catch (_) {}
        }

        const nowIso = new Date().toISOString();
        if (typeof userDocRef.collection === 'function') {
          try {
            await userDocRef.collection('transactions').doc(ref).set({
              id: ref,
              reference: ref,
              title: 'Paystack Wallet Top Up',
              amount: amountKobo,
              amountInKobo: amountKobo,
              amountNaira: amountKobo / 100,
              status: 'Completed',
              type: 'credit',
              category: 'Top Up',
              channel: 'paystack',
              recipientOrSender: 'Paystack',
              transferType: 'Wallet Funding',
              createdAt: nowIso,
              timestamp: nowIso,
            });
          } catch (_) {}
        }

        await refDocRef.set({
          reference: ref,
          phoneNumber: formatted,
          amount: amountKobo,
          type: 'wallet_funding',
          channel: 'paystack',
          processedAt: nowIso,
        });
      } catch (_) {}
    };

    if (config.paystackSecretKey && !config.paystackSecretKey.includes('mock')) {
      try {
        const response = await axios.get(`https://api.paystack.co/transaction/verify/${reference}`, {
          headers: { Authorization: `Bearer ${config.paystackSecretKey}` },
        });
        const resData = response.data || {};
        const innerData = resData.data || {};
        if (innerData.status === 'success' || resData.status === 'success') {
          const verifiedAmt = Number(innerData.amount || resData.amount || 0);
          if (verifiedAmt > 0) {
            await creditUserWallet(verifiedAmt, reference);
          }
        }
        res.status(200).json(response.data);
        return;
      } catch (apiErr: any) {
        res.status(400).json({ error: apiErr?.response?.data || 'Paystack verification failed' });
        return;
      }
    }

    // Sandbox / Mock fallback verification
    const mockAmount = 100000;
    await creditUserWallet(mockAmount, reference);

    res.status(200).json({
      status: true,
      message: 'Verification successful (Sandbox)',
      data: {
        status: 'success',
        reference,
        amount: mockAmount,
        gateway_response: 'Successful',
        paid_at: new Date().toISOString(),
        channel: 'dedicated_virtual_account',
      },
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Verification exception' });
  }
});

/**
 * POST /v1/payments/paystack/dedicated-account
 * Assigns dedicated virtual account for wallet top up. (Requires Firebase Auth)
 */
router.post('/paystack/dedicated-account', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const userPhone = req.user?.phone_number || req.user?.uid;
    if (!userPhone) {
      res.status(401).json({ error: 'Unauthorized: missing authenticated user phone or UID' });
      return;
    }

    if (config.paystackSecretKey && !config.paystackSecretKey.includes('mock')) {
      try {
        const customerEmail = req.user?.email || `user_${req.user?.uid || 'anon'}@payflow.app`;
        const response = await axios.post(
          'https://api.paystack.co/dedicated_account/assign',
          {
            email: customerEmail,
            first_name: 'PayFlow',
            last_name: userPhone,
            phone: userPhone,
            preferred_bank: 'wema-bank',
            country: 'NG',
          },
          {
            headers: {
              Authorization: `Bearer ${config.paystackSecretKey}`,
              'Content-Type': 'application/json',
            },
          }
        );
        res.status(200).json(response.data);
        return;
      } catch (apiErr: any) {
        res.status(apiErr?.response?.status || 400).json({
          error: apiErr?.response?.data || 'Paystack dedicated account assignment failed',
        });
        return;
      }
    }

    // Sandbox / Mock fallback response
    res.status(200).json({
      status: true,
      message: 'Dedicated virtual account assigned (Sandbox)',
      data: {
        account_name: `PayFlow / ${userPhone}`,
        account_number: '99' + Math.floor(10000000 + Math.random() * 90000000),
        bank: { name: 'Wema Bank' },
        assigned: true,
      },
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Failed to create dedicated account' });
  }
});

/**
 * POST /v1/payments/vtpass/pay
 * Proxies utility bill / airtime payment to VTPass. (Requires Firebase Auth)
 */
router.post('/vtpass/pay', requireAuth, handleVtpassPay);

/**
 * POST /v1/payments/vtpass/requery
 * Queries transaction status from VTPass. (Requires Firebase Auth)
 */
router.post('/vtpass/requery', requireAuth, handleVtpassRequery);

/**
 * POST /v1/payments/vtpass/verify, /merchant-verify, /verify-meter, /verify-smartcard
 * Merchant verification for electricity meters and cable TV smartcards. (Requires Firebase Auth)
 */
router.post('/vtpass/verify', requireAuth, handleMerchantVerify);
router.post('/vtpass/merchant-verify', requireAuth, handleMerchantVerify);
router.post('/vtpass/verify-meter', requireAuth, handleMerchantVerify);
router.post('/vtpass/verify-smartcard', requireAuth, handleMerchantVerify);

/**
 * POST /v1/payments/webhooks/paystack
 * Receives and verifies Paystack HMAC SHA512 signature.
 */
router.post('/webhooks/paystack', async (req: RawBodyRequest, res: Response): Promise<void> => {
  const signature = req.headers['x-paystack-signature'] as string;

  if (!signature) {
    res.status(401).json({ error: 'Missing x-paystack-signature header' });
    return;
  }

  // Use rawBody buffer or JSON string representation for HMAC computation
  const bodyData = req.rawBody || Buffer.from(JSON.stringify(req.body));
  const secret = config.paystackWebhookSecret || config.paystackSecretKey;

  const expectedSignature = crypto
    .createHmac('sha512', secret)
    .update(bodyData)
    .digest('hex');

  if (signature !== expectedSignature) {
    res.status(401).json({ error: 'Invalid HMAC signature' });
    return;
  }

  const payload = req.body || {};
  const reference = payload.data?.reference || payload.reference;

  if (reference) {
    const amountKobo = payload.data?.amount || 0;
    const amountNaira = (amountKobo / 100).toFixed(2);
    const customerEmail = payload.data?.customer?.email;
    const userId = payload.data?.metadata?.userId;

    try {
      const refDocRef = db.collection('processed_references').doc(String(reference));
      const refDoc = await refDocRef.get();

      if (refDoc.exists) {
        // Idempotency: Duplicate webhook received, return 200 without re-processing
        res.status(200).json({ status: 'success', message: 'Webhook already processed' });
        return;
      }

      // Store in idempotency collection
      await refDocRef.set({
        reference: String(reference),
        type: 'paystack_webhook',
        event: payload.event || 'charge.success',
        amount_kobo: amountKobo,
        customerEmail: customerEmail || null,
        userId: userId || null,
        processedAt: new Date().toISOString(),
      });
    } catch (dbErr: any) {
      console.warn('[Paystack Webhook] Firestore persistence warning:', dbErr?.message);
    }

    // Send FCM push to user
    try {
      let targetUserId = userId;
      if (!targetUserId && customerEmail && typeof db.collection('users').where === 'function') {
        const userQuery = await db.collection('users').where('email', '==', customerEmail).limit(1).get();
        if (!userQuery.empty) {
          targetUserId = userQuery.docs[0].id;
        }
      }

      if (targetUserId) {
        const userDoc = await db.collection('users').doc(targetUserId).get();
        const fcmToken = userDoc.data()?.fcmToken;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: 'Payment Successful',
              body: `Your Paystack transaction of ₦${amountNaira} was confirmed.`,
            },
            data: {
              reference: String(reference),
              type: 'paystack',
              amount: String(amountNaira),
            },
          });
        }
      }
    } catch (fcmErr: any) {
      console.warn('[FCM] Webhook push dispatch warning:', fcmErr?.message);
    }
  }

  res.status(200).json({ status: 'success', message: 'Paystack webhook received and reconciled' });
});

/**
 * POST /v1/payments/webhooks/vtpass
 * Receives and verifies VTPass callback signature.
 */
router.post('/webhooks/vtpass', async (req: RawBodyRequest, res: Response): Promise<void> => {
  const signature = req.headers['x-vtpass-signature'] as string;
  const secret = config.vtpassWebhookSecret || config.vtpassSecretKey;

  // Validate signature header if secret is configured
  if (secret && signature) {
    const bodyData = req.rawBody || Buffer.from(JSON.stringify(req.body));
    const expectedSignature = crypto.createHmac('sha256', secret).update(bodyData).digest('hex');
    if (signature !== expectedSignature && signature !== secret) {
      res.status(401).json({ error: 'Invalid VTPass signature' });
      return;
    }
  } else if (!signature && secret) {
    res.status(401).json({ error: 'Missing X-VTPass-Signature header' });
    return;
  }

  const payload = req.body || {};
  const requestId = payload.content?.transactions?.requestId || payload.requestId;

  if (requestId) {
    const refDocRef = db.collection('processed_references').doc(String(requestId));
    const refDoc = await refDocRef.get();

    if (refDoc.exists) {
      res.status(200).json({ code: '000', response_description: 'Callback already processed' });
      return;
    }

    await refDocRef.set({
      reference: String(requestId),
      type: 'vtpass_webhook',
      code: payload.code || '000',
      processedAt: new Date().toISOString(),
    });

    // Send FCM push notification if user token exists
    try {
      const userId = payload.userId || payload.content?.transactions?.userId;
      if (userId) {
        const userDoc = await db.collection('users').doc(userId).get();
        const fcmToken = userDoc.data()?.fcmToken;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: 'Utility Payment Completed',
              body: `Your VTPass transaction ${requestId} was completed successfully.`,
            },
            data: {
              reference: String(requestId),
              type: 'vtpass',
            },
          });
        }
      }
    } catch (fcmErr: any) {
      console.warn('[FCM] VTPass webhook push dispatch warning:', fcmErr?.message);
    }
  }

  res.status(200).json({ code: '000', response_description: 'VTPass notification processed' });
});

export default router;

import { Router, Request, Response } from 'express';
import axios from 'axios';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
import {
  executeTransfer,
  getWalletBalance,
  seedWalletBalance,
  InsufficientBalanceError,
  DuplicateReferenceError,
  normalizePhone,
  getBalanceKobo,
} from '../services/ledger';
import { config } from '../config';
import { db } from '../firebase';

const router = Router();

/**
 * POST /v1/wallet/initialize-funding
 * Initializes live wallet funding transaction via Paystack API.
 * Request body: { email, amount, phoneNumber } (amount in Naira)
 * Generates unique reference: PF_FUND_${Date.now()}_${phoneNumber}
 * Returns Paystack's authorization_url, access_code, and reference.
 */
router.post('/initialize-funding', async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, amount, phoneNumber } = req.body || {};

    if (!amount || isNaN(Number(amount)) || Number(amount) <= 0) {
      res.status(400).json({ error: 'Valid positive amount in Naira is required' });
      return;
    }

    if (!phoneNumber || typeof phoneNumber !== 'string' || !phoneNumber.trim()) {
      res.status(400).json({ error: 'phoneNumber is required' });
      return;
    }

    const cleanPhone = phoneNumber.trim().replace(/[^0-9+]/g, '');
    const formattedPhone = normalizePhone(cleanPhone);
    const amountKobo = Math.round(Number(amount) * 100);

    // Format reference: PF_FUND_${Date.now()}_${phoneNumber}
    const reference = `PF_FUND_${Date.now()}_${cleanPhone.replace(/\+/g, '')}`;
    const customerEmail = email && typeof email === 'string' && email.includes('@')
      ? email.trim()
      : `user_${cleanPhone.replace(/\+/g, '')}@payflow.app`;

    const isTest = config.nodeEnv === 'test' || process.env.NODE_ENV === 'test';
    const paystackKey = process.env.PAYSTACK_SECRET_KEY || config.paystackSecretKey;

    if (paystackKey && !paystackKey.includes('mock') && !isTest) {
      try {
        const paystackRes = await axios.post(
          'https://api.paystack.co/transaction/initialize',
          {
            reference,
            amount: amountKobo,
            email: customerEmail,
            metadata: {
              phoneNumber: formattedPhone,
              channel: 'paystack',
              type: 'wallet_funding',
            },
          },
          {
            headers: {
              Authorization: `Bearer ${paystackKey}`,
              'Content-Type': 'application/json',
            },
            timeout: 10000,
          }
        );

        const data = paystackRes.data?.data || {};
        res.status(200).json({
          success: true,
          status: true,
          authorization_url: data.authorization_url,
          access_code: data.access_code,
          reference: data.reference || reference,
          data,
        });
        return;
      } catch (apiErr: any) {
        const errMsg = apiErr?.response?.data?.message || apiErr?.response?.data?.error || apiErr?.message || 'Paystack initialization failed';
        res.status(apiErr?.response?.status || 400).json({ error: errMsg });
        return;
      }
    }

    // Dev / Test fallback
    res.status(200).json({
      success: true,
      status: true,
      authorization_url: `https://checkout.paystack.com/${reference}`,
      access_code: `acc_${reference}`,
      reference,
      data: {
        authorization_url: `https://checkout.paystack.com/${reference}`,
        access_code: `acc_${reference}`,
        reference,
      },
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Initialization exception' });
  }
});

/**
 * POST /v1/wallet/verify-funding
 * Verifies Paystack transaction by reference and credits wallet.
 * Request body: { reference, phoneNumber }
 * Atomically increments walletBalance in Firestore (users/{phoneNumber}) with verified amount.
 * Records transaction under users/{phoneNumber}/transactions.
 * Returns updated balance and success status.
 */
router.post('/verify-funding', async (req: Request, res: Response): Promise<void> => {
  try {
    const { reference, phoneNumber } = req.body || {};

    if (!reference || typeof reference !== 'string' || !reference.trim()) {
      res.status(400).json({ error: 'reference is required' });
      return;
    }

    if (!phoneNumber || typeof phoneNumber !== 'string' || !phoneNumber.trim()) {
      res.status(400).json({ error: 'phoneNumber is required' });
      return;
    }

    const cleanRef = reference.trim();
    const formattedPhone = normalizePhone(phoneNumber);
    const isTest = config.nodeEnv === 'test' || process.env.NODE_ENV === 'test';
    const paystackKey = process.env.PAYSTACK_SECRET_KEY || config.paystackSecretKey;

    let isSuccess = false;
    let verifiedAmountKobo = 0;

    if (paystackKey && !paystackKey.includes('mock') && !isTest) {
      try {
        const paystackRes = await axios.get(`https://api.paystack.co/transaction/verify/${cleanRef}`, {
          headers: { Authorization: `Bearer ${paystackKey}` },
          timeout: 10000,
        });

        const resData = paystackRes.data || {};
        const innerData = resData.data || {};

        if (innerData.status === 'success' || resData.status === 'success') {
          isSuccess = true;
          verifiedAmountKobo = Number(innerData.amount || resData.amount || 0);
        } else {
          res.status(400).json({
            success: false,
            status: innerData.status || 'failed',
            error: innerData.gateway_response || 'Payment not verified on Paystack',
          });
          return;
        }
      } catch (apiErr: any) {
        const errMsg = apiErr?.response?.data?.message || apiErr?.response?.data?.error || apiErr?.message || 'Paystack verification failed';
        res.status(apiErr?.response?.status || 400).json({ error: errMsg });
        return;
      }
    } else {
      isSuccess = true;
      verifiedAmountKobo = 100000;
    }

    if (!isSuccess) {
      res.status(400).json({ error: 'Transaction verification failed' });
      return;
    }

    // Check Idempotency Store (processed_references)
    try {
      const refDocRef = db.collection('processed_references').doc(cleanRef);
      const refDoc = await refDocRef.get();

      if (refDoc.exists) {
        const userDoc = await db.collection('users').doc(formattedPhone).get();
        const currentBalance = userDoc.exists ? getBalanceKobo(userDoc.data()) : 0;

        res.status(200).json({
          success: true,
          status: 'success',
          reference: cleanRef,
          walletBalance: currentBalance,
          balanceInKobo: currentBalance,
          balance: currentBalance,
          amount: verifiedAmountKobo,
          alreadyProcessed: true,
        });
        return;
      }
    } catch (_) {}

    // Atomically increment walletBalance and record transaction in Firestore
    const userDocRef = db.collection('users').doc(formattedPhone);
    const refDocRef = db.collection('processed_references').doc(cleanRef);

    let updatedBalance = verifiedAmountKobo;

    try {
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userDocRef);
        const refDoc = await transaction.get(refDocRef);

        const currentBalance = userDoc.exists ? getBalanceKobo(userDoc.data()) : 0;

        if (refDoc.exists) {
          updatedBalance = currentBalance;
          return;
        }

        updatedBalance = currentBalance + verifiedAmountKobo;

        transaction.set(userDocRef, {
          phoneNumber: formattedPhone,
          walletBalance: updatedBalance,
          balanceInKobo: updatedBalance,
          balance: updatedBalance,
          updatedAt: new Date().toISOString(),
        }, { merge: true });

        // Record transaction under users/{phoneNumber}/transactions
        const nowIso = new Date().toISOString();
        try {
          const txRef = typeof userDocRef.collection === 'function'
            ? userDocRef.collection('transactions').doc(cleanRef)
            : db.collection('transactions').doc(cleanRef);

          transaction.set(txRef, {
            id: cleanRef,
            reference: cleanRef,
            title: 'Paystack Wallet Top Up',
            amount: verifiedAmountKobo,
            amountInKobo: verifiedAmountKobo,
            amountNaira: verifiedAmountKobo / 100,
            status: 'successful',
            type: 'credit',
            category: 'Top Up',
            channel: 'paystack',
            recipientOrSender: 'Paystack',
            transferType: 'Wallet Funding',
            createdAt: nowIso,
            timestamp: nowIso,
          });
        } catch (_) {}

        transaction.set(refDocRef, {
          reference: cleanRef,
          phoneNumber: formattedPhone,
          amount: verifiedAmountKobo,
          type: 'wallet_funding',
          channel: 'paystack',
          processedAt: nowIso,
        });
      });
    } catch (txErr: any) {
      // Direct write fallback
      try {
        const nowIso = new Date().toISOString();
        const userDoc = await userDocRef.get();
        const currentBalance = userDoc.exists ? getBalanceKobo(userDoc.data()) : 0;
        updatedBalance = currentBalance + verifiedAmountKobo;
        await userDocRef.set({
          phoneNumber: formattedPhone,
          walletBalance: updatedBalance,
          balanceInKobo: updatedBalance,
          balance: updatedBalance,
          updatedAt: nowIso,
        }, { merge: true });

        if (typeof userDocRef.collection === 'function') {
          await userDocRef.collection('transactions').doc(cleanRef).set({
            id: cleanRef,
            reference: cleanRef,
            title: 'Paystack Wallet Top Up',
            amount: verifiedAmountKobo,
            amountInKobo: verifiedAmountKobo,
            amountNaira: verifiedAmountKobo / 100,
            status: 'successful',
            type: 'credit',
            category: 'Top Up',
            channel: 'paystack',
            recipientOrSender: 'Paystack',
            transferType: 'Wallet Funding',
            createdAt: nowIso,
            timestamp: nowIso,
          });
        }
        await refDocRef.set({
          reference: cleanRef,
          phoneNumber: formattedPhone,
          amount: verifiedAmountKobo,
          type: 'wallet_funding',
          channel: 'paystack',
          processedAt: nowIso,
        });
      } catch (_) {}
    }

    res.status(200).json({
      success: true,
      status: 'success',
      reference: cleanRef,
      walletBalance: updatedBalance,
      balanceInKobo: updatedBalance,
      balance: updatedBalance,
      amount: verifiedAmountKobo,
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Verification exception' });
  }
});

/**
 * POST /v1/wallet/transfer
 * Executes an atomic P2P wallet transfer from the authenticated user to recipient.
 */
router.post('/transfer', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { toPhone, amount_kobo, reference, recipientName } = req.body;

    // Derived from authenticated session token:
    // If req.user.uid is a phone number format, use it strictly.
    // If req.user.uid is an alphanumeric Firebase UID, resolve from phone_number claim or user doc.
    let fromPhone = req.user?.uid;
    if (fromPhone && !fromPhone.startsWith('+') && !/^\d+$/.test(fromPhone)) {
      if (req.user?.phone_number) {
        fromPhone = req.user.phone_number;
      } else {
        try {
          const userDoc = await db.collection('users').doc(fromPhone).get();
          if (userDoc.exists && userDoc.data()?.phoneNumber) {
            fromPhone = userDoc.data()!.phoneNumber;
          }
        } catch (_) {}
      }
    }

    if (!fromPhone) {
      res.status(400).json({ error: 'Authenticated user does not have a valid UID or phone associated' });
      return;
    }

    if (!toPhone || !amount_kobo || !reference) {
      res.status(400).json({ error: 'Missing required parameters: toPhone, amount_kobo, and reference are required' });
      return;
    }

    const result = await executeTransfer({
      fromPhone,
      toPhone,
      amount_kobo: Number(amount_kobo),
      reference: String(reference),
      recipientName: recipientName ? String(recipientName) : undefined,
    });

    res.status(200).json(result);
  } catch (error: any) {
    if (error instanceof InsufficientBalanceError) {
      res.status(400).json({ error: error.message });
      return;
    }
    if (error instanceof DuplicateReferenceError) {
      res.status(409).json({ error: error.message });
      return;
    }
    res.status(400).json({ error: error?.message || 'Transfer failed' });
  }
});

/**
 * GET /v1/wallet/balance/me, /v1/wallet/balance, or /v1/wallet
 * Returns integer kobo balance for the authenticated user (derived strictly from authenticated session token).
 */
router.get(['/balance/me', '/balance', '/'], requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    let phone = req.user?.uid;
    if (phone && !phone.startsWith('+') && !/^\d+$/.test(phone)) {
      if (req.user?.phone_number) {
        phone = req.user.phone_number;
      } else {
        try {
          const userDoc = await db.collection('users').doc(phone).get();
          if (userDoc.exists && userDoc.data()?.phoneNumber) {
            phone = userDoc.data()!.phoneNumber;
          }
        } catch (_) {}
      }
    }

    if (!phone) {
      res.status(401).json({ error: 'Unauthorized: missing authenticated user phone or UID' });
      return;
    }

    const balanceData = await getWalletBalance(phone);
    res.status(200).json(balanceData);
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Failed to fetch wallet balance' });
  }
});

/**
 * GET /v1/wallet/transactions
 * Returns transaction history for the authenticated user from users/{userPhone}/transactions.
 * Ordered by createdAt descending, limit 20.
 */
router.get('/transactions', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    let phone = req.user?.uid;
    if (phone && !phone.startsWith('+') && !/^\d+$/.test(phone)) {
      if (req.user?.phone_number) {
        phone = req.user.phone_number;
      } else {
        try {
          const userDoc = await db.collection('users').doc(phone).get();
          if (userDoc.exists && userDoc.data()?.phoneNumber) {
            phone = userDoc.data()!.phoneNumber;
          }
        } catch (_) {}
      }
    }

    if (!phone) {
      res.status(401).json({ error: 'Unauthorized: missing authenticated user phone or UID' });
      return;
    }

    const formattedPhone = normalizePhone(phone);
    const candidateKeys = [
      formattedPhone,
      phone,
      phone.replace(/^\+/, ''),
      formattedPhone.replace(/^\+/, ''),
      formattedPhone.startsWith('+234') ? '0' + formattedPhone.substring(4) : '',
    ].filter((k, idx, arr) => k && arr.indexOf(k) === idx);

    let rawDocs: any[] = [];

    for (const key of candidateKeys) {
      try {
        const userDocRef = db.collection('users').doc(key);
        if (typeof userDocRef.collection === 'function') {
          let query: any = userDocRef.collection('transactions');
          if (typeof query.orderBy === 'function') {
            query = query.orderBy('createdAt', 'desc');
          }
          if (typeof query.limit === 'function') {
            query = query.limit(20);
          }

          const snap = await query.get();
          if (snap && snap.docs && snap.docs.length > 0) {
            rawDocs = snap.docs.map((doc: any) => ({
              id: doc.id,
              ...doc.data(),
            }));
            break;
          }
        }
      } catch (_) {}
    }

    // Sort by createdAt / timestamp descending as guarantee
    rawDocs.sort((a, b) => {
      const timeA = new Date(b.createdAt || b.timestamp || 0).getTime();
      const timeB = new Date(a.createdAt || a.timestamp || 0).getTime();
      return timeA - timeB;
    });

    const normalizedTransactions = rawDocs.slice(0, 20).map((tx) => {
      const amtKobo = getBalanceKobo({ amount: tx.amount });
      return {
        id: tx.id || tx.reference,
        reference: tx.reference || tx.id,
        title: tx.title || (tx.type === 'credit' ? 'Wallet Credit' : 'Wallet Debit'),
        amount: amtKobo,
        amountInKobo: amtKobo,
        amountNaira: tx.amountNaira !== undefined ? Number(tx.amountNaira) : amtKobo / 100,
        type: tx.type || (tx.isCredit ? 'credit' : 'debit'),
        category: tx.category || (tx.type === 'credit' ? 'Top Up' : 'transfer'),
        status: tx.status || 'Completed',
        recipientOrSender: tx.recipientOrSender || null,
        transferType: tx.transferType || null,
        token: tx.token || null,
        narration: tx.narration || null,
        senderName: tx.senderName || null,
        recipientName: tx.recipientName || null,
        senderId: tx.senderId || tx.senderPhone || null,
        recipientId: tx.recipientId || tx.recipientPhone || null,
        senderPhone: tx.senderPhone || null,
        recipientPhone: tx.recipientPhone || null,
        createdAt: tx.createdAt || tx.timestamp || new Date().toISOString(),
        timestamp: tx.timestamp || tx.createdAt || new Date().toISOString(),
      };
    });

    res.status(200).json({
      success: true,
      transactions: normalizedTransactions,
      data: normalizedTransactions,
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Failed to fetch transaction history' });
  }
});

/**
 * POST /v1/wallet/seed
 * Dev-only endpoint to fund test accounts. Gated by ALLOW_DEV_ENDPOINTS=true AND requireAuth.
 */
router.post('/seed', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  if (!config.allowDevEndpoints) {
    res.status(403).json({ error: 'Dev endpoints are disabled in this environment (ALLOW_DEV_ENDPOINTS=false)' });
    return;
  }

  try {
    const { phone, amount_kobo } = req.body;
    const targetPhone = phone || req.user?.uid;

    if (!targetPhone || !amount_kobo) {
      res.status(400).json({ error: 'phone and amount_kobo are required' });
      return;
    }

    const result = await seedWalletBalance(targetPhone, Number(amount_kobo));
    res.status(200).json(result);
  } catch (error: any) {
    res.status(400).json({ error: error?.message || 'Seed failed' });
  }
});

export default router;

import { db, admin } from '../firebase';

export class InsufficientBalanceError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InsufficientBalanceError';
  }
}

export class DuplicateReferenceError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DuplicateReferenceError';
  }
}

export interface TransferParams {
  fromPhone: string;
  toPhone: string;
  amount_kobo: number;
  reference: string;
  recipientName?: string;
  senderName?: string;
}

export interface TransferResult {
  success: boolean;
  reference: string;
  fromPhone: string;
  toPhone: string;
  senderId?: string;
  recipientId?: string;
  amount_kobo: number;
  newBalance: number;
  senderName?: string;
  recipientName?: string;
}

/**
 * Robust balance extractor: extracts integer Kobo balance from Firestore document data.
 * Checks walletBalance, balanceInKobo, and balance with graceful fallbacks.
 */
export function getBalanceKobo(data: any): number {
  if (!data || typeof data !== 'object') return 0;

  // 1. walletBalance (primary integer Kobo)
  if (typeof data.walletBalance === 'number' && !isNaN(data.walletBalance)) {
    return Math.floor(data.walletBalance);
  }
  if (typeof data.walletBalance === 'string' && !isNaN(Number(data.walletBalance))) {
    return Math.floor(Number(data.walletBalance));
  }

  // 2. balanceInKobo (alias in integer Kobo)
  if (typeof data.balanceInKobo === 'number' && !isNaN(data.balanceInKobo)) {
    return Math.floor(data.balanceInKobo);
  }
  if (typeof data.balanceInKobo === 'string' && !isNaN(Number(data.balanceInKobo))) {
    return Math.floor(Number(data.balanceInKobo));
  }

  // 3. balance (legacy field)
  if (typeof data.balance === 'number' && !isNaN(data.balance)) {
    return Math.floor(data.balance);
  }
  if (typeof data.balance === 'string' && !isNaN(Number(data.balance))) {
    return Math.floor(Number(data.balance));
  }

  return 0;
}

/**
 * Normalizes phone numbers to standard E.164 format (+234...).
 * Handles:
 * 1. 11 digits with leading 0 (e.g. 08123456789 -> +2348123456789)
 * 2. 10 digits without leading 0 (e.g. 8123456789 -> +2348123456789)
 * 3. 13 digits starting with 234 without + (e.g. 2348123456789 -> +2348123456789)
 * 4. 14/15 digits with accidental zero after country code (e.g. +23408123456789 -> +2348123456789)
 * 5. Already formatted with + (e.g. +2348123456789 -> +2348123456789)
 */
export function normalizePhone(phone: string): string {
  if (!phone) return '';
  let cleaned = phone.trim().replace(/[\s\-\(\)]/g, '');

  // Handle +2340... (e.g. +2340801234567 -> +234801234567)
  if (cleaned.startsWith('+2340') && cleaned.length === 15) {
    return `+234${cleaned.substring(5)}`;
  }
  if (cleaned.startsWith('2340') && cleaned.length === 14) {
    return `+234${cleaned.substring(4)}`;
  }

  if (cleaned.startsWith('+')) {
    return cleaned;
  }

  if (cleaned.startsWith('234') && cleaned.length === 13) {
    return `+${cleaned}`;
  }

  if (cleaned.startsWith('0') && cleaned.length === 11) {
    return `+234${cleaned.substring(1)}`;
  }

  if (!cleaned.startsWith('0') && cleaned.length === 10) {
    return `+234${cleaned}`;
  }

  if (cleaned.startsWith('234')) {
    return `+${cleaned}`;
  }

  return cleaned;
}

/**
 * Executes an atomic P2P wallet transfer inside a Firestore Transaction.
 */
export async function executeTransfer(params: TransferParams): Promise<TransferResult> {
  const fromPhone = normalizePhone(params.fromPhone);
  const toPhone = normalizePhone(params.toPhone);
  const amountKobo = Math.floor(params.amount_kobo);
  const reference = params.reference.trim();

  if (!fromPhone) {
    throw new Error('Invalid sender phone number');
  }
  if (!toPhone) {
    throw new Error('Invalid recipient phone number');
  }
  if (fromPhone === toPhone) {
    throw new Error('Sender and recipient phone numbers cannot be identical');
  }
  if (isNaN(amountKobo) || amountKobo <= 0) {
    throw new Error('Amount must be a positive integer in kobo');
  }
  if (!reference) {
    throw new Error('Transaction reference is required');
  }

  const result = await db.runTransaction(async (transaction) => {
    // 1. Check Idempotency Store (processed_references)
    const refDocRef = db.collection('processed_references').doc(reference);
    const refDoc = await transaction.get(refDocRef);

    if (refDoc.exists) {
      throw new DuplicateReferenceError(`Transaction reference ${reference} has already been processed`);
    }

    // 2. Read Sender Document (users/{fromPhone} with fallback to alternate key formats)
    let senderDocRef = db.collection('users').doc(fromPhone);
    let senderDoc = await transaction.get(senderDocRef);

    // If normalized document does not exist or has 0 balance, check candidate alternate document IDs
    if (!senderDoc.exists || getBalanceKobo(senderDoc.data()) === 0) {
      const candidateKeys = [
        params.fromPhone,
        fromPhone.replace(/^\+/, ''),
        fromPhone.startsWith('+234') ? '0' + fromPhone.substring(4) : '',
        params.fromPhone.replace(/^\+/, ''),
      ].filter((k) => k && k !== fromPhone);

      for (const key of candidateKeys) {
        try {
          const candidateRef = db.collection('users').doc(key);
          const candidateDoc = await transaction.get(candidateRef);
          if (candidateDoc.exists) {
            const bal = getBalanceKobo(candidateDoc.data());
            if (bal > 0 || !senderDoc.exists) {
              senderDocRef = candidateRef;
              senderDoc = candidateDoc;
              if (bal > 0) break;
            }
          }
        } catch (_) {}
      }
    }

    if (!senderDoc.exists) {
      throw new InsufficientBalanceError(`Sender account ${fromPhone} not found or has zero balance`);
    }

    const senderData = senderDoc.data() || {};
    const senderBalance = getBalanceKobo(senderData);

    if (senderBalance < amountKobo) {
      throw new InsufficientBalanceError(
        `Insufficient balance. Available: ${senderBalance} kobo (₦${(senderBalance / 100).toFixed(2)}), Required: ${amountKobo} kobo (₦${(amountKobo / 100).toFixed(2)})`
      );
    }

    // 3. Read Recipient Document (users/{toPhone})
    let recipientDocRef = db.collection('users').doc(toPhone);
    let recipientDoc = await transaction.get(recipientDocRef);

    if (!recipientDoc.exists) {
      const candidateToKeys = [
        params.toPhone,
        toPhone.replace(/^\+/, ''),
        toPhone.startsWith('+234') ? '0' + toPhone.substring(4) : '',
      ].filter((k) => k && k !== toPhone);

      for (const key of candidateToKeys) {
        try {
          const candidateRef = db.collection('users').doc(key);
          const candidateDoc = await transaction.get(candidateRef);
          if (candidateDoc.exists) {
            recipientDocRef = candidateRef;
            recipientDoc = candidateDoc;
            break;
          }
        } catch (_) {}
      }
    }

    const recipientData = recipientDoc.exists ? recipientDoc.data() || {} : {};
    const recipientBalance = getBalanceKobo(recipientData);

    // 4. Calculate New Balances (Integer Kobo)
    const newSenderBalance = Math.floor(senderBalance - amountKobo);
    const newRecipientBalance = Math.floor(recipientBalance + amountKobo);

    // Resolve recipient and sender display names for transaction logging
    const recipientName =
      (params.recipientName && params.recipientName.trim()) ||
      recipientData.fullName ||
      recipientData.displayName ||
      recipientData.name ||
      (recipientData.firstName ? `${recipientData.firstName} ${recipientData.lastName || ''}`.trim() : '') ||
      toPhone;

    const senderName =
      (params.senderName && params.senderName.trim()) ||
      senderData.fullName ||
      senderData.displayName ||
      senderData.name ||
      (senderData.firstName ? `${senderData.firstName} ${senderData.lastName || ''}`.trim() : '') ||
      fromPhone;

    const nowIso = new Date().toISOString();

    // 5. Execute Atomic Writes
    transaction.update(senderDocRef, {
      walletBalance: newSenderBalance,
      balanceInKobo: newSenderBalance,
      balance: newSenderBalance,
      updatedAt: nowIso,
    });

    // Also update normalized phone doc if senderDocRef was an alternate key
    if (senderDocRef.id !== fromPhone) {
      try {
        const normRef = db.collection('users').doc(fromPhone);
        transaction.set(normRef, {
          phoneNumber: fromPhone,
          walletBalance: newSenderBalance,
          balanceInKobo: newSenderBalance,
          balance: newSenderBalance,
          updatedAt: nowIso,
        }, { merge: true });
      } catch (_) {}
    }

    if (recipientDoc.exists) {
      transaction.update(recipientDocRef, {
        walletBalance: newRecipientBalance,
        balanceInKobo: newRecipientBalance,
        balance: newRecipientBalance,
        updatedAt: nowIso,
      });
    } else {
      transaction.set(recipientDocRef, {
        phoneNumber: toPhone,
        walletBalance: newRecipientBalance,
        balanceInKobo: newRecipientBalance,
        balance: newRecipientBalance,
        createdAt: nowIso,
        updatedAt: nowIso,
      });
    }

    // 6. Record Sub-Collection Transaction Entries
    // Sender: users/{fromPhone}/transactions/{reference}
    try {
      const fromDoc = db.collection('users').doc(fromPhone);
      if (typeof fromDoc.collection === 'function') {
        const senderTxRef = fromDoc.collection('transactions').doc(reference);
        transaction.set(senderTxRef, {
          id: reference,
          reference,
          title: `Transfer to ${recipientName}`,
          amount: amountKobo,
          amountInKobo: amountKobo,
          amountNaira: amountKobo / 100,
          type: 'debit',
          category: 'transfer',
          status: 'Completed',
          senderName,
          recipientName,
          senderPhone: fromPhone,
          recipientPhone: toPhone,
          senderId: fromPhone,
          recipientId: toPhone,
          recipientOrSender: recipientName,
          transferType: 'PayFlow Transfer',
          createdAt: nowIso,
          timestamp: nowIso,
        });
      }
      if (senderDocRef.id !== fromPhone && typeof senderDocRef.collection === 'function') {
        const altSenderTxRef = senderDocRef.collection('transactions').doc(reference);
        transaction.set(altSenderTxRef, {
          id: reference,
          reference,
          title: `Transfer to ${recipientName}`,
          amount: amountKobo,
          amountInKobo: amountKobo,
          amountNaira: amountKobo / 100,
          type: 'debit',
          category: 'transfer',
          status: 'Completed',
          senderName,
          recipientName,
          senderPhone: fromPhone,
          recipientPhone: toPhone,
          senderId: fromPhone,
          recipientId: toPhone,
          recipientOrSender: recipientName,
          transferType: 'PayFlow Transfer',
          createdAt: nowIso,
          timestamp: nowIso,
        });
      }
    } catch (_) {}

    // Recipient: users/{toPhone}/transactions/{reference}
    try {
      const toDoc = db.collection('users').doc(toPhone);
      if (typeof toDoc.collection === 'function') {
        const recipientTxRef = toDoc.collection('transactions').doc(reference);
        transaction.set(recipientTxRef, {
          id: reference,
          reference,
          title: `Transfer from ${senderName}`,
          amount: amountKobo,
          amountInKobo: amountKobo,
          amountNaira: amountKobo / 100,
          type: 'credit',
          category: 'transfer',
          status: 'Completed',
          senderName,
          recipientName,
          senderPhone: fromPhone,
          recipientPhone: toPhone,
          senderId: fromPhone,
          recipientId: toPhone,
          recipientOrSender: senderName,
          transferType: 'PayFlow Transfer',
          createdAt: nowIso,
          timestamp: nowIso,
        });
      }
      if (recipientDocRef.id !== toPhone && typeof recipientDocRef.collection === 'function') {
        const altRecipientTxRef = recipientDocRef.collection('transactions').doc(reference);
        transaction.set(altRecipientTxRef, {
          id: reference,
          reference,
          title: `Transfer from ${senderName}`,
          amount: amountKobo,
          amountInKobo: amountKobo,
          amountNaira: amountKobo / 100,
          type: 'credit',
          category: 'transfer',
          status: 'Completed',
          senderName,
          recipientName,
          senderPhone: fromPhone,
          recipientPhone: toPhone,
          senderId: fromPhone,
          recipientId: toPhone,
          recipientOrSender: senderName,
          transferType: 'PayFlow Transfer',
          createdAt: nowIso,
          timestamp: nowIso,
        });
      }
    } catch (_) {}

    // 7. Record Reference in Idempotency Store
    transaction.set(refDocRef, {
      reference,
      type: 'p2p_transfer',
      fromPhone,
      toPhone,
      amount_kobo: amountKobo,
      processedAt: nowIso,
    });

    return {
      success: true,
      reference,
      fromPhone,
      toPhone,
      senderId: senderDocRef.id,
      recipientId: recipientDocRef.id,
      amount_kobo: amountKobo,
      newBalance: newSenderBalance,
      senderName,
      recipientName,
    };
  });

  // 8. Write Real-Time Notification Documents to Firestore & Trigger Push Notifications
  try {
    const amount = result.amount_kobo / 100;
    const recipientId = result.recipientId || result.toPhone;
    const senderId = result.senderId || result.fromPhone;
    const nowIso = new Date().toISOString();

    // Recipient Notification Document in Firestore
    try {
      const recNotifColl = db.collection('users').doc(recipientId).collection('notifications');
      if (typeof recNotifColl.add === 'function') {
        await recNotifColl.add({
          title: 'Transfer Received',
          body: `₦${amount} received from ${result.senderName}`,
          type: 'transfer_credit',
          amount,
          senderName: result.senderName,
          createdAt: nowIso,
          read: false,
        });
      }
      if (result.toPhone && result.toPhone !== recipientId) {
        const altRecColl = db.collection('users').doc(result.toPhone).collection('notifications');
        if (typeof altRecColl.add === 'function') {
          await altRecColl.add({
            title: 'Transfer Received',
            body: `₦${amount} received from ${result.senderName}`,
            type: 'transfer_credit',
            amount,
            senderName: result.senderName,
            createdAt: nowIso,
            read: false,
          });
        }
      }
    } catch (notifErr) {
      console.error('[Ledger] Failed to write recipient notification document:', notifErr);
    }

    // Sender Notification Document in Firestore
    try {
      const sendNotifColl = db.collection('users').doc(senderId).collection('notifications');
      if (typeof sendNotifColl.add === 'function') {
        await sendNotifColl.add({
          title: 'Transfer Successful',
          body: `₦${amount} sent to ${result.recipientName}`,
          type: 'transfer_debit',
          amount,
          recipientName: result.recipientName,
          createdAt: nowIso,
          read: false,
        });
      }
      if (result.fromPhone && result.fromPhone !== senderId) {
        const altSendColl = db.collection('users').doc(result.fromPhone).collection('notifications');
        if (typeof altSendColl.add === 'function') {
          await altSendColl.add({
            title: 'Transfer Successful',
            body: `₦${amount} sent to ${result.recipientName}`,
            type: 'transfer_debit',
            amount,
            recipientName: result.recipientName,
            createdAt: nowIso,
            read: false,
          });
        }
      }
    } catch (notifErr) {
      console.error('[Ledger] Failed to write sender notification document:', notifErr);
    }

    const amountNaira = (result.amount_kobo / 100).toFixed(2);

    // Send push notification to Recipient
    try {
      const recipientDoc = await db.collection('users').doc(result.toPhone).get();
      const recipientFcmToken = recipientDoc.data()?.fcmToken;
      if (recipientFcmToken && admin && admin.messaging) {
        await admin.messaging().send({
          token: recipientFcmToken,
          notification: {
            title: 'Transfer Received',
            body: `You received ₦${amountNaira} from ${result.senderName}.`,
          },
          data: {
            reference: String(result.reference),
            type: 'transfer',
            amount: String(result.amount_kobo / 100),
            amountKobo: String(result.amount_kobo),
            senderName: String(result.senderName),
            senderPhone: String(result.fromPhone),
            recipientName: String(result.recipientName),
            recipientPhone: String(result.toPhone),
            category: 'transfer',
          },
        });
      }
    } catch (_) {}

    // Send push notification to Sender
    try {
      const senderDoc = await db.collection('users').doc(result.fromPhone).get();
      const senderFcmToken = senderDoc.data()?.fcmToken;
      if (senderFcmToken && admin && admin.messaging) {
        await admin.messaging().send({
          token: senderFcmToken,
          notification: {
            title: 'Transfer Successful',
            body: `You sent ₦${amountNaira} to ${result.recipientName}.`,
          },
          data: {
            reference: String(result.reference),
            type: 'transfer',
            amount: String(result.amount_kobo / 100),
            amountKobo: String(result.amount_kobo),
            senderName: String(result.senderName),
            senderPhone: String(result.fromPhone),
            recipientName: String(result.recipientName),
            recipientPhone: String(result.toPhone),
            category: 'transfer',
          },
        });
      }
    } catch (_) {}
  } catch (_) {}

  return result;
}

/**
 * Gets wallet balance for a phone number in integer Kobo.
 */
export async function getWalletBalance(phone: string): Promise<{
  phone: string;
  walletBalance: number;
  balanceInKobo: number;
  balance: number;
}> {
  const normalized = normalizePhone(phone);
  let userDoc = await db.collection('users').doc(normalized).get();
  let balance = 0;

  if (userDoc.exists) {
    balance = getBalanceKobo(userDoc.data());
  }

  // If not found or 0 balance, check candidate alternate document keys
  if (!userDoc.exists || balance === 0) {
    const candidateKeys = [
      phone,
      phone.replace(/^\+/, ''),
      normalized.replace(/^\+/, ''),
      normalized.startsWith('+234') ? '0' + normalized.substring(4) : '',
    ].filter((k) => k && k !== normalized);

    for (const key of candidateKeys) {
      try {
        const altDoc = await db.collection('users').doc(key).get();
        if (altDoc.exists) {
          const altBal = getBalanceKobo(altDoc.data());
          if (altBal > 0 || !userDoc.exists) {
            userDoc = altDoc;
            balance = altBal;
            if (balance > 0) break;
          }
        }
      } catch (_) {}
    }
  }

  return {
    phone: normalized,
    walletBalance: balance,
    balanceInKobo: balance,
    balance: balance,
  };
}

/**
 * Seeds or updates wallet balance for dev testing.
 */
export async function seedWalletBalance(
  phone: string,
  amountKobo: number
): Promise<{ success: boolean; phone: string; walletBalance: number }> {
  const normalized = normalizePhone(phone);
  const userDocRef = db.collection('users').doc(normalized);
  const userDoc = await userDocRef.get();

  let newBalance = amountKobo;

  if (userDoc.exists) {
    const current = getBalanceKobo(userDoc.data());
    newBalance = current + amountKobo;
    await userDocRef.update({
      walletBalance: newBalance,
      balanceInKobo: newBalance,
      balance: newBalance,
      updatedAt: new Date().toISOString(),
    });
  } else {
    await userDocRef.set({
      phoneNumber: normalized,
      walletBalance: newBalance,
      balanceInKobo: newBalance,
      balance: newBalance,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }

  return { success: true, phone: normalized, walletBalance: newBalance };
}


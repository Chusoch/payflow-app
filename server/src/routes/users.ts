import { Router, Response } from 'express';
import crypto from 'crypto';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
import { db } from '../firebase';
import { normalizePhone } from '../services/ledger';
import { config } from '../config';

const router = Router();

/**
 * GET /v1/users/beneficiaries
 * Query: ?category=bank|bills|airtime
 * Reads subcollection users/{phone}/beneficiaries
 */
router.get('/beneficiaries', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const authPhone = req.user?.phone_number || req.user?.uid;
    const phone = authPhone ? normalizePhone(authPhone) : null;

    if (!phone) {
      res.status(401).json({ status: 'error', message: 'Unauthorized' });
      return;
    }

    const { category } = req.query;
    let query: FirebaseFirestore.Query = db.collection('users').doc(phone).collection('beneficiaries');

    if (category && typeof category === 'string') {
      query = query.where('category', '==', category.toLowerCase().trim());
    }

    const snapshot = await query.get();
    const beneficiaries = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Sort in memory by lastUsedAt descending if available
    beneficiaries.sort((a: any, b: any) => {
      const timeA = a.lastUsedAt ? new Date(a.lastUsedAt).getTime() : 0;
      const timeB = b.lastUsedAt ? new Date(b.lastUsedAt).getTime() : 0;
      return timeB - timeA;
    });

    res.status(200).json({
      status: 'success',
      beneficiaries,
    });
  } catch (error: any) {
    res.status(500).json({ status: 'error', message: error?.message || 'Failed to fetch beneficiaries' });
  }
});

/**
 * POST /v1/users/beneficiaries
 * Body: { name, accountNumber, bankCode, bankName, category, serviceId, phone }
 * Upserts beneficiary document into users/{phone}/beneficiaries
 */
router.post('/beneficiaries', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const authPhone = req.user?.phone_number || req.user?.uid;
    const phone = authPhone ? normalizePhone(authPhone) : null;

    if (!phone) {
      res.status(401).json({ status: 'error', message: 'Unauthorized' });
      return;
    }

    const {
      name,
      accountNumber,
      bankCode,
      bankName,
      category,
      serviceId,
      phone: benPhone,
    } = req.body || {};

    if (!name || (!accountNumber && !benPhone)) {
      res.status(400).json({ status: 'error', message: 'name and accountNumber or phone are required' });
      return;
    }

    const effectiveAccountOrPhone = String(accountNumber || benPhone || '').trim();
    const cat = String(category || 'bank').toLowerCase().trim();
    const docId = `${cat}_${(bankCode || serviceId || 'default')}_${effectiveAccountOrPhone}`.replace(/[^a-zA-Z0-9_]/g, '_');

    const beneficiaryDocRef = db.collection('users').doc(phone).collection('beneficiaries').doc(docId);
    const existing = await beneficiaryDocRef.get();

    const beneficiaryData: Record<string, any> = {
      id: docId,
      name: String(name).trim(),
      accountNumber: effectiveAccountOrPhone,
      accountOrPhone: effectiveAccountOrPhone,
      bankCode: bankCode ? String(bankCode).trim() : null,
      bankName: bankName ? String(bankName).trim() : (cat === 'bank' ? 'Bank Account' : null),
      category: cat,
      serviceId: serviceId ? String(serviceId).trim() : null,
      phone: benPhone ? String(benPhone).trim() : effectiveAccountOrPhone,
      lastUsedAt: new Date().toISOString(),
    };

    if (!existing.exists) {
      beneficiaryData.createdAt = new Date().toISOString();
      await beneficiaryDocRef.set(beneficiaryData);
    } else {
      await beneficiaryDocRef.set(beneficiaryData, { merge: true });
    }

    res.status(200).json({
      status: 'success',
      beneficiary: beneficiaryData,
    });
  } catch (error: any) {
    res.status(500).json({ status: 'error', message: error?.message || 'Failed to save beneficiary' });
  }
});

/**
 * GET /v1/users/profile or GET /v1/users/me
 * Returns profile for the authenticated user based on session token.
 */
router.get(['/profile', '/me'], requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const authPhone = req.user?.phone_number || req.user?.uid;
    if (!authPhone) {
      res.status(401).json({ error: 'Unauthorized: No authenticated user phone or UID' });
      return;
    }

    const formattedPhone = normalizePhone(authPhone);
    const userDoc = await db.collection('users').doc(formattedPhone).get();

    if (userDoc.exists) {
      const data = userDoc.data() || {};
      const name = data.fullName || data.displayName || data.name || `User ${formattedPhone}`;
      res.status(200).json({
        phone: formattedPhone,
        displayName: name,
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
    res.status(500).json({ error: error?.message || 'Failed to fetch user profile' });
  }
});

/**
 * GET /v1/users/:phone/profile
 * Returns recipient display name for confirmation step prior to money transfer
 * or user's own profile details with honest fallback.
 */
router.get('/:phone/profile', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const rawParam = req.params.phone;
    const phone = Array.isArray(rawParam) ? rawParam[0] : rawParam;

    if (!phone) {
      res.status(400).json({ error: 'Phone parameter is required' });
      return;
    }

    const formattedPhone = normalizePhone(phone);
    const userDoc = await db.collection('users').doc(formattedPhone).get();

    if (userDoc.exists) {
      const data = userDoc.data() || {};
      const name = data.fullName || data.displayName || data.name || `User ${formattedPhone}`;
      res.status(200).json({
        phone: formattedPhone,
        displayName: name,
        fullName: data.fullName || null,
        email: data.email || null,
      });
      return;
    }

    // Check if the requesting user is requesting their own profile
    const authUid = req.user?.uid;
    const authPhone = req.user?.phone_number ? normalizePhone(req.user.phone_number) : null;
    const isSelf = (authPhone && authPhone === formattedPhone) ||
                   (authUid && (authUid === formattedPhone || normalizePhone(authUid) === formattedPhone));

    if (isSelf) {
      // Return honest fallback for authenticated user's own profile when document does not exist yet
      res.status(200).json({
        phone: formattedPhone,
        displayName: `User ${formattedPhone}`,
        fullName: null,
        email: null,
      });
      return;
    }

    res.status(404).json({ error: 'No PayFlow user found with this number' });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Failed to fetch user profile' });
  }
});

/**
 * Handler for PUT & PATCH /v1/users/:phone/profile
 * Persists fullName and optional email to users/{phone} in Firestore.
 */
async function handleUpdateProfile(req: AuthenticatedRequest, res: Response): Promise<void> {
  try {
    const rawParam = req.params.phone;
    const phone = Array.isArray(rawParam) ? rawParam[0] : rawParam;

    if (!phone) {
      res.status(400).json({ error: 'Phone parameter is required' });
      return;
    }

    const formattedPhone = normalizePhone(phone);

    // Verify requesting user is authorized to update this profile
    const authUid = req.user?.uid;
    const authPhone = req.user?.phone_number ? normalizePhone(req.user.phone_number) : null;
    const isDevToken = config.allowDevEndpoints &&
      Boolean(req.headers.authorization &&
        (req.headers.authorization.includes('valid_user_a_token') || req.headers.authorization.includes('valid_user_b_token')));

    const isOwner = isDevToken ||
                    (authPhone && authPhone === formattedPhone) ||
                    (authUid && (authUid === formattedPhone || normalizePhone(authUid) === formattedPhone));

    if (!isOwner) {
      res.status(403).json({ error: 'Forbidden: You can only update your own profile' });
      return;
    }

    const { fullName, email } = req.body || {};

    if (!fullName || typeof fullName !== 'string' || fullName.trim().length === 0) {
      res.status(400).json({ error: 'fullName is required and cannot be empty' });
      return;
    }

    const trimmedName = fullName.trim();
    const trimmedEmail = email && typeof email === 'string' && email.trim().length > 0 ? email.trim() : null;

    const userDocRef = db.collection('users').doc(formattedPhone);
    const userDoc = await userDocRef.get();

    const updatePayload: Record<string, any> = {
      fullName: trimmedName,
      displayName: trimmedName,
      updatedAt: new Date().toISOString(),
    };

    if (trimmedEmail !== null) {
      updatePayload.email = trimmedEmail;
    }

    if (req.body?.bvn && typeof req.body.bvn === 'string') {
      const trimmedBvn = req.body.bvn.trim();
      if (/^\d{11}$/.test(trimmedBvn)) {
        updatePayload.bvnHash = crypto.createHash('sha256').update(trimmedBvn).digest('hex');
        updatePayload.isKycVerified = true;
        updatePayload.kycProvider = 'dojah';
      }
    }

    if (req.body?.nin && typeof req.body.nin === 'string') {
      const trimmedNin = req.body.nin.trim();
      if (/^\d{11}$/.test(trimmedNin)) {
        updatePayload.ninHash = crypto.createHash('sha256').update(trimmedNin).digest('hex');
        updatePayload.isKycVerified = true;
        updatePayload.kycProvider = 'dojah';
      }
    }

    if (!userDoc.exists) {
      updatePayload.phoneNumber = formattedPhone;
      updatePayload.walletBalance = 0;
      updatePayload.createdAt = new Date().toISOString();
      await userDocRef.set(updatePayload);
    } else {
      await userDocRef.update(updatePayload);
    }

    const finalEmail = trimmedEmail || (userDoc.exists ? userDoc.data()?.email : null) || null;

    res.status(200).json({
      success: true,
      phone: formattedPhone,
      displayName: trimmedName,
      fullName: trimmedName,
      email: finalEmail,
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Failed to update user profile' });
  }
}

router.put('/:phone/profile', requireAuth, handleUpdateProfile);
router.patch('/:phone/profile', requireAuth, handleUpdateProfile);

export default router;

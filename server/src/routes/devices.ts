import { Router, Response } from 'express';
import { requireAuth, AuthenticatedRequest } from '../middleware/auth';
import { db } from '../firebase';

const router = Router();

/**
 * POST /v1/devices/register
 * Registers/updates the user's FCM device token in Firestore. (Requires Firebase Auth)
 * Body: { fcm_token: string }
 * Note: User identity is strictly resolved from req.user.uid (no client-supplied uid/phone).
 */
router.post('/register', requireAuth, async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  try {
    const { fcm_token } = req.body || {};

    if (!fcm_token || typeof fcm_token !== 'string' || fcm_token.trim().length === 0) {
      res.status(400).json({ error: 'fcm_token string is required' });
      return;
    }

    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ error: 'Unauthorized: missing authenticated user token' });
      return;
    }

    // Save token under users/{userId} doc and users/{userId}/devices/fcm subcollection
    const userDocRef = db.collection('users').doc(userId);
    await userDocRef.set(
      {
        fcmToken: fcm_token.trim(),
        fcmTokenUpdatedAt: new Date().toISOString(),
      },
      { merge: true }
    );

    await userDocRef.collection('devices').doc('fcm').set(
      {
        token: fcm_token.trim(),
        updatedAt: new Date().toISOString(),
      },
      { merge: true }
    );

    res.status(200).json({
      status: 'success',
      message: 'Device token registered successfully',
    });
  } catch (error: any) {
    res.status(500).json({ error: error?.message || 'Failed to register device token' });
  }
});

export default router;

import * as admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { config } from './config';

export let isFirebaseCredentialConfigured = false;

if (!admin.apps.length) {
  const credEnvPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || config.googleApplicationCredentials;

  if (credEnvPath && credEnvPath.trim()) {
    const rawPath = credEnvPath.trim();
    const resolvedPath = path.isAbsolute(rawPath)
      ? rawPath
      : path.resolve(process.cwd(), rawPath);

    if (!fs.existsSync(resolvedPath)) {
      console.error(`================================================================================`);
      console.error(`[Firebase] 🚨 CRITICAL CONFIGURATION ERROR:`);
      console.error(`[Firebase] GOOGLE_APPLICATION_CREDENTIALS is set to: "${rawPath}"`);
      console.error(`[Firebase] But the file does not exist at: "${resolvedPath}"`);
      console.error(`[Firebase] Firebase Admin SDK cannot mint custom authentication tokens without valid credentials.`);
      console.error(`[Firebase] Please ensure GOOGLE_APPLICATION_CREDENTIALS points to a valid service account JSON key file.`);
      console.error(`[Firebase] Falling back to projectId-only initialization ("${config.firebaseProjectId}").`);
      console.error(`================================================================================`);
      try {
        admin.initializeApp({
          projectId: config.firebaseProjectId,
        });
      } catch (err: any) {
        console.error('[Firebase] Failed fallback initialization:', err?.message || err);
      }
    } else {
      try {
        // Ensure process.env.GOOGLE_APPLICATION_CREDENTIALS is set to resolved path
        process.env.GOOGLE_APPLICATION_CREDENTIALS = resolvedPath;
        admin.initializeApp({
          credential: admin.credential.applicationDefault(),
          projectId: config.firebaseProjectId,
        });
        isFirebaseCredentialConfigured = true;
        console.log(`[Firebase] ✅ Firebase Admin SDK initialized successfully with applicationDefault() credentials.`);
        console.log(`[Firebase]    Service Account Key: ${resolvedPath}`);
        console.log(`[Firebase]    Project ID: ${config.firebaseProjectId}`);
      } catch (error: any) {
        console.error(`================================================================================`);
        console.error(`[Firebase] ❌ CRITICAL: Failed to initialize Firebase Admin SDK with credentials:`, error?.message || error);
        console.error(`[Firebase]    File at "${resolvedPath}" could not be loaded as valid Google service account credentials.`);
        console.error(`[Firebase]    Ensure the file is valid JSON downloaded from Firebase Console.`);
        console.error(`[Firebase]    Falling back to projectId-only initialization.`);
        console.error(`================================================================================`);
        try {
          admin.initializeApp({
            projectId: config.firebaseProjectId,
          });
        } catch (err: any) {
          console.error('[Firebase] Failed fallback initialization:', err?.message || err);
        }
      }
    }
  } else {
    // GOOGLE_APPLICATION_CREDENTIALS not set
    try {
      admin.initializeApp({
        projectId: config.firebaseProjectId,
      });
      console.warn(`================================================================================`);
      console.warn(`[Firebase] ⚠️ WARNING: GOOGLE_APPLICATION_CREDENTIALS is not set.`);
      console.warn(`[Firebase]    Firebase Admin SDK initialized with projectId only ("${config.firebaseProjectId}").`);
      console.warn(`[Firebase]    auth.createCustomToken() will FAIL until GOOGLE_APPLICATION_CREDENTIALS is set`);
      console.warn(`[Firebase]    to the absolute path of your Firebase service account JSON key file.`);
      console.warn(`[Firebase]    See server/README.md for instructions on generating and configuring this key.`);
      console.warn(`================================================================================`);
    } catch (error: any) {
      console.warn('Firebase Admin SDK initialization warning:', error?.message || error);
    }
  }
}

export const db = admin.firestore();
export const auth = admin.auth();
export { admin };

import admin from 'firebase-admin';
import { env } from './env';
import { logger } from '../common/utils/logger';

let firebaseApp: admin.app.App | null = null;

export function initializeFirebase(): void {
  if (!env.FIREBASE_PROJECT_ID || !env.FIREBASE_PRIVATE_KEY || !env.FIREBASE_CLIENT_EMAIL) {
    logger.warn('Firebase credentials not configured — push notifications disabled');
    return;
  }

  try {
    firebaseApp = admin.initializeApp({
      credential: admin.credential.cert({
        projectId: env.FIREBASE_PROJECT_ID,
        privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
        clientEmail: env.FIREBASE_CLIENT_EMAIL,
      }),
    });
    logger.info('Firebase Admin SDK initialized');
  } catch (error) {
    logger.error('Failed to initialize Firebase:', error);
  }
}

export async function sendPushNotification(
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<boolean> {
  if (!firebaseApp) return false;

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,
      android: {
        priority: 'high',
        notification: { channelId: 'appointments', sound: 'default' },
      },
    });
    return true;
  } catch (error) {
    logger.error('FCM send failed:', error);
    return false;
  }
}

export async function sendMulticastNotification(
  fcmTokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<{ successCount: number; failureCount: number }> {
  if (!firebaseApp || fcmTokens.length === 0) {
    return { successCount: 0, failureCount: fcmTokens.length };
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens: fcmTokens,
    notification: { title, body },
    data,
    android: { priority: 'high' },
  });

  return {
    successCount: response.successCount,
    failureCount: response.failureCount,
  };
}

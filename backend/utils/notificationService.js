const admin = require('firebase-admin');
const path = require('path');
const dotenv = require('dotenv');

dotenv.config();

let isInitialized = false;

const initializeFirebase = () => {
    if (isInitialized) return;

    try {
        // Try to find the service account file
        const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.join(__dirname, '../config/service-account.json');

        // Check if file exists (basic check, allow require to fail if not)
        // Note: In production, consider using environment variables for the private key content 
        // if files are bad (e.g. Render/Heroku).

        // For now, assume file or env vars
        if (process.env.FIREBASE_PRIVATE_KEY) {
            // Initialize from Env Vars (Render compatible)
            admin.initializeApp({
                credential: admin.credential.cert({
                    projectId: process.env.FIREBASE_PROJECT_ID,
                    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
                    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
                })
            });
            console.log('[NotificationService] Firebase Admin Initialized via Env Vars');
            isInitialized = true;
        } else {
            const serviceAccount = require(serviceAccountPath);
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
            console.log(`[NotificationService] Firebase Admin Initialized via file: ${serviceAccountPath}`);
            isInitialized = true;
        }

    } catch (error) {
        console.warn('[NotificationService] Failed to initialize Firebase Admin. Notifications will not be sent.', error.message);
    }
};

// Initialize on load (optional, or call explicitly)
initializeFirebase();

exports.sendPushNotification = async (tokens, title, body, data = {}) => {
    if (!isInitialized || !tokens || tokens.length === 0) return;

    // Deduplicate and clean tokens
    const uniqueTokens = [...new Set(tokens.filter(t => t && typeof t === 'string' && t.trim() !== ''))];
    if (uniqueTokens.length === 0) return;

    // FCM multicast limit is 500.
    const message = {
        notification: {
            title: title,
            body: body
        },
        data: data, // Custom data like { route: '/orders/123' }
        // [CRITICAL] Platform overrides for High Priority & Heads-up
        android: {
            priority: 'high',
            notification: {
                channelId: 'high_importance_channel', // Must match AndroidManifest
                priority: 'high',
                defaultSound: true,
                defaultVibrateTimings: true,
                visibility: 'public'
            }
        },
        apns: {
            payload: {
                aps: {
                    'content-available': 1, // Wake up app
                    sound: 'default'
                }
            },
            headers: {
                'apns-priority': '10' // High Priority
            }
        },
        tokens: uniqueTokens
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`[NotificationService] Sent ${response.successCount} messages, ${response.failureCount} failed.`);

        if (response.failureCount > 0) {
            const failedTokens = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    failedTokens.push(tokens[idx]);
                    // Check error code to remove invalid tokens
                    // if (resp.error.code === 'messaging/registration-token-not-registered') ...
                }
            });
            // TODO: Remove failed tokens from DB
        }
    } catch (error) {
        console.error('[NotificationService] Error sending message:', error);
        if (error.code) console.error('[NotificationService] Error Code:', error.code);
        if (error.message) console.error('[NotificationService] Error Message:', error.message);
    }
};

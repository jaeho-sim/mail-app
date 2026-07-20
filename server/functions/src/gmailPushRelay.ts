/**
 * gmailPushRelay.ts
 *
 * Relays Gmail push notifications (via Google Cloud Pub/Sub) to devices via
 * Firebase Cloud Messaging. Deployment prerequisites — see
 * docs/PHASE5-BACKGROUND-PUSH.md and scripts/setup_gmail_push.sh:
 *   1. Firebase project on the Blaze (pay-as-you-go) plan.
 *   2. A Pub/Sub topic named `gmail-inbox-updates` with
 *      gmail-api-push@system.gserviceaccount.com granted Publisher on it.
 *   3. The client calling `users.watch` per connected Gmail account,
 *      targeting that topic (see PushRegistrar.swift — handled automatically
 *      once an account is connected and periodically renewed).
 *
 * Deploy: firebase deploy --only functions:onGmailPush
 */

import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

interface GmailPushPayload {
  emailAddress: string;
  historyId: string;
}

/**
 * Triggered by Gmail's Pub/Sub push whenever a watched mailbox changes.
 * The payload only tells us *that* something changed (via historyId), not
 * what — the client re-syncs the specific account via the Gmail API when it
 * wakes up (see PushRegistrar.handleRemoteNotification).
 */
export const onGmailPush = onMessagePublished(
  "gmail-inbox-updates",
  async (event) => {
    const base64Data = event.data.message.data;
    if (!base64Data) return;

    const payload: GmailPushPayload = JSON.parse(
      Buffer.from(base64Data, "base64").toString("utf8")
    );

    const subscriptionsSnapshot = await db
      .collection("pushSubscriptions")
      .where("gmailAddress", "==", payload.emailAddress)
      .get();

    if (subscriptionsSnapshot.empty) {
      console.log(`No push subscriptions registered for ${payload.emailAddress}`);
      return;
    }

    const tokens = subscriptionsSnapshot.docs.map((doc) => doc.data().fcmToken as string);

    await Promise.all(tokens.map((token) => sendSilentPush(token, payload)));
  }
);

/**
 * Sends a silent (content-available / background) push so the client wakes
 * up and syncs just this account, rather than trying to embed message
 * content in the push itself — the client reads `gmailAddress` from the
 * data payload to know which account to re-sync.
 */
async function sendSilentPush(token: string, payload: GmailPushPayload): Promise<void> {
  try {
    await getMessaging().send({
      token,
      data: {
        gmailAddress: payload.emailAddress,
        historyId: payload.historyId,
      },
      apns: {
        payload: {
          aps: {
            "content-available": 1,
          },
        },
        headers: {
          "apns-push-type": "background",
          "apns-priority": "5",
        },
      },
    });
  } catch (error) {
    // A token can go stale (app uninstalled, etc.) — log and move on rather
    // than failing the whole batch. Consider pruning stale tokens from
    // pushSubscriptions on repeated failures.
    console.error(`Failed to send push to token ${token}:`, error);
  }
}

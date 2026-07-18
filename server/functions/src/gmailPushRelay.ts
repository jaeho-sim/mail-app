/**
 * gmailPushRelay.ts
 *
 * Reference sketch for relaying Gmail push notifications (via Google Cloud
 * Pub/Sub) to APNs. NOT deployed — see docs/PHASE5-BACKGROUND-PUSH.md for
 * the setup steps this depends on (Blaze plan, Pub/Sub topic, users.watch,
 * APNs auth key). Written against Firebase Functions v2 + node-apn-style
 * APNs client; adjust to whichever APNs library you end up using.
 */

import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();
const db = getFirestore();

interface GmailPushPayload {
  emailAddress: string;
  historyId: string;
}

/**
 * Triggered by Gmail's Pub/Sub push whenever a watched mailbox changes.
 * The payload only tells us *that* something changed (via historyId), not
 * what — the client re-syncs via the Gmail API when it wakes up.
 */
export const onGmailPush = onMessagePublished(
  "gmail-inbox-updates",
  async (event) => {
    const base64Data = event.data.message.data;
    if (!base64Data) return;

    const payload: GmailPushPayload = JSON.parse(
      Buffer.from(base64Data, "base64").toString("utf8")
    );

    // Look up the device token(s) we stored for this Gmail account when the
    // user signed in (see AuthManager's device-token registration, once added).
    const tokensSnapshot = await db
      .collection("deviceTokens")
      .where("gmailAddress", "==", payload.emailAddress)
      .get();

    if (tokensSnapshot.empty) {
      console.log(`No device tokens registered for ${payload.emailAddress}`);
      return;
    }

    const deviceTokens = tokensSnapshot.docs.map((doc) => doc.data().token as string);

    await Promise.all(deviceTokens.map((token) => sendSilentPush(token, payload)));
  }
);

/**
 * Sends a silent (content-available) push so the client wakes up and syncs,
 * rather than trying to embed message content in the push itself.
 */
async function sendSilentPush(deviceToken: string, payload: GmailPushPayload): Promise<void> {
  // TODO: replace with your APNs client of choice (e.g. `node-apn`, or raw
  // HTTP/2 requests to api.push.apple.com using a .p8 auth key + key ID +
  // team ID from the Developer Program portal).
  console.log(`Would send silent push to ${deviceToken} for ${payload.emailAddress}`);
}

#!/bin/bash
#
# One-time GCP setup for Gmail → Pub/Sub → Cloud Function push relay.
# Run this AFTER upgrading your Firebase project to the Blaze plan
# (Console -> Usage and billing -> Modify plan) — Pub/Sub and Cloud
# Functions aren't available on the free Spark plan.
#
# Requires the gcloud CLI, authenticated against your project:
#   gcloud auth login
#   gcloud config set project YOUR_PROJECT_ID
#
# Usage: ./scripts/setup_gmail_push.sh YOUR_PROJECT_ID

set -euo pipefail

PROJECT_ID="${1:?Usage: ./scripts/setup_gmail_push.sh YOUR_PROJECT_ID}"
TOPIC_NAME="gmail-inbox-updates"

echo "==> Creating Pub/Sub topic $TOPIC_NAME in $PROJECT_ID (skips if it already exists)…"
gcloud pubsub topics create "$TOPIC_NAME" --project "$PROJECT_ID" 2>/dev/null || echo "   (topic already exists)"

echo "==> Granting Gmail's push service account permission to publish to it…"
gcloud pubsub topics add-iam-policy-binding "$TOPIC_NAME" \
  --project "$PROJECT_ID" \
  --member="serviceAccount:gmail-api-push@system.gserviceaccount.com" \
  --role="roles/pubsub.publisher"

echo ""
echo "Done. Topic: projects/$PROJECT_ID/topics/$TOPIC_NAME"
echo ""
echo "If your Firebase/GCP project ID isn't \"mail-app-1\", also update the"
echo "gmailWatchTopic constant in MailApp/Features/MailEngine/PushRegistrar.swift"
echo "to match: projects/$PROJECT_ID/topics/$TOPIC_NAME"
echo ""
echo "Next: deploy the relay function —"
echo "  cd server && firebase deploy --only firestore:rules,functions"

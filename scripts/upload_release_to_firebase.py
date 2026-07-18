#!/usr/bin/env python3
"""
Uploads a built release file (e.g. the notarized MailApp DMG) to Firebase
Storage and prints a public download link.

One-time setup:
  1. pip install --break-system-packages firebase-admin
  2. Firebase Console -> Project Settings -> Service Accounts ->
     "Generate new private key" -> save the JSON somewhere OUTSIDE this repo
     (e.g. ~/.secrets/mailapp-firebase-key.json). Never commit this file.
  3. Firebase Console -> Storage -> make sure Storage is enabled for your
     project (if you've never used Storage before, click "Get Started" once).

Usage:
  export GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/mailapp-firebase-key.json
  python3 scripts/upload_release_to_firebase.py build/MailApp-1.0.dmg

Optional:
  python3 scripts/upload_release_to_firebase.py build/MailApp-1.0.dmg \
    --bucket your-project-id.appspot.com \
    --dest releases/MailApp-1.0.dmg
"""

import argparse
import os
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", help="Path to the file to upload (e.g. the DMG)")
    parser.add_argument(
        "--bucket",
        default=None,
        help="Firebase Storage bucket (defaults to the project's default bucket)",
    )
    parser.add_argument(
        "--dest",
        default=None,
        help="Destination path in the bucket (defaults to releases/<filename>)",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.file):
        print(f"File not found: {args.file}", file=sys.stderr)
        return 1

    if not os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        print(
            "GOOGLE_APPLICATION_CREDENTIALS is not set — point it at your Firebase\n"
            "service account JSON key. See the header of this script for setup steps.",
            file=sys.stderr,
        )
        return 1

    try:
        import firebase_admin
        from firebase_admin import credentials, storage
    except ImportError:
        print(
            "Missing dependency. Run: pip install --break-system-packages firebase-admin",
            file=sys.stderr,
        )
        return 1

    cred = credentials.ApplicationDefault()
    init_kwargs = {}
    if args.bucket:
        init_kwargs["storageBucket"] = args.bucket
    firebase_admin.initialize_app(cred, init_kwargs)

    bucket = storage.bucket()
    filename = os.path.basename(args.file)
    dest_path = args.dest or f"releases/{filename}"

    print(f"Uploading {args.file} -> gs://{bucket.name}/{dest_path} …")
    blob = bucket.blob(dest_path)
    blob.upload_from_filename(args.file)

    # Public read access, scoped to this one object — everything else in the
    # bucket keeps whatever access rules you already have.
    blob.make_public()

    print("")
    print("Done. Public download link:")
    print(f"  {blob.public_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

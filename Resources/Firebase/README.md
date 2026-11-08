Put the Firebase iOS GoogleService-Info.plist here; it is intentionally ignored.
CI writes it from the secure FIREBASE_IOS_PLIST_BASE64 environment variable.
The app reads the file from this preserved Firebase/ resource subdirectory.

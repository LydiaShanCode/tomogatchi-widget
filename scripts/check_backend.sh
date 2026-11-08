#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../backend"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.config}"
export FIREBASE_EMULATORS_PATH="${FIREBASE_EMULATORS_PATH:-/workspace/.cache/firebase/emulators}"
export NPM_CONFIG_CACHE="${NPM_CONFIG_CACHE:-/workspace/.npm}"
if [[ -x /workspace/feed-connor-tools/node_modules/.bin/firebase ]]; then
  export PATH="/workspace/feed-connor-tools/node_modules/node/bin:/workspace/feed-connor-tools/node_modules/.bin:$PATH"
fi
npm --prefix functions test
firebase emulators:exec --project demo-feed-connor --only auth,firestore,functions 'npm --prefix functions run test:rules && cd functions && node --test test/callables.integration.js'

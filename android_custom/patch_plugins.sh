#!/bin/bash
set -e

echo "=== Patching Flutter Pub Dependencies for Android SDK 36 Compatibility ==="

PUB_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
if [ -d "$PUB_DIR" ]; then
  echo "Found pub cache at: $PUB_DIR"
  find "$PUB_DIR" -name "build.gradle" -type f -exec sed -i 's/compileSdk 34/compileSdk 36/g' {} + 2>/dev/null || true
  find "$PUB_DIR" -name "build.gradle" -type f -exec sed -i 's/compileSdkVersion 34/compileSdkVersion 36/g' {} + 2>/dev/null || true
  find "$PUB_DIR" -name "build.gradle" -type f -exec sed -i 's/compileSdk = 34/compileSdk = 36/g' {} + 2>/dev/null || true
  find "$PUB_DIR" -name "build.gradle.kts" -type f -exec sed -i 's/compileSdk = 34/compileSdk = 36/g' {} + 2>/dev/null || true
  echo "Pub cache build.gradle files patched to compileSdk 36."
else
  echo "Warning: Pub cache directory $PUB_DIR not found"
fi

echo "=== Patching completed ==="

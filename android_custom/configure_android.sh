#!/bin/bash
set -e

echo "=== Configuring Native Android for PDFDost ==="

# 1. Copy custom MainActivity with native MediaStore downloads support
mkdir -p android/app/src/main/kotlin/com/devvrushabh/img2pdf
cp android_custom/MainActivity.kt android/app/src/main/kotlin/com/devvrushabh/img2pdf/MainActivity.kt

# 2. Copy custom app launcher icons into mipmap folders
cp -r android_custom/res/* android/app/src/main/res/

# 3. Inject storage permissions and legacy storage into AndroidManifest.xml
sed -i '/<application/i \    <uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>\n    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>\n    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>' android/app/src/main/AndroidManifest.xml
sed -i 's/<application/<application android:requestLegacyExternalStorage="true"/' android/app/src/main/AndroidManifest.xml
sed -i 's/android:label="[^"]*"/android:label="PDFDost"/' android/app/src/main/AndroidManifest.xml

# 4. Configure SDK versions (minSdk 21, compileSdk 36)
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 21/' android/app/build.gradle.kts 2>/dev/null || true
sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 21/' android/app/build.gradle 2>/dev/null || true
sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/' android/app/build.gradle.kts 2>/dev/null || true
sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/' android/app/build.gradle.kts 2>/dev/null || true
sed -i 's/compileSdkVersion flutter.compileSdkVersion/compileSdkVersion 36/' android/app/build.gradle 2>/dev/null || true
sed -i 's/targetSdkVersion flutter.targetSdkVersion/targetSdkVersion 36/' android/app/build.gradle 2>/dev/null || true

# 5. Use pre-installed runner NDK instead of triggering failed sdkmanager downloads
NDK_DIR=""
if [ -d "$ANDROID_HOME/ndk" ] && [ -n "$(ls -A "$ANDROID_HOME/ndk" 2>/dev/null)" ]; then
  NDK_DIR="$ANDROID_HOME/ndk"
elif [ -d "/usr/local/lib/android/sdk/ndk" ] && [ -n "$(ls -A "/usr/local/lib/android/sdk/ndk" 2>/dev/null)" ]; then
  NDK_DIR="/usr/local/lib/android/sdk/ndk"
fi

if [ -n "$NDK_DIR" ]; then
  INSTALLED_NDK=$(ls -1 "$NDK_DIR" | sort -V | tail -n 1)
  echo "Using preinstalled Android NDK: $INSTALLED_NDK from $NDK_DIR"
  sed -i "s/ndkVersion = flutter.ndkVersion/ndkVersion = \"$INSTALLED_NDK\"/" android/app/build.gradle.kts 2>/dev/null || true
  sed -i "s/ndkVersion flutter.ndkVersion/ndkVersion \"$INSTALLED_NDK\"/" android/app/build.gradle 2>/dev/null || true
else
  echo "No preinstalled NDK found; removing ndkVersion declaration"
  sed -i '/ndkVersion/d' android/app/build.gradle.kts 2>/dev/null || true
  sed -i '/ndkVersion/d' android/app/build.gradle 2>/dev/null || true
fi

# 6. Suppress unsupported compileSdk checks in gradle.properties
echo "android.suppressUnsupportedCompileSdk=36" >> android/gradle.properties

# 7. Force all subprojects (e.g. file_picker) to compile with compileSdk 36 so checkReleaseAarMetadata succeeds
if [ -f "android/build.gradle.kts" ]; then
  cat << 'EOF' >> android/build.gradle.kts

subprojects {
    afterEvaluate {
        val isAndroid = plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")
        if (isAndroid) {
            extensions.findByName("android")?.let { androidExt ->
                if (androidExt is com.android.build.gradle.BaseExtension) {
                    androidExt.compileSdkVersion(36)
                }
            }
        }
    }
}
EOF
fi

if [ -f "android/build.gradle" ]; then
  cat << 'EOF' >> android/build.gradle

subprojects {
    afterEvaluate { project ->
        if (project.hasProperty("android")) {
            project.android {
                compileSdkVersion 36
            }
        }
    }
}
EOF
fi

echo "=== Native Android configuration completed successfully ==="

# Plan: Fix Android Build (AGP/Kotlin) and Run on Samsung S6

## Summary
The Android build currently fails at `:app:checkDebugAarMetadata` because several AndroidX dependencies require **Android Gradle Plugin (AGP) 8.9.1+**, while the project is using **AGP 8.6.1**. The plan upgrades AGP and Kotlin Gradle Plugin (KGP) to compatible versions, resets cached Gradle state, then verifies that `flutter run` launches on the connected Samsung S6.

## Current State Analysis (Observed)
- Device connectivity works:
  - `adb devices` shows a physical Android device (Samsung S6 / SM G928C).
  - `flutter devices` lists the Android device.
- Build failure (from terminal):
  - `Execution failed for task ':app:checkDebugAarMetadata'`
  - Dependencies requiring AGP 8.9.1+:
    - `androidx.browser:browser:1.9.0`
    - `androidx.activity:activity(-ktx):1.12.4`
    - `androidx.core:core(-ktx):1.18.0`
    - `androidx.navigationevent:navigationevent-android:1.0.2`
- Android build configuration is driven by:
  - AGP/KGP versions in [settings.gradle.kts](file:///c:/Users/k/Desktop/hallaq/android/settings.gradle.kts#L20-L24)
  - Gradle wrapper in [gradle-wrapper.properties](file:///c:/Users/k/Desktop/hallaq/android/gradle/wrapper/gradle-wrapper.properties#L1-L5)
  - Performance/caching flags in [gradle.properties](file:///c:/Users/k/Desktop/hallaq/android/gradle.properties#L1-L9)
- A helper runner script exists to consistently run on a real device and keep caches off C::
  - [run_android.ps1](file:///c:/Users/k/Desktop/hallaq/run_android.ps1)

## Proposed Changes

### 1) Upgrade AGP to satisfy AAR metadata requirements
- File: [settings.gradle.kts](file:///c:/Users/k/Desktop/hallaq/android/settings.gradle.kts#L20-L24)
- Change:
  - `id("com.android.application") version "8.6.1" apply false`
  - → upgrade to **8.11.1** (>= 8.9.1 required by dependencies; also meets Flutter’s “soon be dropped” warning threshold).
- Why:
  - Fixes `checkDebugAarMetadata` failure caused by modern AndroidX artifacts requiring newer AGP.

### 2) Upgrade Kotlin Gradle Plugin to a supported version for the upgraded AGP
- File: [settings.gradle.kts](file:///c:/Users/k/Desktop/hallaq/android/settings.gradle.kts#L20-L24)
- Change:
  - `id("org.jetbrains.kotlin.android") version "2.1.21" apply false`
  - → upgrade to **2.2.20** (matches Flutter’s guidance “at least 2.2.20 soon” and reduces Kotlin/AGP mismatch risk).
- Why:
  - Keeps Kotlin tooling aligned with the upgraded Android build stack and avoids Kotlin compiler edge-case failures.

### 3) Reset build caches that can preserve stale AGP/Kotlin state
- Commands (PowerShell):
  - Kill any stuck Gradle/Java processes:
    - `taskkill /F /IM java.exe`
  - Clear project-local Gradle state:
    - `Remove-Item -Recurse -Force .\android\.gradle -ErrorAction SilentlyContinue`
    - `Remove-Item -Recurse -Force .\android\app\build -ErrorAction SilentlyContinue`
    - `Remove-Item -Recurse -Force .\build -ErrorAction SilentlyContinue`
  - Optionally (only if builds still hang): clear wrapper dists in the cache root used by the script:
    - `Remove-Item -Recurse -Force G:\hallaq_cache\gradle_home\wrapper\dists -ErrorAction SilentlyContinue`
- Why:
  - Prevents “cached old plugin version” and resolves intermittent Kotlin incremental cache corruption.

### 4) Verify end-to-end: build + install + launch on the Samsung S6
- Commands:
  - `powershell -ExecutionPolicy Bypass -File .\run_android.ps1`
- Expected:
  - Gradle completes `assembleDebug`
  - APK installs to the connected device
  - App launches on-device (not Chrome/Edge)

## Assumptions & Decisions
- Keep Gradle wrapper at its current 8.x version unless AGP upgrade requires a specific minimum. Current wrapper is already Gradle 8.14 which is within the Gradle 8 line and should remain compatible with the pre-AGP-9 Flutter template.
- Do not upgrade Flutter/Dart packages broadly (e.g., `share_plus`, `geolocator`) unless the AGP/Kotlin upgrade still leaves an error. This keeps the change set minimal and avoids breaking API changes in app code.

## Verification Steps (Must Pass)
1. `flutter doctor -v` shows Android toolchain OK and device detected.
2. `adb devices` shows the Samsung S6 as `device` (authorized).
3. `flutter run -d <deviceId>` installs and launches successfully.
4. No `checkDebugAarMetadata` failure.


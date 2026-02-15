# Yes Chef: App Store Prep (Code-First Audit)

**Date:** 2026-02-15
**Goal:** Prepare the Yes Chef iOS app for its first App Store submission.
**Approach:** Code-First Audit — fix code-level issues that would block or risk rejection, draft metadata, create a submission checklist.

## Scope

### 1. Disable Share Extension
- Remove the Share Extension target from the main app's build scheme
- Keep source files in the repo for future use
- Rationale: Extension is broken (reverted), has `TRUEPREDICATE` activation rule (rejection risk), and targets iOS 26.0 (mismatch with main app's 18.5)

### 2. Create Privacy Manifest
- Create `PrivacyInfo.xcprivacy` in the main app target
- Declare required reason APIs used by the app and dependencies (SwiftData file timestamps, WebRTC network APIs)
- Required by Apple since May 2024

### 3. Add Privacy Policy Link
- Host a privacy policy at `yes-chef.ai/privacy` (owner responsibility)
- Add a privacy policy link to the Settings screen in the app
- Required by Apple for apps using camera, microphone, and network access

### 4. Fix Token Logging
- `RecipeVoiceAssistant.swift:106` prints ephemeral OpenAI token to console
- Wrap in `#if DEBUG` to prevent leaking in production builds

### 5. Add Photo Library Usage Description
- Add `NSPhotoLibraryUsageDescription` to build settings
- Safety measure: app uses `PHPickerViewController` for image import

### 6. Investigate Deployment Target
- Check all Swift files for iOS 18+ only APIs
- If no blockers found, lower deployment target from iOS 18.5 to iOS 17.0
- Goal: broaden audience reach

### 7. Draft App Store Metadata
- App description (short subtitle + long description)
- Keywords (up to 100 characters)
- Category: Food & Drink
- "What's New" text for v1.0
- Submission checklist covering App Store Connect requirements

## Out of Scope
- Bug fixes and QA testing
- New features
- UI test coverage
- Share Extension fixes (deferred to future update)
- Screenshot generation (requires device/simulator)

## Files to Change
| File | Change |
|------|--------|
| Build scheme | Remove Share Extension target |
| `Yes Chef/PrivacyInfo.xcprivacy` | Create new |
| `Yes Chef/Settings/Settings.swift` | Add privacy policy link |
| `Yes Chef/Recipes/RecipeVoiceAssistant.swift` | Wrap token print in `#if DEBUG` |
| `Yes Chef.xcodeproj/project.pbxproj` | Add photo library usage description, possibly lower deployment target |
| `docs/app-store-metadata.md` | Create with drafted metadata and submission checklist |

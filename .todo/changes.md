# Summary of Changes: Model Management Lifecycle & PR #7 Fixes

## 1. Overview
This update addresses the latest review comment on Pull Request #7 (P1 issue where unverified or failed models could be re-activated on disk) and refines the AI Model Management lifecycle in the Sync Center to follow explicit user requirements.

---

## 2. P1 Fix & Enhancements in `ModelStore` (`lib/data/models_ota/model_store.dart`)
- **Resolved Auto-Activation of Failed Models:**
  - Removed code in `activeBundleDir()` that automatically selected `installed.first` when `ACTIVE` was `null`.
  - Added verification check, such that if the bundle pointed to by `ACTIVE` is not verified (`ModelBundleStatus.verified`) or its files are missing, it clears `ACTIVE` and returns `null`.
- **Injectable Root Directory:**
  - Added optional `Future<Directory> Function()? rootProvider` parameter to `ModelStore` constructor, enabling tests to run against a real on-disk `ModelStore` backed by temporary directories rather than relying on mocks.
- **Newest Verified Model Lookup:**
  - Added `findNewestVerifiedBundleKey({String? excludingKey})` to identify the newest verified model on disk based on release timestamp (`released_utc`) and version metadata.

---

## 3. Decoupled Download, Smoke Test & Activation (`ModelUpdatePipeline` & `OnnxInferenceEngine`)
- **Non-Destructive ONNX Smoke Test:**
  - Added `smokeTestBundleDir(Directory bundleDir, Uint8List sampleBytes)` to `OnnxInferenceEngine`. Validates NHWC/RGB input layout and output tensor ranges directly against staged bundle directories without mutating active engine state or `ACTIVE` pointers.
- **Explicit Lifecycle Phases:**
  - **Download Step:** Validates download integrity, extracts to bundle directory, and marks state as `ModelBundleStatus.downloaded`. If network or archive extraction fails, cleans up temporary files and surfaces an error.
  - **Verification Step:** Runs per-file SHA256 checksums, digital signature validation, and the ONNX smoke test. Succeeded bundles transition to `ModelBundleStatus.verified`.
  - **No Auto-Activation:** Verified models are not automatically set as active. Activation requires explicit user selection via `activateExisting(bundleKey)`.

---

## 4. Service-Level Fallback & Server-Local Merging (`ModelUpdateService` & `MockSyncRepository`)
- **Default State:** Defaults to no model selected (`getInstalledModelVersion()` returns `null` when no verified model is active).
- **Refresh Catalog:** Merges server models (`GET /models` and `/models/check`) with models stored locally on the device so both remote and local models are displayed.
- **Active Model Deletion Fallback:**
  - When the active model is deleted, `deleteModelBundle()` automatically identifies the newest remaining verified model in the app and activates it.
  - If no verified models remain, it resets to the default state (no model selected) and clears settings.

---

## 5. Sync Center UI & Feedback (`SyncCenterScreen`)
- **Active Model Banner:** Displays current active model or default message (`Belum Ada Model Aktif` / `TIDAK ADA MODEL AKTIF`).
- **Model State Badges:** Displays clear state indicators (`Belum Diunduh`, `Diunduh`, `Terverifikasi`, and `Aktif`).
- **Action Buttons per State:**
  - `Belum Diunduh`: **Unduh** button.
  - `Diunduh`: **Verifikasi** / **Verify Ulang** button and **Hapus** button.
  - `Terverifikasi` (inactive): **Gunakan** / **Pilih** button and **Hapus** button.
  - `Terverifikasi` (active): **Aktif** indicator and **Hapus** button.
- **Toast Notifications:** Displays `SnackBar` toast messages on network/download errors, verification completion, model activation, and active model deletion fallback.

---

## 6. Testing & Quality Verification
- **P1 Regression Tests (`test/operator_model_update_test.dart`):**
  - Tested with a real `ModelStore` on disk: bundles marked `verificationFailed` never re-activate after `clearActive()` when calling `activeBundleDir()`.
  - Tested active model deletion fallback to the newest verified model and fallback to `null` when no verified models remain.
- **Test Suites:**
  - `test/operator_model_update_test.dart`: 10/10 tests passed.
  - `test/sync_center_test.dart`: 14/14 tests passed.
- **Static Analysis:** `flutter analyze` completed with 0 issues.

---

## 7. Screening/Diagnosis Button Contrast & Tablet Camera Ergonomics

### A. Screening / Diagnosis Disabled & Inactive Button Contrast
- **Issue:** The app uses a light Material theme (`onSurface = 0xFF111827`) while the Diagnosis Result & Input tabs use dark surface cards (`0xFF1A1E2B`). Disabled `OutlinedButton` widgets defaulted `disabledForegroundColor` to dark navy (`0x61111827`), making disabled action buttons (`PDF`, `Cetak`, `Tersimpan`) almost invisible against the dark background.
- **Fixes:**
  - **`RuntimeAndActionsCard` (`lib/features/diagnosis/presentation/widgets/result/runtime_and_actions_card.dart`):** Set explicit `disabledForegroundColor: kResultTextLoColor` (`0xFF94A3B8`), `backgroundColor: kResultSurfaceAltColor`, `disabledBackgroundColor: kResultSurfaceAltColor.withValues(alpha: 0.55)`, and a visible border (`0x24FFFFFF` when disabled, `0x40FFFFFF` when enabled).
  - **`XrayImageCard` (`lib/features/diagnosis/presentation/widgets/result/xray_image_card.dart`):** Brightened unselected view mode toggle buttons (`Rontgen`, `Paru`, `Lesi`) to `kResultTextHiColor.withValues(alpha: 0.85)` with a `0x33FFFFFF` border.
  - **`DiagnosisInputTab` (`lib/features/diagnosis/presentation/widgets/diagnosis_input_tab.dart`):** Added explicit `disabledForegroundColor` to `Atur Ulang` (`diagnosisMuted`) and `Analisis` (`Colors.white.withValues(alpha: 0.75)`).

### B. Right-Center Camera Capture Controls for Tablet Usage
- **Issue:** On a tablet held with two hands (left and right edges), the bottom-center camera capture button was difficult to reach with the thumb.
- **Fixes (`lib/features/camera/presentation/camera_screen.dart`):**
  - Repositioned live `_captureControls` from bottom-center (`Positioned(bottom: 36, left: 0, right: 0)`) to **right-center** (`Positioned(top: 0, bottom: 0, right: 24, child: Center(child: _captureControls()))`).
  - Converted `_captureControls` from a horizontal `Row` into a vertical `Column` inside a rounded translucent pill (`Colors.black38`) with Flash on top, the `82x82` shutter button (`Key('camera-capture-shutter-button')`) in the vertical center, and Switch Camera at the bottom.
  - Adjusted the error banner right inset when live controls are visible so they never overlap, and added `disabledForegroundColor` to post-capture confirmation buttons (`Ulangi` / `Gunakan Foto`).
- **Verification:**
  - Added widget tests in `test/diagnosis_result_tab_test.dart` and `test/camera_screen_orientation_test.dart` (28/28 tests passed).

---

## 8. Model Sync & Data Backup UI Localization (`EN` / `ID`)
- **Issue:** Strings across `SyncCenterScreen` (`_ModelUpdateCard`, `_DataBackupCard`, `_ConsentDialog`) and `initiateModelStandbyWithDialog` used plain `Text(...)` widgets or lacked English/Indonesian mappings in `app_language.dart`, leaving the Sync Center untranslated when switching the app language to English (`ENG`).
- **Fixes:**
  - **`lib/core/localization/app_language.dart`:** Added static translations in `_stagingEnglish` (which also auto-populates `_stagingIndonesian`) and dynamic pattern matchers in `localize()` for model versions, counts, progress percentages, timestamps, deletion dialogs, and error messages.
  - **`lib/features/sync/presentation/sync_center_screen.dart` & `lib/features/shared/presentation/model_initiation_dialog.dart`:** Replaced hardcoded `Text(...)` widgets with `AppText(...)`, localized tooltips via `localize(context, ...)`, and fixed UTF-8 punctuation (`•` and `—`).
- **Verification:**
  - Added `SyncCenterScreen language localization (EN / ID)` widget test in `test/sync_center_test.dart` (`18/18` tests in `sync_center_test.dart` and `language_regression_test.dart` passed).

---

## 9. Comprehensive UI Localization Audit & Full Test Suite Pass
- **Audit & Standardization across All Screens:**
  - Audited all user-facing presentation pages across `lib/features/` (`account`, `auth`, `camera`, `dashboard`, `dataset`, `diagnosis`, `institution`, `patients`, `shared`, `sync`, `validation`).
  - **`lib/features/diagnosis/presentation/widgets/diagnosis_input_tab.dart`:** Replaced raw `Text` widgets in `_SourceSelectionSheet` and `_SourceTile` (sheet title, title, subtitle, USB hint badge) with `AppText`.
  - **`lib/features/diagnosis/presentation/widgets/input/dashed_upload_panel.dart`:** Localized the `'Hapus Rontgen'` tooltip via `localize(context, ...)`.
  - **`lib/features/diagnosis/presentation/widgets/result/runtime_and_actions_card.dart`:** Localized action button tooltips (such as PHI policy disclaimer) with `localize(context, ...)`.
  - **`lib/features/auth/presentation/login_screen.dart`:** Localized form field validators (`Email wajib diisi`, `Format email belum valid`, `Password wajib diisi`) using `context.tr(...)`.
  - **`lib/features/camera/presentation/camera_screen.dart`:** Localized round button tooltips (`Close camera`, `Turn flash off/on`, `Switch camera`) with `localize(context, ...)`.
  - **`lib/features/validation/presentation/validation_screen.dart`:** Converted fallback conflict text to `AppText` with bilingual support for verdicts, doctor notes, and conflict resolution options.
  - **`lib/features/sync/presentation/sync_center_screen.dart`:** Localized connection status chip (`Online` / `Offline`) with `AppText` and added responsive `LayoutBuilder` wrapping to eliminate horizontal overflow at 320px screen width.
- **`lib/core/localization/app_language.dart` Enhancements:**
  - Expanded `_stagingEnglish` with image source selection options, reset confirmations, and tooltips.
  - Expanded `_stagingIndonesian` with tenant metadata, camera control tooltips, doctor review validations, conflict dialog strings, and connection states.
  - Added dynamic regex matchers in `localize()` for screening volume periods with variable day counts, added dates, deletion confirmation prompts, validation error messages, and verdict statuses.
- **Regression Tests & Verification:**
  - Added `newly added UI strings translate correctly in both languages` test in `test/language_regression_test.dart` verifying all audited UI strings translate accurately in both English and Indonesian modes.
  - Ran `flutter analyze` with 0 warnings/errors.
  - Executed the full test suite (`flutter test`) across all 49 test files with temporary directory redirected to `build\tmp`. All **347 test cases passed cleanly** with zero failures.

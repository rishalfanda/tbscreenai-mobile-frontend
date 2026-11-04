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

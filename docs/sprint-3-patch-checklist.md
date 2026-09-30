# Sprint 3 review patch checklist

- [x] P1: Block direct and indirect production packaging/install by disabling production variants. Validate artifact environment in the resolved task graph. Verify production package dry-run fails and demo packaging still works.
- [x] P1: Empty staging Result has no synthetic diagnosis, confidence, or model. Keep labelled synthetic sample in demo. Verify screening navigation.
- [x] P2: Reject demo + USE_HTTP and repository overrides crossing environment boundaries at compile/configuration/runtime layers. Verify staging still binds live adapters.

Validation completed:

- `gradlew :app:packageProductionRelease --dry-run`: rejected with clinical gate message.
- An init-script alias depending on `:app:packageProductionRelease`: rejected because production packaging task does not exist. This verifies variant removal independently of the caller name.
- Demo + USE_HTTP Dart kernel compile: rejected with synthetic-only assertion.
- Full default Flutter suite: 150 passed.
- Staging guard/binding/result suite: 7 passed; no dummy diagnosis/confidence in empty Result, screening navigation works.
- Analyzer: no issues. `git diff --check`: clean.
- Demo release APK rebuilt successfully (57.4 MB): `build/app/outputs/flutter-apk/app-demo-release.apk`.

No staging backend calls or device installation performed. Clinical production gate remains closed.

# Reviewed visual baselines

`diagnosis_form_1900x982.png` was generated and reviewed with Flutter 3.44.7 on
Windows. Keep golden comparison and baseline generation on that platform/SDK.
Do not compare this Windows reference against a Linux renderer or auto-update it
in CI: the original Ubuntu run differed by 25,623 pixels (1.37%), while the same
commit's Windows test passed.

CI runs functional tests on Ubuntu (`flutter test --exclude-tags golden`) and
strict visual comparisons on Windows (`flutter test --tags golden`). Both jobs
must pass. Tests are partitioned by the `golden` tag, not skipped. Failed Windows
comparisons upload `test/failures/` as an artifact.

Before changing a baseline, run on Windows with Flutter 3.44.7:

```sh
flutter test --tags golden
# Only for an intentional UI change; inspect the generated image before commit:
flutter test --tags golden --update-goldens
flutter test --tags golden
```

Preserve pixel-exact comparison. A Linux visual baseline, if introduced later,
must be generated and reviewed separately instead of copying the Windows PNG.

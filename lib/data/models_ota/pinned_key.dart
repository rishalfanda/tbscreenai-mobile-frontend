import 'dart:convert';
import 'dart:typed_data';

/// The Ed25519 **public** key that signs a bundle's `SHA256SUMS`.
///
/// Identical to `week-1/pipeline-app/build/keys/bundle_signing_key_pub.pem` and
/// `week-3/demo_api/keys/bundle_signing_key_pub.pem` — the project-wide root of
/// trust for a model bundle, shared with `inf_app`. Everything else (the
/// manifest, every model file) is verified transitively against `SHA256SUMS`.
/// Rotating the signing key requires an app release.
const String _spkiBase64 =
    'MCowBQYDK2VwAyEA9TTlcEAUeuAG1x+i7+meuqNLyqReN+EtwPQcDaluAcU=';

/// The raw 32-byte Ed25519 public key (the 12-byte SPKI header removed).
Uint8List pinnedPublicKeyBytes() =>
    Uint8List.fromList(base64.decode(_spkiBase64).sublist(12));

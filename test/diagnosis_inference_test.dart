// The clinical core: attaching an X-ray and running inference against the
// backend. Until now the repository contract could only carry a filename, so
// POST /diagnoses/infer had never been called by any client and this path was
// untested on both sides of the wire.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_diagnosis_repository.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/state/diagnosis_provider.dart';

const _serverResponse = {
  'is_positive': true,
  'confidence': 87,
  'processing_time_ms': 2850,
  'model_version': 'TBScreen v2.1.0',
  'findings': {
    'consolidation': 28.4,
    'cavity': 3.2,
    'effusion': 6.1,
    'fibrotic': 0.8,
    'calcification': 1.2,
  },
  'is_mock': true,
};

/// Captures the request the repository actually builds, and replies with
/// whatever the test asks for.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.body = _serverResponse});

  final int statusCode;
  final Map<String, dynamic> body;

  RequestOptions? captured;
  List<int> capturedBody = const [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    if (requestStream != null) {
      capturedBody = await requestStream.expand((chunk) => chunk).toList();
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_RecordingAdapter adapter) {
  final client = ApiClient(baseUrl: 'http://localhost:8000/api/v1');
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('XrayImage', () {
    test('the placeholder is a genuine PNG, not arbitrary bytes', () {
      final image = XrayImage.placeholder();

      // The backend validates by file signature; a placeholder that is not
      // really an image would be rejected with 415 and the flow would look
      // broken for entirely the wrong reason.
      expect(image.bytes.sublist(0, 8),
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(image.isEmpty, isFalse);
    });

    test('carries its filename through', () {
      expect(XrayImage.placeholder('captured_xray.png').filename,
          'captured_xray.png');
    });
  });

  group('HttpDiagnosisRepository', () {
    test('posts the image bytes as multipart to /diagnoses/infer', () async {
      final adapter = _RecordingAdapter();
      final repo = HttpDiagnosisRepository(_client(adapter));

      await repo.runInference(image: XrayImage.placeholder('scan.png'));

      expect(adapter.captured!.path, '/diagnoses/infer');
      expect(adapter.captured!.method, 'POST');
      expect(
        adapter.captured!.headers[Headers.contentTypeHeader].toString(),
        contains('multipart/form-data'),
      );
      // The field name must be "image" — that is what the endpoint binds to.
      expect(utf8.decode(adapter.capturedBody, allowMalformed: true),
          contains('name="image"'));
    });

    test('sends the actual bytes, not just the filename', () async {
      final adapter = _RecordingAdapter();
      final repo = HttpDiagnosisRepository(_client(adapter));
      final image = XrayImage.placeholder();

      await repo.runInference(image: image);

      // The PNG signature has to appear in the request body. The whole point
      // of the contract change was that this could not happen before.
      expect(adapter.capturedBody.length, greaterThan(image.bytes.length));
      expect(
        _containsSequence(adapter.capturedBody, image.bytes),
        isTrue,
        reason: 'request body should contain the image bytes verbatim',
      );
    });

    test('maps the server response onto the outcome model', () async {
      final repo = HttpDiagnosisRepository(_client(_RecordingAdapter()));

      final outcome = await repo.runInference(image: XrayImage.placeholder());

      expect(outcome.isPositive, isTrue);
      expect(outcome.confidence, 87);
      expect(outcome.modelVersion, 'TBScreen v2.1.0');
      // 2850 ms is rendered the way the Result screen already expects.
      expect(outcome.processingTime, '2.9s');
      expect(outcome.consolidation, closeTo(28.4, 0.001));
      expect(outcome.cavity, closeTo(3.2, 0.001));
    });

    test('a response missing findings does not crash the screen', () async {
      final adapter = _RecordingAdapter(body: {
        'is_positive': false,
        'confidence': 12,
        'processing_time_ms': 1000,
        'model_version': 'v1',
        'is_mock': true,
      });
      final repo = HttpDiagnosisRepository(_client(adapter));

      final outcome = await repo.runInference(image: XrayImage.placeholder());

      expect(outcome.consolidation, 0.0);
      expect(outcome.cavity, 0.0);
    });
  });

  group('DiagnosisProvider', () {
    test('will not run without an attached image', () async {
      final provider = DiagnosisProvider(MockDiagnosisRepository());

      await provider.runDiagnosis();

      expect(provider.lastOutcome, isNull);
      expect(provider.isRunning, isFalse);
    });

    test('produces an outcome once an image is attached', () async {
      final provider = DiagnosisProvider(
        HttpDiagnosisRepository(_client(_RecordingAdapter())),
      )..attachPlaceholderImage('xray.png');

      await provider.runDiagnosis();

      expect(provider.hasImage, isTrue);
      expect(provider.imageLabel, 'xray.png');
      expect(provider.lastOutcome?.confidence, 87);
      expect(provider.lastError, isNull);
    });

    test('a server failure clears the outcome instead of keeping a stale one',
        () async {
      final failing = _RecordingAdapter(statusCode: 500, body: const {});
      final provider = DiagnosisProvider(
        HttpDiagnosisRepository(_client(failing)),
      )..attachPlaceholderImage('xray.png');

      await provider.runDiagnosis();

      // Leaving the previous patient's result on screen after a failed run is
      // a misread waiting to happen.
      expect(provider.lastOutcome, isNull);
      expect(provider.lastError, isNotNull);
      expect(provider.isRunning, isFalse);
    });

    test('resetting clears image, outcome and error together', () async {
      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..attachPlaceholderImage('xray.png');

      provider.resetForNewDiagnosis();

      expect(provider.hasImage, isFalse);
      expect(provider.imageLabel, isNull);
      expect(provider.lastOutcome, isNull);
      expect(provider.lastError, isNull);
    });
  });
}

bool _containsSequence(List<int> haystack, List<int> needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

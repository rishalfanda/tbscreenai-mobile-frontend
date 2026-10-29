import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/camera/presentation/camera_screen.dart';

void main() {
  const backCamera90 = CameraDescription(
    name: '0',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );

  const backCamera0 = CameraDescription(
    name: '0',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 0,
  );

  const externalWebcam0 = CameraDescription(
    name: 'external_obsbot',
    lensDirection: CameraLensDirection.external,
    sensorOrientation: 0,
  );

  const externalWebcam90 = CameraDescription(
    name: 'external_90',
    lensDirection: CameraLensDirection.external,
    sensorOrientation: 90,
  );

  const frontCamera270 = CameraDescription(
    name: '1',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 270,
  );

  group('isSensorLandscapeNative', () {
    test('identifies 0° sensor as landscape native', () {
      expect(isSensorLandscapeNative(backCamera0), isTrue);
      expect(isSensorLandscapeNative(externalWebcam0), isTrue);
    });

    test('identifies external lens direction as landscape native regardless of reported degrees', () {
      expect(isSensorLandscapeNative(externalWebcam90), isTrue);
    });

    test('identifies standard mobile sensors (90°/270°) as not landscape native', () {
      expect(isSensorLandscapeNative(backCamera90), isFalse);
      expect(isSensorLandscapeNative(frontCamera270), isFalse);
    });
  });

  group('defaultCaptureOrientationForCamera', () {
    test('returns portraitUp for 0° sensor / external camera when raw is portraitUp (Device 2 / landscape monitor)', () {
      expect(
        defaultCaptureOrientationForCamera(
          externalWebcam0,
          currentOrientation: DeviceOrientation.portraitUp,
        ),
        DeviceOrientation.portraitUp,
      );
      expect(
        defaultCaptureOrientationForCamera(
          backCamera0,
          currentOrientation: DeviceOrientation.portraitUp,
        ),
        DeviceOrientation.portraitUp,
      );
    });

    test('preserves landscape orientations for 0° sensor if tilted', () {
      expect(
        defaultCaptureOrientationForCamera(
          externalWebcam0,
          currentOrientation: DeviceOrientation.landscapeLeft,
        ),
        DeviceOrientation.landscapeLeft,
      );
      expect(
        defaultCaptureOrientationForCamera(
          externalWebcam0,
          currentOrientation: DeviceOrientation.landscapeRight,
        ),
        DeviceOrientation.landscapeRight,
      );
    });

    test('falls back to landscapeLeft for 90° sensor when device is flat on desk (Device 1)', () {
      expect(
        defaultCaptureOrientationForCamera(
          backCamera90,
          currentOrientation: DeviceOrientation.portraitUp,
          fallbackLandscape: DeviceOrientation.landscapeLeft,
        ),
        DeviceOrientation.landscapeLeft,
      );
    });

    test('preserves last known landscape fallback for 90° sensor', () {
      expect(
        defaultCaptureOrientationForCamera(
          backCamera90,
          currentOrientation: DeviceOrientation.portraitUp,
          fallbackLandscape: DeviceOrientation.landscapeRight,
        ),
        DeviceOrientation.landscapeRight,
      );
    });
  });

  group('effectiveCameraOrientation', () {
    test('returns raw landscape orientations untouched', () {
      expect(
        effectiveCameraOrientation(DeviceOrientation.landscapeLeft),
        DeviceOrientation.landscapeLeft,
      );
      expect(
        effectiveCameraOrientation(DeviceOrientation.landscapeRight),
        DeviceOrientation.landscapeRight,
      );
    });

    test(
      'falls back to landscapeLeft when raw is portraitUp (device flat / tertidur or Device 2 no-accel)',
      () {
        expect(
          effectiveCameraOrientation(
            DeviceOrientation.portraitUp,
            description: backCamera90,
          ),
          DeviceOrientation.landscapeLeft,
        );
        expect(
          effectiveCameraOrientation(
            DeviceOrientation.portraitUp,
            description: externalWebcam0,
          ),
          DeviceOrientation.landscapeLeft,
        );
      },
    );

    test('falls back to landscapeLeft when raw is portraitDown without description', () {
      expect(
        effectiveCameraOrientation(DeviceOrientation.portraitDown),
        DeviceOrientation.landscapeLeft,
      );
    });

    test(
      'preserves last known landscape orientation when provided as fallback',
      () {
        expect(
          effectiveCameraOrientation(
            DeviceOrientation.portraitUp,
            fallbackLandscape: DeviceOrientation.landscapeRight,
          ),
          DeviceOrientation.landscapeRight,
        );
      },
    );
  });

  group('cameraPreviewQuarterTurns', () {
    test('Android landscapeLeft returns 3 quarter turns (270° CW / 90° CCW compensation)', () {
      expect(
        cameraPreviewQuarterTurns(
          orientation: DeviceOrientation.landscapeLeft,
          platform: TargetPlatform.android,
        ),
        3,
      );
    });

    test('Android landscapeRight returns 1 quarter turn (90° CW compensation)', () {
      expect(
        cameraPreviewQuarterTurns(
          orientation: DeviceOrientation.landscapeRight,
          platform: TargetPlatform.android,
        ),
        1,
      );
    });

    test('non-Android platforms return 0 quarter turns (native engine auto-rotates)', () {
      expect(
        cameraPreviewQuarterTurns(
          orientation: DeviceOrientation.landscapeLeft,
          platform: TargetPlatform.linux,
        ),
        0,
      );
      expect(
        cameraPreviewQuarterTurns(
          orientation: DeviceOrientation.landscapeLeft,
          platform: TargetPlatform.iOS,
        ),
        0,
      );
      expect(
        cameraPreviewQuarterTurns(
          orientation: DeviceOrientation.landscapeRight,
          platform: TargetPlatform.windows,
        ),
        0,
      );
    });
  });

  group('previewQuarterTurns', () {
    test('back camera 90° sensor is upright (0 turns) in landscapeLeft', () {
      final turns = previewQuarterTurns(
        backCamera90,
        DeviceOrientation.landscapeLeft,
      );
      expect(turns, 0);
    });

    test(
      'back camera 90° sensor without effective fallback would produce 1 turn (mis-scale bug)',
      () {
        // Raw portraitUp without fallback caused the 90° rotation and aspect ratio swap.
        final buggedTurns = previewQuarterTurns(
          backCamera90,
          DeviceOrientation.portraitUp,
        );
        expect(buggedTurns, 1);
      },
    );

    test('back camera 90° sensor produces 2 turns in landscapeRight (180° flip)', () {
      final turns = previewQuarterTurns(
        backCamera90,
        DeviceOrientation.landscapeRight,
      );
      expect(turns, 2);
    });
  });
}

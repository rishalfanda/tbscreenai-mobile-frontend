import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/camera/presentation/camera_screen.dart';

void main() {
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
      'falls back to landscapeLeft when raw is portraitUp (device flat / tertidur)',
      () {
        expect(
          effectiveCameraOrientation(DeviceOrientation.portraitUp),
          DeviceOrientation.landscapeLeft,
        );
      },
    );

    test('falls back to landscapeLeft when raw is portraitDown', () {
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

  group('previewQuarterTurns', () {
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

    const frontCamera270 = CameraDescription(
      name: '1',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );

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

    test(
      'back camera 90° sensor with effective orientation produces 0 turns when device is flat',
      () {
        final fixedTurns = previewQuarterTurns(
          backCamera90,
          effectiveCameraOrientation(DeviceOrientation.portraitUp),
        );
        expect(fixedTurns, 0);
      },
    );

    test('back camera 90° sensor produces 2 turns in landscapeRight (180° flip)', () {
      final turns = previewQuarterTurns(
        backCamera90,
        DeviceOrientation.landscapeRight,
      );
      expect(turns, 2);
    });

    test(
      'front camera 270° sensor with effective orientation is upright in landscapeLeft',
      () {
        final turns = previewQuarterTurns(
          frontCamera270,
          effectiveCameraOrientation(DeviceOrientation.landscapeLeft),
        );
        expect(turns, 0);
      },
    );

    test('native landscape sensor (0°) is consistent in landscapeLeft', () {
      final turns = previewQuarterTurns(
        backCamera0,
        effectiveCameraOrientation(DeviceOrientation.portraitUp),
      );
      expect(
        turns,
        previewQuarterTurns(backCamera0, DeviceOrientation.landscapeLeft),
      );
    });
  });
}


import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/diagnosis/application/xray_image_picker.dart';

base class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile({
    required this.name,
    required String path,
    required this.bytes,
  }) : uri = Uri.file(path);

  @override
  final String name;

  @override
  final Uri uri;

  final Uint8List bytes;

  @override
  XFile get xFile => XFile(path ?? '');

  @override
  int? lengthSync() => bytes.length;

  @override
  Future<int?> length() async => bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);
}

class _FakeImagePicker extends Fake implements ImagePicker {
  _FakeImagePicker({this.pickedFile});

  final XFile? pickedFile;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return pickedFile;
  }
}

void main() {
  final validPngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00,
  ]);
  final validJpegBytes = Uint8List.fromList([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46,
  ]);

  group('XrayImagePicker', () {
    test('pickFromFiles returns null when user cancels picker', () async {
      final picker = XrayImagePicker(
        pickFileHandler: ({allowedExtensions, type = FileType.any}) async {
          return null;
        },
      );

      final result = await picker.pickFromFiles();
      expect(result, isNull);
    });

    test('pickFromFiles returns null when file bytes are empty', () async {
      final picker = XrayImagePicker(
        pickFileHandler: ({allowedExtensions, type = FileType.any}) async {
          return _TestPlatformFile(
            name: 'empty.png',
            path: '/tmp/empty.png',
            bytes: Uint8List(0),
          );
        },
      );

      final result = await picker.pickFromFiles();
      expect(result, isNull);
    });

    test('pickFromFiles returns XrayImage with bytes and filename', () async {
      List<String>? passedExtensions;
      FileType? passedType;

      final picker = XrayImagePicker(
        pickFileHandler: ({allowedExtensions, type = FileType.any}) async {
          passedExtensions = allowedExtensions;
          passedType = type;
          return _TestPlatformFile(
            name: 'chest_xray.png',
            path: '/usb/chest_xray.png',
            bytes: validPngBytes,
          );
        },
      );

      final result = await picker.pickFromFiles();
      expect(result, isNotNull);
      expect(result!.filename, equals('chest_xray.png'));
      expect(result.bytes, equals(validPngBytes));
      expect(result.source, equals(XrayImageSource.gallery));
      expect(result.format, equals(XrayImageFormat.png));
      expect(passedType, equals(FileType.custom));
      expect(passedExtensions, equals(XrayImagePicker.defaultAllowedExtensions));
    });

    test('pickFromGallery returns null when user cancels gallery', () async {
      final fakeImagePicker = _FakeImagePicker(pickedFile: null);
      final picker = XrayImagePicker(imagePicker: fakeImagePicker);

      final result = await picker.pickFromGallery();
      expect(result, isNull);
    });

    test('pickFromGallery returns XrayImage when file selected', () async {
      final fakeXFile = XFile.fromData(validJpegBytes, path: 'gallery_xray.jpg');
      final fakeImagePicker = _FakeImagePicker(pickedFile: fakeXFile);
      final picker = XrayImagePicker(imagePicker: fakeImagePicker);

      final result = await picker.pickFromGallery();
      expect(result, isNotNull);
      expect(result!.filename, equals('gallery_xray.jpg'));
      expect(result.bytes, equals(validJpegBytes));
      expect(result.source, equals(XrayImageSource.gallery));
      expect(result.format, equals(XrayImageFormat.jpeg));
    });
  });
}

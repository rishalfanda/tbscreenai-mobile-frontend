import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/domain/models/xray_image.dart';

enum XrayPickSource {
  usbFiles,
  gallery,
}

typedef FilePickerHandler = Future<PlatformFile?> Function({
  FileType type,
  List<String>? allowedExtensions,
});

class XrayImagePicker {
  XrayImagePicker({
    ImagePicker? picker,
    ImagePicker? imagePicker,
    FilePickerHandler? pickFileHandler,
  })  : _imagePicker = imagePicker ?? picker ?? ImagePicker(),
        _pickFileHandler = pickFileHandler;

  final ImagePicker _imagePicker;
  final FilePickerHandler? _pickFileHandler;

  static const defaultAllowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'dcm',
    'dicom',
    'JPG',
    'JPEG',
    'PNG',
    'DCM',
    'DICOM',
  ];

  /// Picks an image file using the system file manager (Storage Access Framework).
  ///
  /// Opens Android's DocumentsUI or desktop file manager where connected USB
  /// thumb drives (OTG), SD cards, downloads, and internal storage are accessible.
  Future<XrayImage?> pickFromFiles({
    List<String> allowedExtensions = defaultAllowedExtensions,
  }) async {
    final PlatformFile? file = _pickFileHandler != null
        ? await _pickFileHandler(
            type: FileType.custom,
            allowedExtensions: allowedExtensions,
          )
        : await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: allowedExtensions,
          );

    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    return XrayImage.fromBytes(
      bytes: bytes,
      filename: file.name,
      source: XrayImageSource.gallery,
    );
  }

  /// Picks an image from the local photo gallery application.
  Future<XrayImage?> pickFromGallery() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    return XrayImage.fromBytes(
      bytes: await picked.readAsBytes(),
      filename: picked.name,
      source: XrayImageSource.gallery,
    );
  }
}

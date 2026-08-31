import 'package:image_picker/image_picker.dart';
import 'package:myapp/domain/models/xray_image.dart';

class XrayImagePicker {
  XrayImagePicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<XrayImage?> pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    return XrayImage.fromBytes(
      bytes: await picked.readAsBytes(),
      filename: picked.name,
      source: XrayImageSource.gallery,
    );
  }
}

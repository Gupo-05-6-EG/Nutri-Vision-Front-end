import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// De onde vem a foto da refeicao.
enum PhotoSource { camera, gallery }

/// Foto escolhida pelo paciente, pronta para enviar.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Abre a camera ou a galeria; `null` quando o paciente desiste.
typedef PickPhoto = Future<PickedPhoto?> Function(PhotoSource source);

/// Implementacao com o `image_picker`. A foto ja sai reduzida (a IA trabalha
/// com no maximo 1280 px) para o envio ser rapido no 4G.
Future<PickedPhoto?> pickPhotoWithImagePicker(PhotoSource source) async {
  final file = await ImagePicker().pickImage(
    source:
        source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;
  return PickedPhoto(bytes: await file.readAsBytes(), filename: file.name);
}

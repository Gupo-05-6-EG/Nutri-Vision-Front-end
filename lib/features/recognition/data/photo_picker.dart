import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// De onde vem a foto da refeicao.
enum PhotoSource { camera, gallery }

/// Tipo de prato escolhido na camera: vai para a IA como dica de volume.
enum PlateType {
  shallow('Raso', 'raso', Icons.restaurant),
  deep('Fundo', 'fundo', Icons.soup_kitchen_outlined);

  const PlateType(this.label, this.apiValue, this.icon);

  final String label;

  /// Valor de `tipo_prato` em `POST /analises`.
  final String apiValue;
  final IconData icon;
}

/// Foto escolhida pelo paciente, pronta para enviar.
class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.filename,
    this.plateType,
  });

  final Uint8List bytes;
  final String filename;

  /// Nulo quando a foto veio da galeria sem passar pela camera do app.
  final PlateType? plateType;

  PickedPhoto withPlate(PlateType? plate) =>
      PickedPhoto(bytes: bytes, filename: filename, plateType: plate);
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

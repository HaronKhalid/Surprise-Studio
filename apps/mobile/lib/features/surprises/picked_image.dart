import 'dart:typed_data';

/// A photo chosen by the user, decoupled from the picker plugin so it can be tested and faked.
class PickedImage {
  const PickedImage({required this.bytes, required this.mimeType, required this.name});
  final Uint8List bytes;
  final String mimeType;
  final String name;
}

/// Hard limits that mirror the server (apps/api/src/assets/image-validation.ts). The server remains
/// the authority; checking here only saves a pointless upload.
const maxPhotoBytes = 10 * 1024 * 1024;
const maxPhotosPerSurprise = 10;

/// The real format from the file's first bytes, never from its name or what the picker claims.
/// Returns null for anything that is not JPEG, PNG or WebP.
String? sniffImageMime(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (b.length >= 8 && [for (var i = 0; i < 8; i++) b[i] == png[i]].every((x) => x)) return 'image/png';
  if (b.length >= 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

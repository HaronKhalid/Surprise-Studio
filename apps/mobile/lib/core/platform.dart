import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../features/surprises/picked_image.dart';

/// Platform capabilities behind interfaces, so screens can be tested without plugins.

abstract class Sharer {
  Future<void> shareText(String text);
  Future<void> copy(String text);
}

class PlatformSharer implements Sharer {
  const PlatformSharer();

  @override
  Future<void> shareText(String text) => SharePlus.instance.share(ShareParams(text: text));

  @override
  Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));
}

abstract class PhotoPicker {
  /// Lets the user choose up to [limit] photos. Empty if they cancel.
  Future<List<PickedImage>> pickMany(int limit);
}

/// Uses the system photo picker, so the app never needs broad access to the user's gallery.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<List<PickedImage>> pickMany(int limit) async {
    if (limit <= 0) return const [];
    final files = await _picker.pickMultiImage(maxWidth: 2560, maxHeight: 2560, imageQuality: 88, limit: limit < 2 ? 2 : limit);
    final picked = <PickedImage>[];
    for (final f in files.take(limit)) {
      final bytes = await f.readAsBytes();
      // The type comes from the bytes, not the file name or what the picker claims.
      picked.add(PickedImage(bytes: bytes, mimeType: sniffImageMime(bytes) ?? 'application/octet-stream', name: f.name));
    }
    return picked;
  }
}

final sharerProvider = Provider<Sharer>((_) => const PlatformSharer());
final photoPickerProvider = Provider<PhotoPicker>((_) => ImagePickerPhotoPicker());

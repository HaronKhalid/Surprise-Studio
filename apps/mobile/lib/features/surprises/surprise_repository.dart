import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import 'picked_image.dart';
import 'surprise.dart';

abstract class SurpriseRepository {
  Future<List<Surprise>> list();
  Future<Surprise> get(String id);

  /// [changes.recipientName] is required by the API when creating.
  Future<Surprise> create(SurpriseChanges changes);
  Future<Surprise> update(String id, SurpriseChanges changes);
  Future<void> delete(String id);
  Future<Surprise> publish(String id);
  Future<Surprise> unpublish(String id);

  /// Short-lived token for the draft preview page.
  Future<String> previewToken(String id);

  Future<List<Photo>> photos(String surpriseId);
  Future<Photo> uploadPhoto(String surpriseId, PickedImage image);
  Future<void> deletePhoto(String photoId);
  Future<void> setPhotoOrder(String photoId, int sortOrder);
}

class ApiSurpriseRepository implements SurpriseRepository {
  ApiSurpriseRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Surprise>> list() async {
    final data = await _api.get('/surprises') as List;
    return [for (final s in data) Surprise.fromJson(s as Map<String, dynamic>)];
  }

  @override
  Future<Surprise> get(String id) async => Surprise.fromJson(await _api.get('/surprises/$id') as Map<String, dynamic>);

  @override
  Future<Surprise> create(SurpriseChanges changes) async {
    assert(changes.recipientName != null, 'recipientName is required to create a surprise');
    return Surprise.fromJson(await _api.post('/surprises', body: changes.toJson()) as Map<String, dynamic>);
  }

  @override
  Future<Surprise> update(String id, SurpriseChanges changes) async =>
      Surprise.fromJson(await _api.patch('/surprises/$id', body: changes.toJson()) as Map<String, dynamic>);

  @override
  Future<void> delete(String id) async => _api.delete('/surprises/$id');

  @override
  Future<Surprise> publish(String id) async =>
      Surprise.fromJson(await _api.post('/surprises/$id/publish') as Map<String, dynamic>);

  @override
  Future<Surprise> unpublish(String id) async =>
      Surprise.fromJson(await _api.post('/surprises/$id/unpublish') as Map<String, dynamic>);

  @override
  Future<String> previewToken(String id) async =>
      (await _api.post('/surprises/$id/preview') as Map<String, dynamic>)['token'] as String;

  @override
  Future<List<Photo>> photos(String surpriseId) async {
    final data = await _api.get('/assets', query: {'surpriseId': surpriseId}) as List;
    return [for (final p in data) Photo.fromJson(p as Map<String, dynamic>)];
  }

  /// The three-step flow from docs/api.md: ask for a signed URL, send the bytes straight to
  /// storage (they never pass through the API), then ask the server to validate and process them.
  @override
  Future<Photo> uploadPhoto(String surpriseId, PickedImage image) async {
    if (image.bytes.length > maxPhotoBytes) {
      throw const ApiException(code: 'FILE_TOO_LARGE', message: 'File is too large');
    }
    final mime = sniffImageMime(image.bytes);
    if (mime == null) {
      throw const ApiException(code: 'INVALID_FILE_TYPE', message: 'Only JPEG, PNG and WebP images are allowed');
    }
    final slot = await _api.post('/assets/upload-url',
        body: {'surpriseId': surpriseId, 'mimeType': mime, 'size': image.bytes.length}) as Map<String, dynamic>;
    await _api.putToStorage(
      slot['uploadUrl'] as String,
      image.bytes,
      Map<String, String>.from(slot['headers'] as Map),
    );
    return Photo.fromJson(await _api.post('/assets/complete', body: {'assetId': slot['assetId']}) as Map<String, dynamic>);
  }

  @override
  Future<void> deletePhoto(String photoId) async => _api.delete('/assets/$photoId');

  @override
  Future<void> setPhotoOrder(String photoId, int sortOrder) async =>
      _api.patch('/assets/$photoId/order', body: {'sortOrder': sortOrder});
}

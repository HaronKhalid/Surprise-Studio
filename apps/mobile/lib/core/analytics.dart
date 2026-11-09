import 'network/api_client.dart';

/// The closed event list the API accepts (apps/api/src/analytics/event-types.ts).
enum AppEvent {
  appOpened('app_opened'),
  createStarted('create_started'),
  surpriseCreated('surprise_created'),
  templateSelected('template_selected'),
  photoUploaded('photo_uploaded'),
  previewOpened('preview_opened'),
  surprisePublished('surprise_published'),
  shareClicked('share_clicked');

  const AppEvent(this.wire);
  final String wire;
}

abstract class Analytics {
  /// Fire and forget. Analytics must never slow down or break the app.
  void track(AppEvent event, {String? template, String? step});
}

/// Sends only an event name and up to two short tokens: no user id, no content.
class ApiAnalytics implements Analytics {
  ApiAnalytics(this._api);
  final ApiClient _api;

  @override
  void track(AppEvent event, {String? template, String? step}) {
    final metadata = {'template': ?template, 'step': ?step};
    _api
        .post('/analytics/events', body: {'eventType': event.wire, if (metadata.isNotEmpty) 'metadata': metadata}, auth: false)
        .then((_) {}, onError: (_) {});
  }
}

class NoAnalytics implements Analytics {
  const NoAnalytics();
  @override
  void track(AppEvent event, {String? template, String? step}) {}
}

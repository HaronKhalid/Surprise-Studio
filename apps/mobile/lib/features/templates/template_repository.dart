import '../../core/network/api_client.dart';
import 'template.dart';

abstract class TemplateRepository {
  Future<List<Template>> list();
}

class ApiTemplateRepository implements TemplateRepository {
  ApiTemplateRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Template>> list() async {
    final data = await _api.get('/templates') as List;
    return [for (final t in data) Template.fromJson(t as Map<String, dynamic>)];
  }
}

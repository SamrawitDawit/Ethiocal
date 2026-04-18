import '../models/education_model.dart';
import 'api_service.dart';

class EducationService {
  static Future<List<EducationArticle>> getEducationArticles() async {
    try {
      final response = await ApiService.getList('/api/v1/education/', requireAuth: true);
      return response.map((json) => EducationArticle.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load education articles: $e');
    }
  }

  static Future<EducationArticle> getEducationArticle(String articleId) async {
    try {
      final response = await ApiService.get('/api/v1/education/$articleId', requireAuth: true);
      return EducationArticle.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load education article: $e');
    }
  }
}

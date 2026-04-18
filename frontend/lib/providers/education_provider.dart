import 'package:flutter/foundation.dart';
import '../models/education_model.dart';
import '../services/education_service.dart';

class EducationProvider extends ChangeNotifier {
  List<EducationArticle> _articles = [];
  bool _isLoading = false;
  String _error = '';
  String _preferredLanguage = 'English'; // Default to English

  // Getters
  List<EducationArticle> get articles => _articles;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get preferredLanguage => _preferredLanguage;

  // Set language preference
  void setPreferredLanguage(String language) {
    _preferredLanguage = language;
    notifyListeners();
  }

  // Load all education articles
  Future<void> loadArticles() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      _articles = await EducationService.getEducationArticles();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get a specific article by ID (from cached list or fetch if needed)
  EducationArticle? getArticleById(String id) {
    try {
      return _articles.firstWhere((article) => article.id == id);
    } catch (e) {
      return null;
    }
  }

  // Load a specific article (useful when coming from deep link or refresh)
  Future<EducationArticle?> loadArticle(String articleId) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final article = await EducationService.getEducationArticle(articleId);
      
      // Update the article in the cached list if it exists
      final index = _articles.indexWhere((a) => a.id == articleId);
      if (index != -1) {
        _articles[index] = article;
      } else {
        _articles.add(article);
      }
      
      notifyListeners();
      return article;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
    }
  }

  // Refresh articles list
  Future<void> refreshArticles() async {
    await loadArticles();
  }

  // Clear error
  void clearError() {
    _error = '';
    notifyListeners();
  }

  // Get articles filtered by category
  List<EducationArticle> getArticlesByCategory(String category) {
    return _articles.where((article) => 
      article.category.toLowerCase() == category.toLowerCase()
    ).toList();
  }

  // Get all available categories
  List<String> getAvailableCategories() {
    final categories = _articles.map((article) => article.category).toSet().toList();
    categories.sort();
    return categories;
  }
}

class EducationArticle {
  final String id;
  final String title;
  final String titleAmharic;
  final String content;
  final String contentAmharic;
  final String imageUrl;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;

  EducationArticle({
    required this.id,
    required this.title,
    required this.titleAmharic,
    required this.content,
    required this.contentAmharic,
    required this.imageUrl,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EducationArticle.fromJson(Map<String, dynamic> json) {
    return EducationArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      titleAmharic: json['title_amharic'] as String,
      content: json['content'] as String,
      contentAmharic: json['content_amharic'] as String,
      imageUrl: json['image_url'] as String,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_amharic': titleAmharic,
      'content': content,
      'content_amharic': contentAmharic,
      'image_url': imageUrl,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  EducationArticle copyWith({
    String? id,
    String? title,
    String? titleAmharic,
    String? content,
    String? contentAmharic,
    String? imageUrl,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EducationArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      titleAmharic: titleAmharic ?? this.titleAmharic,
      content: content ?? this.content,
      contentAmharic: contentAmharic ?? this.contentAmharic,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper method to get localized title based on language preference
  String getLocalizedTitle(String preferredLanguage) {
    return preferredLanguage.toLowerCase() == 'amharic' ? titleAmharic : title;
  }

  // Helper method to get localized content based on language preference
  String getLocalizedContent(String preferredLanguage) {
    return preferredLanguage.toLowerCase() == 'amharic' ? contentAmharic : content;
  }
}

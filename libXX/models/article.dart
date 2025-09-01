import 'package:cloud_firestore/cloud_firestore.dart';

enum ArticleStatus {
  draft,
  published,
  archived,
}

enum ArticleVisibility {
  internal,
  public,
}

class Article {
  final String id;
  final String vendorId;
  final String title;
  final String content;
  final List<String> tags;
  final String category;
  final ArticleStatus status;
  final ArticleVisibility visibility;
  final String? authorId;
  final String? authorName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final int viewCount;
  final Map<String, dynamic>? metadata;

  Article({
    required this.id,
    required this.vendorId,
    required this.title,
    required this.content,
    required this.tags,
    required this.category,
    required this.status,
    required this.visibility,
    this.authorId,
    this.authorName,
    required this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.viewCount = 0,
    this.metadata,
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'] as String,
      vendorId: map['vendorId'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      tags: List<String>.from(map['tags'] as List),
      category: map['category'] as String,
      status: ArticleStatus.values.firstWhere(
        (e) => e.toString() == 'ArticleStatus.${map['status']}',
      ),
      visibility: ArticleVisibility.values.firstWhere(
        (e) => e.toString() == 'ArticleVisibility.${map['visibility']}',
      ),
      authorId: map['authorId'] as String?,
      authorName: map['authorName'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      publishedAt: map['publishedAt'] != null
          ? (map['publishedAt'] as Timestamp).toDate()
          : null,
      viewCount: map['viewCount'] as int? ?? 0,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'title': title,
      'content': content,
      'tags': tags,
      'category': category,
      'status': status.toString().split('.').last,
      'visibility': visibility.toString().split('.').last,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'publishedAt': publishedAt,
      'viewCount': viewCount,
      'metadata': metadata,
    };
  }

  Article copyWith({
    String? id,
    String? vendorId,
    String? title,
    String? content,
    List<String>? tags,
    String? category,
    ArticleStatus? status,
    ArticleVisibility? visibility,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    int? viewCount,
    Map<String, dynamic>? metadata,
  }) {
    return Article(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      viewCount: viewCount ?? this.viewCount,
      metadata: metadata ?? this.metadata,
    );
  }
} 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/article.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart';

class ArticleService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  ArticleService(this._firestore, this._vendorId, this._notificationService);

  // Article Management
  Stream<List<Article>> streamArticles({
    String? category,
    ArticleStatus? status,
    ArticleVisibility? visibility,
    String? searchQuery,
    DocumentSnapshot? lastDocument,
    int? limit,
  }) {
    Query query = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('articles')
        .orderBy('createdAt', descending: true);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    if (status != null) {
      query =
          query.where('status', isEqualTo: status.toString().split('.').last);
    }
    if (visibility != null) {
      query = query.where('visibility',
          isEqualTo: visibility.toString().split('.').last);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      final articles = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Article.fromMap({...data, 'id': doc.id});
      }).toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return articles.where((article) {
          return article.title.toLowerCase().contains(query) ||
              article.content.toLowerCase().contains(query) ||
              article.tags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
      }

      return articles;
    });
  }

  Future<Article> fetchArticle(String articleId) async {
    final doc = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('articles')
        .doc(articleId)
        .get();

    if (!doc.exists) {
      throw Exception('Article not found');
    }

    return Article.fromMap({...?doc.data()!, 'id': doc.id});
  }

  Future<Article> createArticle({
    required String title,
    required String content,
    required List<String> tags,
    required String category,
    required ArticleVisibility visibility,
    String? authorId,
    String? authorName,
  }) async {
    final docRef = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('articles')
        .doc();

    final article = Article(
      id: docRef.id,
      vendorId: _vendorId,
      title: title,
      content: content,
      tags: tags,
      category: category,
      status: ArticleStatus.draft,
      visibility: visibility,
      authorId: authorId,
      authorName: authorName,
      createdAt: DateTime.now(),
    );

    await docRef.set(article.toMap());

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Article Created',
      message: article.title,
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: {
        'type': 'article',
        'articleId': article.id,
      },
    );

    return article;
  }

  Future<void> updateArticle(
    String articleId, {
    String? title,
    String? content,
    List<String>? tags,
    String? category,
    ArticleVisibility? visibility,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now(),
    };

    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    if (tags != null) updates['tags'] = tags;
    if (category != null) updates['category'] = category;
    if (visibility != null)
      updates['visibility'] = visibility.toString().split('.').last;

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('articles')
        .doc(articleId)
        .update(updates);
  }

  Future<void> updateArticleStatus(
    String articleId,
    ArticleStatus status,
  ) async {
    final updates = {
      'status': status.toString().split('.').last,
      'updatedAt': DateTime.now(),
    };

    if (status == ArticleStatus.published) {
      updates['publishedAt'] = DateTime.now();
    }

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('articles')
        .doc(articleId)
        .update(updates);

    // Send notification for status change
    final article = await fetchArticle(articleId);
    await _notificationService.sendNotification(
      title: 'Article Status Updated',
      message: '${article.title} - ${status.toString().split('.').last}',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: {
        'type': 'article_status',
        'articleId': article.id,
      },
    );
  }

  Future<void> deleteArticle(String articleId) async {
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('articles')
        .doc(articleId)
        .delete();
  }

  Future<void> incrementViewCount(String articleId) async {
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('articles')
        .doc(articleId)
        .update({
      'viewCount': FieldValue.increment(1),
    });
  }

  // Analytics
  Future<Map<String, dynamic>> getArticleSummary() async {
    final snapshot = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('articles')
        .get();

    final articles = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Article.fromMap({...data, 'id': doc.id});
    }).toList();

    Map<String, int> categoryCounts = {};
    Map<ArticleStatus, int> statusCounts = {};
    Map<ArticleVisibility, int> visibilityCounts = {};
    int totalViews = 0;

    for (var article in articles) {
      categoryCounts[article.category] =
          (categoryCounts[article.category] ?? 0) + 1;
      statusCounts[article.status] = (statusCounts[article.status] ?? 0) + 1;
      visibilityCounts[article.visibility] =
          (visibilityCounts[article.visibility] ?? 0) + 1;
      totalViews += article.viewCount;
    }

    return {
      'totalArticles': articles.length,
      'categoryCounts': categoryCounts,
      'statusCounts': statusCounts,
      'visibilityCounts': visibilityCounts,
      'totalViews': totalViews,
    };
  }

  // Category Management
  Future<void> addCategory(String category) async {
    // Check if category already exists
    final summary = await getArticleSummary();
    if (summary['categoryCounts'].containsKey(category)) {
      throw Exception('Category already exists');
    }

    // Add category to categories collection
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('categories')
        .doc(category)
        .set({
      'name': category,
      'createdAt': DateTime.now(),
    });
  }

  Future<void> updateCategory(String oldCategory, String newCategory) async {
    // Check if new category already exists
    final summary = await getArticleSummary();
    if (summary['categoryCounts'].containsKey(newCategory)) {
      throw Exception('Category already exists');
    }

    // Update category in categories collection
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('categories')
        .doc(oldCategory)
        .update({
      'name': newCategory,
      'updatedAt': DateTime.now(),
    });

    // Update category in all articles
    final articles = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('articles')
        .where('category', isEqualTo: oldCategory)
        .get();

    final batch = _firestore.batch();
    for (var doc in articles.docs) {
      batch.update(doc.reference, {
        'category': newCategory,
        'updatedAt': DateTime.now(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteCategory(String category) async {
    // Check if category has articles
    final summary = await getArticleSummary();
    if (summary['categoryCounts'][category]! > 0) {
      throw Exception('Cannot delete category with existing articles');
    }

    // Delete category from categories collection
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('categories')
        .doc(category)
        .delete();
  }
}

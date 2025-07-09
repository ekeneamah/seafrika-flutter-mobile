import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/article.dart';
import 'package:vendor_app/services/article_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class ArticleDetailScreen extends StatefulWidget {
  final String articleId;

  const ArticleDetailScreen({
    super.key,
    required this.articleId,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Article? _article;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final articleService = context.read<ArticleService>();
      final article = await articleService.fetchArticle(widget.articleId);
      await articleService.incrementViewCount(widget.articleId);
      setState(() {
        _article = article;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load article details';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(ArticleStatus status) async {
    try {
      final articleService = context.read<ArticleService>();
      await articleService.updateArticleStatus(widget.articleId, status);
      await _loadArticle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  Future<void> _deleteArticle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Article'),
        content: const Text('Are you sure you want to delete this article?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final articleService = context.read<ArticleService>();
        await articleService.deleteArticle(widget.articleId);
        if (mounted) {
          NavigationService.goBack();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete article')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article Details'),
        actions: [
          if (_article != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                NavigationService.navigateToEditArticle(_article!.id);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteArticle,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadArticle,
                )
              : _article == null
                  ? const Center(child: Text('Article not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _article!.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                              ),
                              _buildStatusChip(_article!.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 16,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_article!.viewCount} views',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.person,
                                size: 16,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _article!.authorName ?? 'Unknown',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildCategoryChip(_article!.category),
                              _buildVisibilityChip(_article!.visibility),
                              ..._article!.tags.map((tag) => Chip(
                                    label: Text(tag),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _article!.content,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          if (_article!.status == ArticleStatus.draft)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _updateStatus(ArticleStatus.published),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Publish'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _updateStatus(ArticleStatus.archived),
                                    child: const Text('Archive'),
                                  ),
                                ),
                              ],
                            ),
                          if (_article!.status == ArticleStatus.published)
                            OutlinedButton(
                              onPressed: () =>
                                  _updateStatus(ArticleStatus.archived),
                              child: const Text('Archive'),
                            ),
                          if (_article!.status == ArticleStatus.archived)
                            OutlinedButton(
                              onPressed: () =>
                                  _updateStatus(ArticleStatus.draft),
                              child: const Text('Restore to Draft'),
                            ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStatusChip(ArticleStatus status) {
    Color color;
    String label;

    switch (status) {
      case ArticleStatus.draft:
        color = Colors.grey;
        label = 'Draft';
        break;
      case ArticleStatus.published:
        color = Colors.green;
        label = 'Published';
        break;
      case ArticleStatus.archived:
        color = Colors.red;
        label = 'Archived';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildVisibilityChip(ArticleVisibility visibility) {
    final color =
        visibility == ArticleVisibility.public ? Colors.green : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        visibility.toString().split('.').last,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

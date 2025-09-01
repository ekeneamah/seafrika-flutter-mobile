import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/article.dart';
import 'package:vendor_app/services/article_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class KnowledgeBaseScreen extends StatefulWidget {
  final String? initialCategory;

  const KnowledgeBaseScreen({
    super.key,
    this.initialCategory,
  });

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedCategory;
  ArticleStatus? _selectedStatus;
  ArticleVisibility? _selectedVisibility;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 10;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreArticles();
    }
  }

  Future<void> _loadMoreArticles() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final articleService = context.read<ArticleService>();
      final articles = await articleService
          .streamArticles(
            category: _selectedCategory,
            status: _selectedStatus,
            visibility: _selectedVisibility,
            searchQuery: _searchQuery,
            lastDocument: _lastDocument,
            limit: _pageSize,
          )
          .first;

      if (articles.length < _pageSize) {
        _hasMore = false;
      }

      if (articles.isNotEmpty) {
        final lastDoc = await FirebaseFirestore.instance
            .collection('articles')
            .doc(articles.last.id)
            .get();
        setState(() => _lastDocument = lastDoc);
      }

      setState(() => _isLoadingMore = false);
    } catch (e) {
      setState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load more articles')),
        );
      }
    }
  }

  void _resetPagination() {
    setState(() {
      _lastDocument = null;
      _hasMore = true;
      _isLoadingMore = false;
    });
  }

  List<Article> _filterArticles(List<Article> articles) {
    return articles.where((article) {
      final matchesSearch = article.title
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          article.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          article.tags.any(
              (tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesCategory =
          _selectedCategory == null || article.category == _selectedCategory;
      final matchesStatus =
          _selectedStatus == null || article.status == _selectedStatus;
      final matchesVisibility = _selectedVisibility == null ||
          article.visibility == _selectedVisibility;
      return matchesSearch &&
          matchesCategory &&
          matchesStatus &&
          matchesVisibility;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              NavigationService.navigateToArticleCategories();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search articles...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                                _resetPagination();
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _resetPagination();
                    });
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildVisibilityChip('All', null),
                      ...ArticleVisibility.values.map(
                        (visibility) => _buildVisibilityChip(
                          visibility.toString().split('.').last,
                          visibility,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('All', null),
                      ...ArticleStatus.values.map(
                        (status) => _buildStatusChip(
                          status.toString().split('.').last,
                          status,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Article>>(
              stream: context.read<ArticleService>().streamArticles(
                    category: _selectedCategory,
                    status: _selectedStatus,
                    visibility: _selectedVisibility,
                    searchQuery: _searchQuery,
                    lastDocument: _lastDocument,
                    limit: _pageSize,
                  ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return error.ErrorView(
                    message: 'Failed to load articles',
                    onRetry: () {
                      setState(() {
                        _resetPagination();
                      });
                    },
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingView();
                }

                final articles = _filterArticles(snapshot.data!);

                if (articles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.article,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Articles Found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Articles will appear here',
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: articles.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == articles.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final article = articles[index];
                    return Card(
                      child: ListTile(
                        onTap: () {
                          NavigationService.navigateToArticleDetail(article.id);
                        },
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(article.status),
                          child: Icon(
                            _getStatusIcon(article.status),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(article.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.category,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Wrap(
                              spacing: 4,
                              children: article.tags.map((tag) {
                                return Chip(
                                  label: Text(
                                    tag,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              article.visibility.toString().split('.').last,
                              style: TextStyle(
                                color: _getVisibilityColor(article.visibility),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${article.viewCount} views',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          NavigationService.navigateToCreateArticle();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildVisibilityChip(String label, ArticleVisibility? visibility) {
    final isSelected = visibility == _selectedVisibility;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedVisibility = selected ? visibility : null;
            _resetPagination();
          });
        },
      ),
    );
  }

  Widget _buildStatusChip(String label, ArticleStatus? status) {
    final isSelected = status == _selectedStatus;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = selected ? status : null;
            _resetPagination();
          });
        },
      ),
    );
  }

  Color _getStatusColor(ArticleStatus status) {
    switch (status) {
      case ArticleStatus.draft:
        return Colors.grey;
      case ArticleStatus.published:
        return Colors.green;
      case ArticleStatus.archived:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(ArticleStatus status) {
    switch (status) {
      case ArticleStatus.draft:
        return Icons.edit;
      case ArticleStatus.published:
        return Icons.check;
      case ArticleStatus.archived:
        return Icons.archive;
    }
  }

  Color _getVisibilityColor(ArticleVisibility visibility) {
    switch (visibility) {
      case ArticleVisibility.internal:
        return Colors.blue;
      case ArticleVisibility.public:
        return Colors.green;
    }
  }
}

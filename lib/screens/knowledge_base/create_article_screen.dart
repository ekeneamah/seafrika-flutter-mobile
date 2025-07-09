import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/article.dart';
import 'package:vendor_app/services/article_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:vendor_app/services/auth_service.dart';

class CreateArticleScreen extends StatefulWidget {
  final String? articleId;

  const CreateArticleScreen({
    super.key,
    this.articleId,
  });

  @override
  State<CreateArticleScreen> createState() => _CreateArticleScreenState();
}

class _CreateArticleScreenState extends State<CreateArticleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  Article? _article;
  String _selectedCategory = 'General';
  ArticleVisibility _selectedVisibility = ArticleVisibility.internal;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.articleId != null) {
      _loadArticle();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadArticle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final articleService = context.read<ArticleService>();
      final article = await articleService.fetchArticle(widget.articleId!);
      setState(() {
        _article = article;
        _titleController.text = article.title;
        _contentController.text = article.content;
        _selectedCategory = article.category;
        _selectedVisibility = article.visibility;
        _tags = article.tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load article details';
        _isLoading = false;
      });
    }
  }

  void _addTag() {
    final tag = _tagsController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagsController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveArticle({bool publish = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final articleService = context.read<ArticleService>();

      if (widget.articleId != null) {
        await articleService.updateArticle(
          widget.articleId!,
          title: _titleController.text,
          content: _contentController.text,
          tags: _tags,
          category: _selectedCategory,
          visibility: _selectedVisibility,
        );

        if (publish) {
          await articleService.updateArticleStatus(
            widget.articleId!,
            ArticleStatus.published,
          );
        }
      } else {
        final article = await articleService.createArticle(
          title: _titleController.text,
          content: _contentController.text,
          tags: _tags,
          category: _selectedCategory,
          visibility: _selectedVisibility,
          authorId: context.read<AuthService>().currentUser?.id ?? '',
          authorName: context.read<AuthService>().currentUser?.fullName ?? '',
        );

        if (publish) {
          await articleService.updateArticleStatus(
            article.id,
            ArticleStatus.published,
          );
        }
      }

      if (mounted) {
        NavigationService.goBack();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save article';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.articleId != null ? 'Edit Article' : 'Create Article'),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadArticle,
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          'General',
                          'Procedures',
                          'How-to Guides',
                          'Policies',
                          'FAQs',
                        ].map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ArticleVisibility>(
                        value: _selectedVisibility,
                        decoration: const InputDecoration(
                          labelText: 'Visibility',
                          border: OutlineInputBorder(),
                        ),
                        items: ArticleVisibility.values.map((visibility) {
                          return DropdownMenuItem(
                            value: visibility,
                            child: Text(visibility.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedVisibility = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Content',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 10,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter content';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tagsController,
                              decoration: const InputDecoration(
                                labelText: 'Add Tags',
                                border: OutlineInputBorder(),
                              ),
                              onFieldSubmitted: (_) => _addTag(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _addTag,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _tags.map((tag) {
                            return Chip(
                              label: Text(tag),
                              onDeleted: () => _removeTag(tag),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                NavigationService.goBack();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _saveArticle(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Text('Save Draft'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _saveArticle(publish: true),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Text('Publish'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

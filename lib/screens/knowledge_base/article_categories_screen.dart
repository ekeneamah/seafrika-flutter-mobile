import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/services/article_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class ArticleCategoriesScreen extends StatefulWidget {
  const ArticleCategoriesScreen({super.key});

  @override
  State<ArticleCategoriesScreen> createState() =>
      _ArticleCategoriesScreenState();
}

class _ArticleCategoriesScreenState extends State<ArticleCategoriesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  Map<String, int> _categoryCounts = {};
  String? _editingCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final articleService = context.read<ArticleService>();
      final summary = await articleService.getArticleSummary();
      setState(() {
        _categoryCounts = Map<String, int>.from(summary['categoryCounts']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load categories';
        _isLoading = false;
      });
    }
  }

  Future<void> _showCategoryDialog({String? category}) async {
    _categoryController.text = category ?? '';
    _editingCategory = category;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a category name';
              }
              if (value != category && _categoryCounts.containsKey(value)) {
                return 'Category already exists';
              }
              return null;
            },
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final articleService = context.read<ArticleService>();
        if (category == null) {
          // Add new category
          await articleService.addCategory(_categoryController.text);
        } else {
          // Update existing category
          await articleService.updateCategory(
              category, _categoryController.text);
        }
        await _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                category == null
                    ? 'Failed to add category'
                    : 'Failed to update category',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "$category"? '
          'This will remove the category from all articles.',
        ),
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
        await articleService.deleteCategory(category);
        await _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete category')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article Categories'),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadCategories,
                )
              : _categoryCounts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.category,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Categories',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add categories to organize your articles',
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categoryCounts.length,
                      itemBuilder: (context, index) {
                        final category = _categoryCounts.keys.elementAt(index);
                        final count = _categoryCounts[category]!;
                        return Card(
                          child: ListTile(
                            onTap: () {
                              // Navigate to filtered article list
                              NavigationService.navigateToKnowledgeBase(
                                initialCategory: category,
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: Text(
                                category[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(category),
                            subtitle:
                                Text('$count article${count == 1 ? '' : 's'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showCategoryDialog(category: category),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteCategory(category),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/supplier.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/supplier_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 10;
  DocumentSnapshot? _lastDocument;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      _loadMoreSuppliers();
    }
  }

  Future<void> _loadMoreSuppliers() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final supplierService = context.read<SupplierService>();
      final suppliers = await supplierService
          .streamSuppliers(
            searchQuery: _searchQuery,
            lastDocument: _lastDocument,
            limit: _pageSize,
          )
          .first;

      if (suppliers.length < _pageSize) {
        _hasMore = false;
      }

      if (suppliers.isNotEmpty) {
        final lastDoc = await _firestore
            .collection('suppliers')
            .doc(suppliers.last.id)
            .get();
        _lastDocument = lastDoc;
      }

      setState(() => _isLoadingMore = false);
    } catch (e) {
      setState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load more suppliers')),
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

  void _onCreateSupplier() {
    NavigationService.navigateToCreateSupplier();
  }

  void _onSupplierTap(Supplier supplier) {
    NavigationService.navigateToSupplierDetail(supplier.id);
  }

  void _onEditSupplier(Supplier supplier) {
    NavigationService.navigateToEditSupplier(supplier.id);
  }

  Future<void> _onDeleteSupplier(Supplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content:
            Text('Are you sure you want to delete ${supplier.companyName}?'),
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
        final supplierService = context.read<SupplierService>();
        await supplierService.deleteSupplier(supplier.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete supplier')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => NavigationService.navigateToSupplierAnalytics(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search suppliers...',
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
          ),
          Expanded(
            child: StreamBuilder<List<Supplier>>(
              stream: context.read<SupplierService>().streamSuppliers(
                    searchQuery: _searchQuery,
                    lastDocument: _lastDocument,
                    limit: _pageSize,
                  ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return error.ErrorView(
                    message: 'Failed to load suppliers',
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

                final suppliers = snapshot.data!;

                if (suppliers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.business,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Suppliers',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add your first supplier',
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: suppliers.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == suppliers.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final supplier = suppliers[index];
                    return Card(
                      child: ListTile(
                        onTap: () => _onSupplierTap(supplier),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            supplier.companyName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(supplier.companyName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.contactPerson,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              supplier.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _onEditSupplier(supplier),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _onDeleteSupplier(supplier),
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
        onPressed: _onCreateSupplier,
        child: const Icon(Icons.add),
      ),
    );
  }
}

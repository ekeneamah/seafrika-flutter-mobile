import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/customer.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/customer_service.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _vendorId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _vendorId = context.read<AuthService>().currentUser?.id;
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
      _loadMoreCustomers();
    }
  }

  Future<void> _loadMoreCustomers() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final customerService = context.read<CustomerService>();
      final customers = await customerService
          .streamCustomers(
            searchQuery: _searchQuery,
            lastDocument: _lastDocument,
          )
          .first;

      if (customers.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        final doc = await _firestore
            .collection('vendors')
            .doc(_vendorId)
            .collection('customers')
            .doc(customers.last.id)
            .get();
        setState(() => _lastDocument = doc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load more customers')),
        );
      }
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _resetPagination() {
    setState(() {
      _lastDocument = null;
      _hasMore = true;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _resetPagination();
    });
  }

  void _onCreateCustomer() {
    NavigationService.navigateToCreateCustomer();
  }

  void _onCustomerTap(Customer customer) {
    NavigationService.navigateToCustomerDetail(customer.id);
  }

  void _onEditCustomer(Customer customer) {
    NavigationService.navigateToEditCustomer(customer.id);
  }

  Future<void> _onDeleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: const Text('Are you sure you want to delete this customer?'),
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

    if (confirmed != true) return;

    try {
      final customerService = context.read<CustomerService>();
      await customerService.deleteCustomer(customer.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete customer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => NavigationService.navigateToCustomerAnalytics(),
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
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: context.read<CustomerService>().streamCustomers(
                    searchQuery: _searchQuery,
                    lastDocument: _lastDocument,
                  ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return error.ErrorView(
                    message: 'Failed to load customers',
                    onRetry: () => setState(() {}),
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingView();
                }

                final customers = snapshot.data!;

                if (customers.isEmpty) {
                  return const Center(
                    child: Text('No customers found'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: customers.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == customers.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final customer = customers[index];
                    return ListTile(
                      title: Text(customer.name),
                      subtitle: Text(customer.email),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _onEditCustomer(customer),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _onDeleteCustomer(customer),
                          ),
                        ],
                      ),
                      onTap: () => _onCustomerTap(customer),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onCreateCustomer,
        child: const Icon(Icons.add),
      ),
    );
  }
}

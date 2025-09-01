import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/supplier_request.dart';
import 'package:vendor_app/services/supplier_service.dart';
import 'package:vendor_app/widgets/loading_indicator.dart';
import 'package:vendor_app/widgets/error_view.dart';

class SupplierRequestsScreen extends StatefulWidget {
  final String inventoryId;

  const SupplierRequestsScreen({
    Key? key,
    required this.inventoryId,
  }) : super(key: key);

  @override
  _SupplierRequestsScreenState createState() => _SupplierRequestsScreenState();
}

class _SupplierRequestsScreenState extends State<SupplierRequestsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  SupplierRequestStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supplierService = Provider.of<SupplierService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search requests...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<SupplierRequest>>(
              stream: supplierService.streamSupplierRequests(
                inventoryId: widget.inventoryId,
                status: _statusFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(
                    message: 'Error loading supplier requests',
                    onRetry: () {
                      setState(() {});
                    },
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingIndicator();
                }

                final requests = snapshot.data!;
                final filteredRequests = requests.where((request) {
                  if (_searchQuery.isEmpty) return true;
                  return request.productName
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredRequests.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No supplier requests found'
                          : 'No matching requests found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final request = filteredRequests[index];
                    return _buildRequestCard(request);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRequestDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRequestCard(SupplierRequest request) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(request.productName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quantity: ${request.quantity}'),
            Text('Status: ${request.status.toString().split('.').last}'),
            if (request.notes != null) Text('Notes: ${request.notes}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleRequestAction(request, value),
          itemBuilder: (context) => [
            if (request.status == SupplierRequestStatus.pending)
              const PopupMenuItem(
                value: 'approve',
                child: Text('Approve'),
              ),
            if (request.status == SupplierRequestStatus.pending)
              const PopupMenuItem(
                value: 'reject',
                child: Text('Reject'),
              ),
            if (request.status == SupplierRequestStatus.approved)
              const PopupMenuItem(
                value: 'complete',
                child: Text('Mark as Completed'),
              ),
            if (request.status != SupplierRequestStatus.completed &&
                request.status != SupplierRequestStatus.cancelled)
              const PopupMenuItem(
                value: 'cancel',
                child: Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Requests'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All'),
              selected: _statusFilter == null,
              onTap: () {
                setState(() {
                  _statusFilter = null;
                });
                Navigator.pop(context);
              },
            ),
            ...SupplierRequestStatus.values.map(
              (status) => ListTile(
                title: Text(status.toString().split('.').last),
                selected: _statusFilter == status,
                onTap: () {
                  setState(() {
                    _statusFilter = status;
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRequestDialog(BuildContext context) {
    final supplierService = Provider.of<SupplierService>(context, listen: false);
    final supplierController = TextEditingController();
    final quantityController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Supplier Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: supplierController,
              decoration: const InputDecoration(
                labelText: 'Supplier ID',
                hintText: 'Enter supplier ID',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter quantity',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Enter any additional notes',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await supplierService.requestInventory(
                  supplierId: supplierController.text,
                  inventoryId: widget.inventoryId,
                  quantity: int.parse(quantityController.text),
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request created successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating request: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _handleRequestAction(SupplierRequest request, String action) async {
    final supplierService = Provider.of<SupplierService>(context, listen: false);

    try {
      switch (action) {
        case 'approve':
          await supplierService.updateRequestStatus(
            requestId: request.id,
            status: 'approved',
          );
          break;
        case 'reject':
          await supplierService.updateRequestStatus(
            requestId: request.id,
            status: 'rejected',
          );
          break;
        case 'complete':
          await supplierService.updateRequestStatus(
            requestId: request.id,
            status: 'completed',
          );
          break;
        case 'cancel':
          await supplierService.updateRequestStatus(
            requestId: request.id,
            status: 'cancelled',
          );
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request ${action}d successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 
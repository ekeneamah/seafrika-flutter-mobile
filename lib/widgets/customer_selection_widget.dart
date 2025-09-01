import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer.dart';
import '../screens/customers/create_customer_screen.dart';
import '../providers/service_providers.dart';

class CustomerSelectionWidget extends ConsumerStatefulWidget {
  final Customer? selectedCustomer;
  final Function(Customer?) onCustomerSelected;
  final bool allowCreate;

  const CustomerSelectionWidget({
    super.key,
    this.selectedCustomer,
    required this.onCustomerSelected,
    this.allowCreate = true,
  });

  @override
  ConsumerState<CustomerSelectionWidget> createState() => _CustomerSelectionWidgetState();
}

class _CustomerSelectionWidgetState extends ConsumerState<CustomerSelectionWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Customer> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedCustomer != null) {
      _searchController.text = widget.selectedCustomer!.name;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      final customerService = ref.read(customerServiceProvider);
      final customers = await customerService.searchCustomers(
        query: query,
        limit: 10,
      );
      
      if (mounted) {
        setState(() {
          _searchResults = customers;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
    }
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _searchController.text = customer.name;
      _showResults = false;
    });
    widget.onCustomerSelected(customer);
    _searchFocusNode.unfocus();
  }

  void _clearSelection() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _showResults = false;
    });
    widget.onCustomerSelected(null);
  }

  void _createNewCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCustomerScreen(
          initialName: _searchController.text,
        ),
      ),
    );

    if (result is Customer) {
      _selectCustomer(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            labelText: 'Search Customer',
            hintText: 'Enter name or phone number',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSelection,
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
          onTap: () {
            if (_searchController.text.isNotEmpty && _searchResults.isNotEmpty) {
              setState(() => _showResults = true);
            }
          },
          validator: (value) {
            if (widget.selectedCustomer == null && (value?.isEmpty ?? true)) {
              return 'Please select a customer';
            }
            return null;
          },
        ),
        if (_showResults) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Column(
              children: [
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Searching...'),
                      ],
                    ),
                  )
                else if (_searchResults.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('No customers found'),
                        if (widget.allowCreate) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _createNewCustomer,
                            icon: const Icon(Icons.add),
                            label: const Text('Create New Customer'),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length + (widget.allowCreate ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (widget.allowCreate && index == _searchResults.length) {
                          return ListTile(
                            leading: const Icon(Icons.add),
                            title: const Text('Create New Customer'),
                            subtitle: Text('Add "${_searchController.text}" as new customer'),
                            onTap: _createNewCustomer,
                          );
                        }

                        final customer = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(customer.name.substring(0, 1).toUpperCase()),
                          ),
                          title: Text(customer.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer.phone),
                              Text(customer.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                          onTap: () => _selectCustomer(customer),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (widget.selectedCustomer != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Text(
                    widget.selectedCustomer!.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedCustomer!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(widget.selectedCustomer!.phone),
                      Text(
                        widget.selectedCustomer!.email,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _clearSelection,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

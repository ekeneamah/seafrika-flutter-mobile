import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/booking_request.dart';
import 'package:vendor_app/services/booking_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/empty_view.dart';
import 'package:vendor_app/services/customer_service.dart';
import 'package:vendor_app/services/service_service.dart';

class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({super.key});

  @override
  State<CustomerRequestsScreen> createState() => _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState extends State<CustomerRequestsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'All';
  bool _isLoading = true;
  String? _error;
  List<BookingRequest> _requests = [];
  Map<String, String> _customerNames = {};
  Map<String, String> _serviceNames = {};
  Map<String, double> _servicePrices = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookingService = context.read<BookingService>();
      final customerService = context.read<CustomerService>();
      final serviceService = context.read<ServiceService>();
      final requests = await bookingService.fetchBookingRequests();

      for (final request in requests) {
        try {
          final customer =
              await customerService.fetchCustomer(request.customerId);
          _customerNames[request.customerId] = customer.name;

          final service = await serviceService.fetchService(request.serviceId);
          _serviceNames[request.serviceId] = service.name;
          _servicePrices[request.serviceId] = service.price;
        } catch (e) {
          _customerNames[request.customerId] = 'Unknown Customer';
          _serviceNames[request.serviceId] = 'Unknown Service';
          _servicePrices[request.serviceId] = 0.0;
        }
      }

      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load booking requests';
        _isLoading = false;
      });
    }
  }

  List<BookingRequest> get _filteredRequests {
    return _requests.where((request) {
      final matchesSearch = request.customerId
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          request.serviceId.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus =
          _selectedStatus == 'All' || request.status == _selectedStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  void _onRequestTap(BookingRequest request) {
    NavigationService.navigateToBookingCreation(bookingId: request.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
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
                  decoration: const InputDecoration(
                    hintText: 'Search requests...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('All'),
                      _buildStatusChip('Pending'),
                      _buildStatusChip('Approved'),
                      _buildStatusChip('Rejected'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const error.LoadingView()
                : _error != null
                    ? error.ErrorView(
                        message: _error!,
                        onRetry: _loadRequests,
                      )
                    : _filteredRequests.isEmpty
                        ? const EmptyView(
                            icon: Icons.event_busy,
                            title: 'No Requests Found',
                            message: 'There are no booking requests to display',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredRequests.length,
                            itemBuilder: (context, index) {
                              final request = _filteredRequests[index];
                              return Card(
                                child: ListTile(
                                  onTap: () => _onRequestTap(request),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        _getStatusColor(request.status),
                                    child: Icon(
                                      _getStatusIcon(request.status),
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                      _customerNames[request.customerId] ??
                                          'Unknown Customer'),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_serviceNames[request.serviceId] ??
                                          'Unknown Service'),
                                      Text(
                                        '\$${_servicePrices[request.serviceId]?.toStringAsFixed(2) ?? '0.00'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      Text(
                                        request.requestedDate
                                            .toString()
                                            .split('.')[0],
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    request.status,
                                    style: TextStyle(
                                      color: _getStatusColor(request.status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isSelected = status == _selectedStatus;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(status),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedStatus = status);
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check;
      case 'rejected':
        return Icons.close;
      default:
        return Icons.event;
    }
  }
}

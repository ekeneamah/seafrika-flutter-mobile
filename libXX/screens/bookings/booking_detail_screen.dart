import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/booking.dart';
import 'package:vendor_app/models/task.dart';
import 'package:vendor_app/services/booking_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;

  const BookingDetailScreen({
    super.key,
    required this.bookingId,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Booking? _booking;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookingService = context.read<BookingService>();
      final booking = await bookingService.fetchBooking(widget.bookingId);
      setState(() {
        _booking = booking;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load booking details';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveBooking() async {
    setState(() => _isLoading = true);

    try {
      final bookingService = context.read<BookingService>();
      await bookingService.updateBookingStatus(
          widget.bookingId, BookingStatus.confirmed);
      await _loadBooking();
    } catch (e) {
      setState(() => _error = 'Failed to approve booking');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final bookingService = context.read<BookingService>();
        await bookingService.cancelBooking(widget.bookingId);
        await _loadBooking();
      } catch (e) {
        setState(() => _error = 'Failed to cancel booking');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createInvoice() async {
    NavigationService.navigateToCreateInvoice(bookingId: widget.bookingId);
  }

  Future<void> _createTask() async {
    NavigationService.navigateToCreateTask(
      itemId: widget.bookingId,
      itemType: TaskType.booking,
      title: 'Task for Booking #${widget.bookingId}',
      description:
          'Customer: ${_booking?.customerName ?? ''}\nDate: ${_booking?.bookingDate.toString() ?? ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        actions: [
          if (_booking != null && _booking!.status == BookingStatus.pending)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                NavigationService.navigateToBookingCreation(
                    bookingId: widget.bookingId);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadBooking,
                )
              : _booking == null
                  ? const Center(child: Text('Booking not found'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer Information',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow('Name', _booking!.customerName),
                                _buildInfoRow('Email', _booking!.customerEmail),
                                _buildInfoRow('Phone', _booking!.customerPhone),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Booking Details',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  'Date',
                                  '${_booking!.bookingDate.day}/${_booking!.bookingDate.month}/${_booking!.bookingDate.year}',
                                ),
                                _buildInfoRow(
                                  'Time',
                                  TimeOfDay.fromDateTime(_booking!.bookingDate)
                                      .format(context),
                                ),
                                _buildInfoRow(
                                  'Price',
                                  '\$${_booking!.totalAmount.toStringAsFixed(2)}',
                                ),
                                _buildInfoRow(
                                    'Status',
                                    _booking!.status
                                        .toString()
                                        .split('.')
                                        .last),
                                if (_booking!.notes?.isNotEmpty ?? false)
                                  _buildInfoRow('Notes', _booking!.notes!),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_booking!.status == BookingStatus.pending) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _cancelBooking,
                                  icon: const Icon(Icons.close),
                                  label: const Text('Cancel'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _approveBooking,
                                  icon: const Icon(Icons.check),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (_booking!.status ==
                            BookingStatus.confirmed) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _createInvoice,
                                  icon: const Icon(Icons.receipt),
                                  label: const Text('Create Invoice'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _createTask,
                                icon: const Icon(Icons.task),
                                label: const Text('Create Task'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

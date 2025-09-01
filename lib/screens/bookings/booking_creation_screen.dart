import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/booking_request.dart';
import 'package:vendor_app/models/booking.dart';
import 'package:vendor_app/models/customer.dart';
import 'package:vendor_app/models/inventory.dart';
import 'package:vendor_app/services/booking_service.dart';
import 'package:vendor_app/services/customer_service.dart';
import 'package:vendor_app/services/inventory_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class BookingCreationScreen extends StatefulWidget {
  final BookingRequest? request;
  final bool isDraft;
  const BookingCreationScreen({
    super.key,
    this.request,
    this.isDraft = false,
  });

  @override
  State<BookingCreationScreen> createState() => _BookingCreationScreenState();
}

class _BookingCreationScreenState extends State<BookingCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  Customer? _selectedCustomer;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Inventory? _selectedInventory;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (widget.request != null) {
      final customerService = context.read<CustomerService>();
      final customer =
          await customerService.fetchCustomer(widget.request!.customerId);
      if (mounted) {
        setState(() {
          _customerNameController.text = customer.name;
          _selectedDate = widget.request!.requestedDate;
        });
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _customerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final bookingService = context.read<BookingService>();
      await bookingService.saveBookingDraft(
        customer: _selectedCustomer,
        customerName: _customerNameController.text,
        customerEmail: _customerEmailController.text,
        customerPhone: _customerPhoneController.text,
        date: _selectedDate,
        time: _selectedTime,
        price: _selectedInventory?.unitPrice ?? 0.0,
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved successfully')),
        );
        NavigationService.goBack();
      }
    } catch (e) {
      setState(() => _error = 'Failed to save draft');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final bookingService = context.read<BookingService>();
      final booking = await bookingService.createBooking(
        customerId: _selectedCustomer?.id ?? '',
        customerName: _customerNameController.text,
        customerEmail: _customerEmailController.text,
        customerPhone: _customerPhoneController.text,
        bookingDate: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
        items: [
          BookingItem(
            inventoryId: _selectedInventory?.productId,
            productName: _selectedInventory?.productName ?? 'Service',
            unitPrice: _selectedInventory?.unitPrice ?? 0.0,
            quantity: 1,
          ),
        ],
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking created successfully')),
        );
        NavigationService.navigateToBookingDetail(booking.id);
      }
    } catch (e) {
      setState(() => _error = 'Failed to create booking');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Booking'),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                  },
                )
              : Form(
                  key: _formKey,
                  child: ListView(
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
                              StreamBuilder<List<Customer>>(
                                stream: context
                                    .read<CustomerService>()
                                    .streamCustomers(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return const Text(
                                        'Error loading customers');
                                  }

                                  if (!snapshot.hasData) {
                                    return const CircularProgressIndicator();
                                  }

                                  final customers = snapshot.data!;
                                  return DropdownButtonFormField<Customer>(
                                    value: _selectedCustomer,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Customer',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: customers.map((customer) {
                                      return DropdownMenuItem(
                                        value: customer,
                                        child: Text(customer.name),
                                      );
                                    }).toList(),
                                    onChanged: (customer) {
                                      setState(
                                          () => _selectedCustomer = customer);
                                      if (customer != null) {
                                        _customerNameController.text =
                                            customer.name;
                                        _customerEmailController.text =
                                            customer.email;
                                        _customerPhoneController.text =
                                            customer.phone;
                                      }
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _customerNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Customer Name',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter customer name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _customerEmailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter email';
                                  }
                                  if (!value!.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _customerPhoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter phone number';
                                  }
                                  return null;
                                },
                              ),
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
                              StreamBuilder<List<Inventory>>(
                                stream: context
                                    .read<InventoryService>()
                                    .streamInventory()
                                    .map((snapshot) => snapshot.docs
                                        .map((doc) =>
                                            Inventory.fromFirestore(doc))
                                        .toList()),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return const Text(
                                        'Error loading inventory');
                                  }

                                  if (!snapshot.hasData) {
                                    return const CircularProgressIndicator();
                                  }

                                  final inventory = snapshot.data!;
                                  return DropdownButtonFormField<Inventory>(
                                    value: _selectedInventory,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Service/Item',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: inventory.map((item) {
                                      return DropdownMenuItem(
                                        value: item,
                                        child: Text(item.productName),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(
                                          () => _selectedInventory = value);
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Please select a service/item';
                                      }
                                      return null;
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              ListTile(
                                title: const Text('Date'),
                                subtitle: Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                ),
                                trailing: const Icon(Icons.calendar_today),
                                onTap: _selectDate,
                              ),
                              ListTile(
                                title: const Text('Time'),
                                subtitle: Text(_selectedTime.format(context)),
                                trailing: const Icon(Icons.access_time),
                                onTap: _selectTime,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _notesController,
                                decoration: const InputDecoration(
                                  labelText: 'Notes',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saveDraft,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Text('Save Draft'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _sendBooking,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                              ),
                              child: const Text('Send Booking'),
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

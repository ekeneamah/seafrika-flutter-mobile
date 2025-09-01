import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/invoice.dart';
import 'package:vendor_app/services/invoice_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/common/loading_indicator.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({Key? key}) : super(key: key);

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  bool _isLoading = false;
  List<Invoice> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await context.read<InvoiceService>().getInvoices();
      setState(() => _invoices = invoices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load invoices')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => NavigationService.navigateToCreateInvoice(),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _invoices.isEmpty
              ? const Center(child: Text('No invoices found'))
              : ListView.builder(
                  itemCount: _invoices.length,
                  itemBuilder: (context, index) {
                    final invoice = _invoices[index];
                    return ListTile(
                      title: Text(invoice.customerName),
                      subtitle: Text('Status: ${invoice.status}'),
                      trailing: Text('\$${invoice.total.toStringAsFixed(2)}'),
                      onTap: () =>
                          NavigationService.navigateToInvoiceDetail(invoice.id),
                    );
                  },
                ),
    );
  }
}

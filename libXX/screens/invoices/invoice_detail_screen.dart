import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/invoice.dart';
import 'package:vendor_app/services/invoice_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/common/loading_indicator.dart';
import 'package:share_plus/share_plus.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({
    Key? key,
    required this.invoiceId,
  }) : super(key: key);

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  bool _isLoading = false;
  Invoice? _invoice;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() => _isLoading = true);
    try {
      final invoice =
          await context.read<InvoiceService>().getInvoice(widget.invoiceId);
      setState(() => _invoice = invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load invoice')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      await context
          .read<InvoiceService>()
          .updateInvoiceStatus(widget.invoiceId, status);
      await _loadInvoice();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareInvoice() async {
    try {
      final shareLink = await context
          .read<InvoiceService>()
          .generateShareLink(widget.invoiceId);
      await Share.share(
        'Invoice Details\n\nView invoice: $shareLink',
        subject: 'Invoice #${widget.invoiceId}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate share link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                NavigationService.navigateToEditInvoice(widget.invoiceId),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _invoice == null
              ? const Center(child: Text('Invoice not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer: ${_invoice!.customerName}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text('Email: ${_invoice!.customerEmail}'),
                              const SizedBox(height: 8),
                              Text('Status: ${_invoice!.status}'),
                              const SizedBox(height: 8),
                              Text('Created: ${_invoice!.createdAt}'),
                              if (_invoice!.updatedAt != null) ...[
                                const SizedBox(height: 8),
                                Text('Updated: ${_invoice!.updatedAt}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Items', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 8),
                      ..._invoice!.items.map((item) => Card(
                            child: ListTile(
                              title: Text(item.name),
                              subtitle: Text(item.description ?? ''),
                              trailing: Text(
                                '\$${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                              ),
                            ),
                          )),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total',
                                  style: TextStyle(fontSize: 18)),
                              Text(
                                '\$${_invoice!.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_invoice!.notes?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 16),
                        const Text('Notes', style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_invoice!.notes!),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: _invoice!.status,
                        decoration: const InputDecoration(
                          labelText: 'Update Status',
                        ),
                        items: ['draft', 'sent', 'paid', 'overdue']
                            .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _updateStatus(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}

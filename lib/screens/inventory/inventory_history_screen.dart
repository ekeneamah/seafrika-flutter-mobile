import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/services/inventory_service.dart';
import 'package:vendor_app/widgets/loading_view.dart';

class InventoryHistoryScreen extends StatefulWidget {
  final String inventoryId;

  const InventoryHistoryScreen({
    super.key,
    required this.inventoryId,
  });

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await context
          .read<InventoryService>()
          .getInventoryHistory(widget.inventoryId);
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load history')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory History'),
      ),
      body: _isLoading
          ? const LoadingView()
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final entry = _history[index];
                return ListTile(
                  leading: Icon(
                    entry['type'] == 'add'
                        ? Icons.add_circle
                        : Icons.remove_circle,
                    color: entry['type'] == 'add' ? Colors.green : Colors.red,
                  ),
                  title: Text(entry['description']),
                  subtitle: Text(entry['date'].toString().split(' ')[0]),
                  trailing: Text(
                    '${entry['type'] == 'add' ? '+' : '-'}${entry['quantity']}',
                    style: TextStyle(
                      color: entry['type'] == 'add' ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

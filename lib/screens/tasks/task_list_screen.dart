import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/task.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/task_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class TaskListScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const TaskListScreen({Key? key, this.arguments}) : super(key: key);

  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _searchController = TextEditingController();
  TaskType? _selectedType;
  TaskStatus? _selectedStatus;
  String? _selectedAssignee;
  bool _isLoading = false;
  String? _error;
  List<Task> _tasks = [];
  String? _relatedItemId;
  TaskType? _relatedItemType;

  @override
  void initState() {
    super.initState();
    _relatedItemId = widget.arguments?['itemId'] as String?;
    _relatedItemType = widget.arguments?['itemType'] as TaskType?;
    if (_relatedItemType != null) {
      _selectedType = _relatedItemType;
    }
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final taskService = context.read<TaskService>();
      final tasks = await taskService.getTasks(
        type: _selectedType,
        status: _selectedStatus,
        assignedTo: _selectedAssignee,
        searchQuery: _searchController.text,
        relatedItemId: _relatedItemId,
      );

      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Tasks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<TaskType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Task Type'),
              items: TaskType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedType = value);
                Navigator.pop(context);
                _loadTasks();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TaskStatus>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: TaskStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                Navigator.pop(context);
                _loadTasks();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedType = null;
                _selectedStatus = null;
                _selectedAssignee = null;
              });
              Navigator.pop(context);
              _loadTasks();
            },
            child: const Text('Clear Filters'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getScreenTitle() {
    if (_relatedItemType != null) {
      switch (_relatedItemType) {
        case TaskType.product:
          return 'Product Tasks';
        case TaskType.booking:
          return 'Booking Tasks';
        case TaskType.service:
          return 'Service Tasks';
        case TaskType.review:
          return 'Review Tasks';
        case TaskType.complaint:
          return 'Complaint Tasks';
        case TaskType.general:
          return 'General Tasks';
        default:
          return 'Tasks';
      }
    }
    return 'Tasks';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingView();
    }

    if (_error != null) {
      return error.ErrorView(
        message: _error!,
        onRetry: _loadTasks,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle()),
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
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadTasks();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _loadTasks(),
            ),
          ),
          Expanded(
            child: _tasks.isEmpty
                ? const Center(
                    child: Text('No tasks found'),
                  )
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(task.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Type: ${task.type.toString().split('.').last}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Status: ${task.status.toString().split('.').last}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Due: ${task.dueDate.toString().split(' ')[0]}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: () {
                              NavigationService.navigateToTaskDetail(task.id);
                            },
                          ),
                          onTap: () {
                            NavigationService.navigateToTaskDetail(task.id);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          NavigationService.navigateToCreateTask();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

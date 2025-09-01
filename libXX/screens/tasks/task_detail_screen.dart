import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/task.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/task_service.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({Key? key, required this.taskId}) : super(key: key);

  @override
  TaskDetailScreenState createState() => TaskDetailScreenState();
}

class TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _isLoading = false;
  String? _error;
  Task? _task;
  List<TaskComment> _comments = [];
  List<TaskActivity> _activities = [];
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTaskData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTaskData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final taskService = context.read<TaskService>();
      _task = await taskService.getTask(widget.taskId);
      _comments = await taskService.getComments(widget.taskId);
      _activities = await taskService.getActivities(widget.taskId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTaskStatus(TaskStatus newStatus) async {
    if (_task == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final taskService = context.read<TaskService>();
      final authService = context.read<AuthService>();
      final userName = authService.currentUser?.fullName ?? '';
      final assignedToName = _task?.assignedTo ?? '';
      final updatedTask = _task!.copyWith(
        status: newStatus,
        completedAt: newStatus == TaskStatus.completed ? DateTime.now() : null,
      );
      await taskService.updateTask(
        updatedTask,
        userName: userName,
        assignedToName: assignedToName,
      );
      await _loadTaskData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final taskService = context.read<TaskService>();
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      final comment = TaskComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: currentUser?.id ?? '',
        userName: currentUser?.fullName ?? 'Unknown User',
        content: _commentController.text,
        createdAt: DateTime.now(),
      );
      await taskService.addComment(widget.taskId, comment);
      _commentController.clear();
      await _loadTaskData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingView();
    }

    if (_error != null) {
      return error.ErrorView(
        message: _error!,
        onRetry: _loadTaskData,
      );
    }

    if (_task == null) {
      return const Scaffold(
        body: Center(
          child: Text('Task not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              NavigationService.navigateToCreateTask(task: _task);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                      _task!.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _task!.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildInfoChip(
                          'Type',
                          _task!.type.toString().split('.').last,
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          'Priority',
                          _task!.priority.toString().split('.').last,
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          'Status',
                          _task!.status.toString().split('.').last,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Due Date: ${_task!.dueDate.toString().split(' ')[0]}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Assigned To: ${_task!.assignedTo}',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                      'Status Actions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              _updateTaskStatus(TaskStatus.inProgress),
                          child: const Text('Start'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              _updateTaskStatus(TaskStatus.completed),
                          child: const Text('Complete'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              _updateTaskStatus(TaskStatus.cancelled),
                          child: const Text('Cancel'),
                        ),
                      ],
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
                      'Comments',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _addComment,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return ListTile(
                          title: Text(comment.userName),
                          subtitle: Text(comment.content),
                          trailing: Text(
                            comment.createdAt.toString().split(' ')[0],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
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
                      'Activity Timeline',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _activities.length,
                      itemBuilder: (context, index) {
                        final activity = _activities[index];
                        return ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(activity.action),
                          subtitle: Text(activity.details ?? ''),
                          trailing: Text(
                            activity.createdAt.toString().split(' ')[0],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/task.dart';
import 'package:vendor_app/services/task_service.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/services/user_service.dart';
import 'package:vendor_app/models/user.dart';
import 'package:collection/collection.dart';

class CreateTaskScreen extends StatefulWidget {
  final Task? task;
  final Map<String, dynamic>? arguments;

  const CreateTaskScreen({
    Key? key,
    this.task,
    this.arguments,
  }) : super(key: key);

  @override
  CreateTaskScreenState createState() => CreateTaskScreenState();
}

class CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TaskType _selectedType = TaskType.general;
  TaskPriority _selectedPriority = TaskPriority.medium;
  TaskStatus _selectedStatus = TaskStatus.pending;
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedAssignee;
  bool _isLoading = false;
  String? _error;
  List<User> _users = [];
  String? _relatedItemId;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _selectedType = widget.task!.type;
      _selectedPriority = widget.task!.priority;
      _selectedStatus = widget.task!.status;
      _selectedDueDate = widget.task!.dueDate;
      _selectedAssignee = widget.task!.assignedTo;
      _relatedItemId = widget.task!.relatedItemId;
    } else if (widget.arguments != null) {
      _titleController.text = widget.arguments!['title'] as String? ?? '';
      _descriptionController.text =
          widget.arguments!['description'] as String? ?? '';
      _selectedType =
          widget.arguments!['itemType'] as TaskType? ?? TaskType.general;
      _relatedItemId = widget.arguments!['itemId'] as String?;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final taskService = context.read<TaskService>();
      final authService = context.read<AuthService>();
      final task = Task(
        id: widget.task?.id ?? '',
        title: _titleController.text,
        description: _descriptionController.text,
        type: _selectedType,
        priority: _selectedPriority,
        status: _selectedStatus,
        dueDate: _selectedDueDate,
        assignedTo: _selectedAssignee ?? '',
        assignedBy: authService.currentUser?.id ?? '',
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        completedAt: widget.task?.completedAt,
        relatedItemId: _relatedItemId,
        comments: widget.task?.comments ?? [],
        activities: widget.task?.activities ?? [],
      );

      final assignedToUser =
          _users.firstWhereOrNull((u) => u.id == _selectedAssignee);
      final assignedToName = assignedToUser?.fullName ?? '';
      final userName = authService.currentUser?.fullName ?? '';

      if (widget.task == null) {
        await taskService.createTask(
          task,
          userName: userName,
          assignedToName: assignedToName,
        );
      } else {
        await taskService.updateTask(
          task,
          userName: userName,
          assignedToName: assignedToName,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Create Task' : 'Edit Task'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TaskType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Task Type',
                        border: OutlineInputBorder(),
                      ),
                      items: TaskType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.toString().split('.').last),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TaskPriority>(
                      value: _selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: TaskPriority.values.map((priority) {
                        return DropdownMenuItem(
                          value: priority,
                          child: Text(priority.toString().split('.').last),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPriority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TaskStatus>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: TaskStatus.values.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.toString().split('.').last),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _selectedDueDate.toString().split(' ')[0],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<User>>(
                      stream: context
                          .read<UserService>()
                          .streamUsers(isActive: true),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text('Error loading team members');
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final users = snapshot.data!;
                        _users = users;
                        return DropdownButtonFormField<String>(
                          value: _selectedAssignee,
                          decoration: const InputDecoration(
                            labelText: 'Assign To',
                            border: OutlineInputBorder(),
                          ),
                          items: users.map((user) {
                            return DropdownMenuItem(
                              value: user.id,
                              child: Text(user.fullName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedAssignee = value);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveTask,
                      child: Text(
                        widget.task == null ? 'Create Task' : 'Update Task',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

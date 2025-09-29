import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskPriority { low, medium, high, urgent }

enum TaskType { product, service, review, complaint, booking, general }

enum TaskStatus { pending, inProgress, completed, cancelled }

class Task {
  final String id;
  final String title;
  final String description;
  final String assignedTo;
  final String assignedBy;
  final TaskType type;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? relatedItemId;
  final List<TaskComment> comments;
  final List<TaskActivity> activities;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedBy,
    required this.type,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.createdAt,
    this.completedAt,
    this.relatedItemId,
    required this.comments,
    required this.activities,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      assignedTo: map['assignedTo'] as String,
      assignedBy: map['assignedBy'] as String,
      type: TaskType.values.firstWhere(
        (e) => e.toString() == 'TaskType.${map['type']}',
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.toString() == 'TaskPriority.${map['priority']}',
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.toString() == 'TaskStatus.${map['status']}',
      ),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      relatedItemId: map['relatedItemId'] as String?,
      comments: (map['comments'] as List<dynamic>?)
              ?.map((e) => TaskComment.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      activities: (map['activities'] as List<dynamic>?)
              ?.map((e) => TaskActivity.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
      'type': type.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'status': status.toString().split('.').last,
      'dueDate': dueDate,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'relatedItemId': relatedItemId,
      'comments': comments.map((e) => e.toMap()).toList(),
      'activities': activities.map((e) => e.toMap()).toList(),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTo,
    String? assignedBy,
    TaskType? type,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? completedAt,
    String? relatedItemId,
    List<TaskComment>? comments,
    List<TaskActivity>? activities,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy ?? this.assignedBy,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      relatedItemId: relatedItemId ?? this.relatedItemId,
      comments: comments ?? this.comments,
      activities: activities ?? this.activities,
    );
  }
}

class TaskComment {
  final String id;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  TaskComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  factory TaskComment.fromMap(Map<String, dynamic> map) {
    return TaskComment(
      id: map['id'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      content: map['content'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'content': content,
      'createdAt': createdAt,
    };
  }
}

class TaskActivity {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String? details;
  final DateTime createdAt;

  TaskActivity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    this.details,
    required this.createdAt,
  });

  factory TaskActivity.fromMap(Map<String, dynamic> map) {
    return TaskActivity(
      id: map['id'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      action: map['action'] as String,
      details: map['details'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'action': action,
      'details': details,
      'createdAt': createdAt,
    };
  }
}

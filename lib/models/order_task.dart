import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderTaskType {
  preparation,
  packing,
  quality_check,
  shipping,
  delivery,
  customer_service,
  refund_processing,
  return_handling
}

enum OrderTaskStatus {
  pending,
  assigned,
  in_progress,
  completed,
  cancelled,
  overdue
}

enum OrderTaskPriority { low, medium, high, urgent }

class OrderTask {
  final String id;
  final String orderId;
  final String vendorId;
  final OrderTaskType type;
  final String title;
  final String description;
  final OrderTaskStatus status;
  final OrderTaskPriority priority;
  final String? assignedTo;
  final String? assignedToName;
  final String? assignedBy;
  final DateTime? dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int estimatedDuration; // in minutes
  final int? actualDuration; // in minutes
  final List<String> attachments;
  final List<OrderTaskComment> comments;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OrderTask({
    required this.id,
    required this.orderId,
    required this.vendorId,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.assignedToName,
    this.assignedBy,
    this.dueDate,
    this.startedAt,
    this.completedAt,
    required this.estimatedDuration,
    this.actualDuration,
    required this.attachments,
    required this.comments,
    this.metadata,
    required this.createdAt,
    this.updatedAt,
  });

  factory OrderTask.fromMap(Map<String, dynamic> map) {
    return OrderTask(
      id: map['id'] as String,
      orderId: map['orderId'] as String,
      vendorId: map['vendorId'] as String,
      type: OrderTaskType.values.firstWhere(
        (e) => e.toString() == 'OrderTaskType.${map['type']}',
      ),
      title: map['title'] as String,
      description: map['description'] as String,
      status: OrderTaskStatus.values.firstWhere(
        (e) => e.toString() == 'OrderTaskStatus.${map['status']}',
      ),
      priority: OrderTaskPriority.values.firstWhere(
        (e) => e.toString() == 'OrderTaskPriority.${map['priority']}',
      ),
      assignedTo: map['assignedTo'] as String?,
      assignedToName: map['assignedToName'] as String?,
      assignedBy: map['assignedBy'] as String?,
      dueDate: map['dueDate'] != null
          ? (map['dueDate'] as Timestamp).toDate()
          : null,
      startedAt: map['startedAt'] != null
          ? (map['startedAt'] as Timestamp).toDate()
          : null,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      estimatedDuration: map['estimatedDuration'] as int,
      actualDuration: map['actualDuration'] as int?,
      attachments: List<String>.from(map['attachments'] ?? []),
      comments: (map['comments'] as List? ?? [])
          .map((comment) =>
              OrderTaskComment.fromMap(comment as Map<String, dynamic>))
          .toList(),
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'vendorId': vendorId,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedBy': assignedBy,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'estimatedDuration': estimatedDuration,
      'actualDuration': actualDuration,
      'attachments': attachments,
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  OrderTask copyWith({
    String? id,
    String? orderId,
    String? vendorId,
    OrderTaskType? type,
    String? title,
    String? description,
    OrderTaskStatus? status,
    OrderTaskPriority? priority,
    String? assignedTo,
    String? assignedToName,
    String? assignedBy,
    DateTime? dueDate,
    DateTime? startedAt,
    DateTime? completedAt,
    int? estimatedDuration,
    int? actualDuration,
    List<String>? attachments,
    List<OrderTaskComment>? comments,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderTask(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      vendorId: vendorId ?? this.vendorId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedBy: assignedBy ?? this.assignedBy,
      dueDate: dueDate ?? this.dueDate,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      actualDuration: actualDuration ?? this.actualDuration,
      attachments: attachments ?? this.attachments,
      comments: comments ?? this.comments,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isOverdue {
    if (dueDate == null || status == OrderTaskStatus.completed) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  Duration? get timeRemaining {
    if (dueDate == null || status == OrderTaskStatus.completed) return null;
    return dueDate!.difference(DateTime.now());
  }
}

class OrderTaskComment {
  final String id;
  final String userId;
  final String userName;
  final String message;
  final DateTime createdAt;
  final List<String> attachments;

  OrderTaskComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.message,
    required this.createdAt,
    required this.attachments,
  });

  factory OrderTaskComment.fromMap(Map<String, dynamic> map) {
    return OrderTaskComment(
      id: map['id'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      message: map['message'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      attachments: List<String>.from(map['attachments'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'attachments': attachments,
    };
  }
}

class OrderWorkflow {
  final String id;
  final String orderId;
  final String vendorId;
  final List<WorkflowStep> steps;
  final int currentStepIndex;
  final WorkflowStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  OrderWorkflow({
    required this.id,
    required this.orderId,
    required this.vendorId,
    required this.steps,
    required this.currentStepIndex,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  factory OrderWorkflow.fromMap(Map<String, dynamic> map) {
    return OrderWorkflow(
      id: map['id'] as String,
      orderId: map['orderId'] as String,
      vendorId: map['vendorId'] as String,
      steps: (map['steps'] as List)
          .map((step) => WorkflowStep.fromMap(step as Map<String, dynamic>))
          .toList(),
      currentStepIndex: map['currentStepIndex'] as int,
      status: WorkflowStatus.values.firstWhere(
        (e) => e.toString() == 'WorkflowStatus.${map['status']}',
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'vendorId': vendorId,
      'steps': steps.map((step) => step.toMap()).toList(),
      'currentStepIndex': currentStepIndex,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  WorkflowStep? get currentStep {
    if (currentStepIndex >= 0 && currentStepIndex < steps.length) {
      return steps[currentStepIndex];
    }
    return null;
  }

  WorkflowStep? get nextStep {
    if (currentStepIndex + 1 < steps.length) {
      return steps[currentStepIndex + 1];
    }
    return null;
  }

  double get completionPercentage {
    if (steps.isEmpty) return 0;
    return (currentStepIndex + 1) / steps.length;
  }
}

class WorkflowStep {
  final String id;
  final String name;
  final String description;
  final OrderTaskType taskType;
  final bool isRequired;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? assignedTo;
  final Map<String, dynamic>? metadata;

  WorkflowStep({
    required this.id,
    required this.name,
    required this.description,
    required this.taskType,
    required this.isRequired,
    required this.isCompleted,
    this.completedAt,
    this.assignedTo,
    this.metadata,
  });

  factory WorkflowStep.fromMap(Map<String, dynamic> map) {
    return WorkflowStep(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      taskType: OrderTaskType.values.firstWhere(
        (e) => e.toString() == 'OrderTaskType.${map['taskType']}',
      ),
      isRequired: map['isRequired'] as bool,
      isCompleted: map['isCompleted'] as bool,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      assignedTo: map['assignedTo'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'taskType': taskType.toString().split('.').last,
      'isRequired': isRequired,
      'isCompleted': isCompleted,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'assignedTo': assignedTo,
      'metadata': metadata,
    };
  }
}

enum WorkflowStatus { active, completed, cancelled, paused }

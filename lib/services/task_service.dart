import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/task.dart';

class TaskService {
  final FirebaseFirestore _firestore;
  final String _vendorId;

  TaskService({
    required FirebaseFirestore firestore,
    required String vendorId,
  })  : _firestore = firestore,
        _vendorId = vendorId;

  Future<List<Task>> getTasks({
    TaskType? type,
    TaskStatus? status,
    String? assignedTo,
    String? searchQuery,
    String? relatedItemId,
  }) async {
    try {
      Query query =
          _firestore.collection('vendors').doc(_vendorId).collection('tasks');

      if (type != null) {
        query = query.where('type', isEqualTo: type.toString().split('.').last);
      }

      if (status != null) {
        query =
            query.where('status', isEqualTo: status.toString().split('.').last);
      }

      if (assignedTo != null) {
        query = query.where('assignedTo', isEqualTo: assignedTo);
      }

      if (relatedItemId != null) {
        query = query.where('relatedItemId', isEqualTo: relatedItemId);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .where('title', isGreaterThanOrEqualTo: searchQuery)
            .where('title', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      }

      final snapshot = await query.orderBy('dueDate').get();

      return snapshot.docs
          .map((doc) => Task.fromMap(
              {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tasks: $e');
    }
  }

  Future<Task> getTask(String taskId) async {
    try {
      final doc = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tasks')
          .doc(taskId)
          .get();

      if (!doc.exists) {
        throw Exception('Task not found');
      }

      return Task.fromMap({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw Exception('Failed to fetch task: $e');
    }
  }

  Future<Task> createTask(Task task,
      {required String userName, required String assignedToName}) async {
    try {
      final docRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tasks')
          .doc();

      final taskData = task.toMap();
      taskData['id'] = docRef.id;
      taskData['createdAt'] = FieldValue.serverTimestamp();

      await docRef.set(taskData);

      // Add initial activity
      await docRef.collection('activities').add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': task.assignedBy,
        'userName': userName,
        'assignedToId': task.assignedTo,
        'assignedToName': assignedToName,
        'action': 'Task created',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return task.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<void> updateTask(Task task,
      {required String userName, required String assignedToName}) async {
    try {
      final taskData = task.toMap();
      taskData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tasks')
          .doc(task.id)
          .update(taskData);

      // Add activity
      await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tasks')
          .doc(task.id)
          .collection('activities')
          .add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': task.assignedBy,
        'userName': userName,
        'assignedToId': task.assignedTo,
        'assignedToName': assignedToName,
        'action': 'Task updated',
        'details': 'Status changed to ${task.status}',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }

  Future<void> addComment(String taskId, TaskComment comment) async {
    try {
      await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tasks')
          .doc(taskId)
          .collection('comments')
          .add(comment.toMap());

      // Add activity
      await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tasks')
          .doc(taskId)
          .collection('activities')
          .add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': comment.userId,
        'userName': comment.userName,
        'action': 'Comment added',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  Future<List<TaskComment>> getComments(String taskId) async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tasks')
          .doc(taskId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TaskComment.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  Future<List<TaskActivity>> getActivities(String taskId) async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('tasks')
          .doc(taskId)
          .collection('activities')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TaskActivity.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch activities: $e');
    }
  }

  Stream<List<Task>> streamTasks({
    TaskType? type,
    TaskStatus? status,
    String? assignedTo,
  }) {
    Query query =
        _firestore.collection('vendors').doc(_vendorId).collection('tasks');

    if (type != null) {
      query = query.where('type', isEqualTo: type.toString().split('.').last);
    }

    if (status != null) {
      query =
          query.where('status', isEqualTo: status.toString().split('.').last);
    }

    if (assignedTo != null) {
      query = query.where('assignedTo', isEqualTo: assignedTo);
    }

    return query.orderBy('dueDate').snapshots().map((snapshot) => snapshot.docs
        .map((doc) =>
            Task.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
        .toList());
  }

  Stream<Task?> streamTask(String taskId) {
    return _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('tasks')
        .doc(taskId)
        .snapshots()
        .map((doc) =>
            doc.exists ? Task.fromMap({...doc.data()!, 'id': doc.id}) : null);
  }
}

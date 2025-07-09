import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/team.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart';

class TeamService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  TeamService({
    required FirebaseFirestore firestore,
    required String vendorId,
    required NotificationService notificationService,
  })  : _firestore = firestore,
        _vendorId = vendorId,
        _notificationService = notificationService;

  Future<Team> createTeam({
    required String name,
    String? description,
    required List<String> memberIds,
    required List<String> managerIds,
  }) async {
    final team = Team(
      id: '',
      vendorId: _vendorId,
      name: name,
      description: description,
      memberIds: memberIds,
      managerIds: managerIds,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore.collection('teams').add(team.toMap());
    final createdTeam = team.copyWith(id: docRef.id);

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Team Created',
      message: 'Team $name has been created',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: createdTeam.toMap(),
    );

    return createdTeam;
  }

  Stream<List<Team>> streamTeams({
    bool? isActive,
  }) {
    Query query =
        _firestore.collection('teams').where('vendorId', isEqualTo: _vendorId);

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Team.fromMap(data);
      }).toList();
    });
  }

  Future<Team> fetchTeam(String teamId) async {
    final doc = await _firestore.collection('teams').doc(teamId).get();
    if (!doc.exists) {
      throw Exception('Team not found');
    }
    final data = doc.data()!;
    data['id'] = doc.id;
    return Team.fromMap(data);
  }

  Future<void> updateTeam({
    required String teamId,
    String? name,
    String? description,
    List<String>? memberIds,
    List<String>? managerIds,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (memberIds != null) updates['memberIds'] = memberIds;
    if (managerIds != null) updates['managerIds'] = managerIds;
    if (isActive != null) updates['isActive'] = isActive;
    updates['lastUpdatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('teams').doc(teamId).update(updates);

    // Send notification
    final team = await fetchTeam(teamId);
    await _notificationService.sendNotification(
      title: 'Team Updated',
      message: 'Team ${team.name} has been updated',
      type: NotificationType.system,
      priority: NotificationPriority.low,
      data: team.toMap(),
    );
  }

  Future<void> deleteTeam(String teamId) async {
    final team = await fetchTeam(teamId);
    await _firestore.collection('teams').doc(teamId).delete();

    // Send notification
    await _notificationService.sendNotification(
      title: 'Team Deleted',
      message: 'Team ${team.name} has been deleted',
      type: NotificationType.system,
      priority: NotificationPriority.high,
      data: team.toMap(),
    );
  }

  Future<void> addTeamMember({
    required String teamId,
    required String userId,
  }) async {
    final team = await fetchTeam(teamId);
    if (!team.memberIds.contains(userId)) {
      final updatedMemberIds = [...team.memberIds, userId];
      await updateTeam(
        teamId: teamId,
        memberIds: updatedMemberIds,
      );
    }
  }

  Future<void> removeTeamMember({
    required String teamId,
    required String userId,
  }) async {
    final team = await fetchTeam(teamId);
    if (team.memberIds.contains(userId)) {
      final updatedMemberIds =
          team.memberIds.where((id) => id != userId).toList();
      await updateTeam(
        teamId: teamId,
        memberIds: updatedMemberIds,
      );
    }
  }

  Future<void> addTeamManager({
    required String teamId,
    required String userId,
  }) async {
    final team = await fetchTeam(teamId);
    if (!team.managerIds.contains(userId)) {
      final updatedManagerIds = [...team.managerIds, userId];
      await updateTeam(
        teamId: teamId,
        managerIds: updatedManagerIds,
      );
    }
  }

  Future<void> removeTeamManager({
    required String teamId,
    required String userId,
  }) async {
    final team = await fetchTeam(teamId);
    if (team.managerIds.contains(userId)) {
      final updatedManagerIds =
          team.managerIds.where((id) => id != userId).toList();
      await updateTeam(
        teamId: teamId,
        managerIds: updatedManagerIds,
      );
    }
  }

  Future<void> deactivateTeam(String teamId) async {
    await updateTeam(
      teamId: teamId,
      isActive: false,
    );
  }

  Future<void> activateTeam(String teamId) async {
    await updateTeam(
      teamId: teamId,
      isActive: true,
    );
  }
}

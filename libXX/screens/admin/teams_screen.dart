import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/team.dart';
import 'package:vendor_app/services/team_service.dart';
import 'package:vendor_app/services/user_service.dart';
import 'package:vendor_app/widgets/loading_indicator.dart';
import 'package:vendor_app/widgets/error_view.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({Key? key}) : super(key: key);

  @override
  _TeamsScreenState createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool? _activeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamService = Provider.of<TeamService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
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
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search teams...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Team>>(
              stream: teamService.streamTeams(
                isActive: _activeFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(
                    message: 'Error loading teams',
                    onRetry: () {
                      setState(() {});
                    },
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingIndicator();
                }

                final teams = snapshot.data!;
                final filteredTeams = teams.where((team) {
                  if (_searchQuery.isEmpty) return true;
                  return team.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredTeams.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No teams found'
                          : 'No matching teams found',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredTeams.length,
                  itemBuilder: (context, index) {
                    final team = filteredTeams[index];
                    return _buildTeamCard(team);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTeamDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTeamCard(Team team) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(team.name[0].toUpperCase()),
        ),
        title: Text(team.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (team.description != null) Text(team.description!),
            Text('Members: ${team.memberIds.length}'),
            Text('Managers: ${team.managerIds.length}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleTeamAction(team, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'members',
              child: Text('Manage Members'),
            ),
            const PopupMenuItem(
              value: 'managers',
              child: Text('Manage Managers'),
            ),
            PopupMenuItem(
              value: team.isActive ? 'deactivate' : 'activate',
              child: Text(team.isActive ? 'Deactivate' : 'Activate'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Teams'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Status'),
              selected: _activeFilter == null,
              onTap: () {
                setState(() {
                  _activeFilter = null;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Active'),
              selected: _activeFilter == true,
              onTap: () {
                setState(() {
                  _activeFilter = true;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Inactive'),
              selected: _activeFilter == false,
              onTap: () {
                setState(() {
                  _activeFilter = false;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTeamDialog(BuildContext context) {
    final teamService = Provider.of<TeamService>(context, listen: false);
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                hintText: 'Enter team name',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter team description',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              try {
                await teamService.createTeam(
                  name: nameController.text,
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  memberIds: [],
                  managerIds: [],
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Team created successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating team: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _handleTeamAction(Team team, String action) async {
    final teamService = Provider.of<TeamService>(context, listen: false);

    try {
      switch (action) {
        case 'edit':
          await _showEditTeamDialog(team);
          break;
        case 'members':
          await _showManageMembersDialog(team);
          break;
        case 'managers':
          await _showManageManagersDialog(team);
          break;
        case 'activate':
          await teamService.activateTeam(team.id);
          break;
        case 'deactivate':
          await teamService.deactivateTeam(team.id);
          break;
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Team'),
              content: Text('Are you sure you want to delete ${team.name}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await teamService.deleteTeam(team.id);
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team ${action}d successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${action}ing team: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditTeamDialog(Team team) async {
    final teamService = Provider.of<TeamService>(context, listen: false);
    final nameController = TextEditingController(text: team.name);
    final descriptionController = TextEditingController(text: team.description);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Team Name',
                hintText: 'Enter team name',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter team description',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      await teamService.updateTeam(
        teamId: team.id,
        name: nameController.text,
        description: descriptionController.text.isEmpty
            ? null
            : descriptionController.text,
      );
    }
  }

  Future<void> _showManageMembersDialog(Team team) async {
    final teamService = Provider.of<TeamService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final selectedMemberIds = Set<String>.from(team.memberIds);

    final users = await userService.streamUsers().first;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Members'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...users.map(
                  (user) => CheckboxListTile(
                    title: Text(user.fullName),
                    subtitle: Text(user.email),
                    value: selectedMemberIds.contains(user.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedMemberIds.add(user.id);
                        } else {
                          selectedMemberIds.remove(user.id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      // Remove members that are no longer selected
      for (final memberId in team.memberIds) {
        if (!selectedMemberIds.contains(memberId)) {
          await teamService.removeTeamMember(
            teamId: team.id,
            userId: memberId,
          );
        }
      }

      // Add new members
      for (final memberId in selectedMemberIds) {
        if (!team.memberIds.contains(memberId)) {
          await teamService.addTeamMember(
            teamId: team.id,
            userId: memberId,
          );
        }
      }
    }
  }

  Future<void> _showManageManagersDialog(Team team) async {
    final teamService = Provider.of<TeamService>(context, listen: false);
    final userService = Provider.of<UserService>(context, listen: false);
    final selectedManagerIds = Set<String>.from(team.managerIds);

    final users = await userService.streamUsers().first;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Managers'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...users.map(
                  (user) => CheckboxListTile(
                    title: Text(user.fullName),
                    subtitle: Text(user.email),
                    value: selectedManagerIds.contains(user.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedManagerIds.add(user.id);
                        } else {
                          selectedManagerIds.remove(user.id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      // Remove managers that are no longer selected
      for (final managerId in team.managerIds) {
        if (!selectedManagerIds.contains(managerId)) {
          await teamService.removeTeamManager(
            teamId: team.id,
            userId: managerId,
          );
        }
      }

      // Add new managers
      for (final managerId in selectedManagerIds) {
        if (!team.managerIds.contains(managerId)) {
          await teamService.addTeamManager(
            teamId: team.id,
            userId: managerId,
          );
        }
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message.dart';
import '../models/integration.dart';
import '../providers/messages_provider.dart';
import '../providers/business_context_provider.dart';
import '../providers/integration_stats_provider.dart';
import '../config/theme.dart';
import '../widgets/messages/conversation_master_list.dart';
import '../widgets/messages/conversation_detail_view.dart';

// Provider to track unread counts per integration
final integrationUnreadCountsProvider =
    FutureProvider.family<int, String?>((ref, integrationId) async {
  final businessId = ref.watch(selectedBusinessIdProvider);
  if (businessId == null) return 0;

  if (integrationId == null) {
    // Get total unread count across all integrations
    final conversations = await ref.watch(messagesProvider.future);
    return conversations.fold<int>(0, (total, conversation) {
      return total + conversation.unreadCount;
    });
  } else {
    // Get unread count for specific integration
    final conversations =
        await ref.watch(messagesProviderFiltered(integrationId).future);
    return conversations.fold<int>(0, (total, conversation) {
      return total + conversation.unreadCount;
    });
  }
});

class ModernMessagesScreen extends ConsumerStatefulWidget {
  final String? initialPlatform;
  final String? integrationId;

  const ModernMessagesScreen({
    Key? key,
    this.initialPlatform,
    this.integrationId,
  }) : super(key: key);

  @override
  ConsumerState<ModernMessagesScreen> createState() =>
      _ModernMessagesScreenState();
}

class _ModernMessagesScreenState extends ConsumerState<ModernMessagesScreen> {
  String? selectedIntegrationId;
  String? selectedIntegrationName;
  String? selectedAccountName;
  Conversation? selectedConversation;

  // Scroll controller for integration filter
  final ScrollController _integrationScrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    selectedIntegrationId = widget.integrationId;

    // Add scroll listener for arrows
    _integrationScrollController.addListener(_updateArrowVisibility);

    // Check scrollable content after frame builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScrollableContent();
    });
  }

  @override
  void dispose() {
    _integrationScrollController.dispose();
    super.dispose();
  }

  void _checkScrollableContent() {
    if (_integrationScrollController.hasClients) {
      final maxScrollExtent =
          _integrationScrollController.position.maxScrollExtent;
      setState(() {
        _showRightArrow = maxScrollExtent > 0;
      });
    }
  }

  void _updateArrowVisibility() {
    if (!_integrationScrollController.hasClients) return;

    final position = _integrationScrollController.position;
    setState(() {
      _showLeftArrow = position.pixels > 10;
      _showRightArrow = position.pixels < position.maxScrollExtent - 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Consumer(
        builder: (context, ref, child) {
          // Check if business is selected
          final hasSelectedBusiness = ref.watch(hasSelectedBusinessProvider);

          if (!hasSelectedBusiness) {
            return _buildNoBusinessSelectedView();
          }

          return Column(
            children: [
              // Header with Integration Filters
              _buildHeader(ref),

              // Main Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 0),
                  child: isDesktop
                      ? _buildDesktopLayout(ref)
                      : _buildMobileLayout(ref),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(WidgetRef ref) {
    final integrationStatsAsync = ref.watch(integrationStatsProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Messages',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (selectedIntegrationName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            selectedIntegrationName!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedAccountName != null
                        ? 'Viewing conversations from ${selectedAccountName!}'
                        : selectedIntegrationName != null
                            ? 'Viewing conversations from $selectedIntegrationName'
                            : 'Tap an integration below to filter conversations',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Integration Filter with Scroll Indicators
            Container(
              height: 64,
              margin: const EdgeInsets.only(bottom: 8),
              child: integrationStatsAsync.when(
                data: (integrationStats) => _buildIntegrationFilterWithArrows(
                    integrationStats.integrations),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Error loading integrations',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrationFilterWithArrows(List<Integration> integrations) {
    // Sort alphabetically by platform name
    final sortedIntegrations = List<Integration>.from(integrations)
      ..sort((a, b) => a.platformName.compareTo(b.platformName));

    return Stack(
      children: [
        // Main ListView
        ListView.builder(
          controller: _integrationScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          itemCount: sortedIntegrations.length + 1, // +1 for "All" option
          itemBuilder: (context, index) {
            if (index == 0) {
              // "All" option
              return Consumer(
                builder: (context, ref, child) {
                  final unreadCountAsync =
                      ref.watch(integrationUnreadCountsProvider(null));
                  return unreadCountAsync.when(
                    data: (unreadCount) => _buildIntegrationItem(
                      platform: 'All',
                      icon: Icons.dashboard_outlined,
                      iconUrl: null,
                      unreadCount: unreadCount,
                      isSelected: selectedIntegrationId == null,
                      onTap: () {
                        print(
                            '🔄 Switching to "All" tab - should show GROUPED conversations');
                        setState(() {
                          selectedIntegrationId = null;
                          selectedIntegrationName = null;
                          selectedAccountName = null;
                          selectedConversation = null;
                        });
                      },
                    ),
                    loading: () => _buildIntegrationItem(
                      platform: 'All',
                      icon: Icons.dashboard_outlined,
                      iconUrl: null,
                      unreadCount: 0,
                      isSelected: selectedIntegrationId == null,
                      onTap: () {
                        setState(() {
                          selectedIntegrationId = null;
                          selectedIntegrationName = null;
                          selectedAccountName = null;
                          selectedConversation = null;
                        });
                      },
                    ),
                    error: (_, __) => _buildIntegrationItem(
                      platform: 'All',
                      icon: Icons.dashboard_outlined,
                      iconUrl: null,
                      unreadCount: 0,
                      isSelected: selectedIntegrationId == null,
                      onTap: () {
                        setState(() {
                          selectedIntegrationId = null;
                          selectedIntegrationName = null;
                          selectedAccountName = null;
                          selectedConversation = null;
                        });
                      },
                    ),
                  );
                },
              );
            }

            final integration = sortedIntegrations[index - 1];
            return Consumer(
              builder: (context, ref, child) {
                final unreadCountAsync =
                    ref.watch(integrationUnreadCountsProvider(integration.id));
                return unreadCountAsync.when(
                  data: (unreadCount) => _buildIntegrationItem(
                    platform: integration.platformName,
                    icon: _getIntegrationIcon(integration.platformName),
                    iconUrl: integration.platformIcon,
                    unreadCount: unreadCount,
                    isSelected: selectedIntegrationId == integration.id,
                    onTap: () {
                      final accountName =
                          _getAccountNameFromIntegration(integration);
                      setState(() {
                        selectedIntegrationId = integration.id;
                        selectedIntegrationName = integration.platformName;
                        selectedAccountName = accountName;
                        selectedConversation = null;
                      });
                    },
                  ),
                  loading: () => _buildIntegrationItem(
                    platform: integration.platformName,
                    icon: _getIntegrationIcon(integration.platformName),
                    iconUrl: integration.platformIcon,
                    unreadCount: 0,
                    isSelected: selectedIntegrationId == integration.id,
                    onTap: () {
                      final accountName =
                          _getAccountNameFromIntegration(integration);
                      setState(() {
                        selectedIntegrationId = integration.id;
                        selectedIntegrationName = integration.platformName;
                        selectedAccountName = accountName;
                        selectedConversation = null;
                      });
                    },
                  ),
                  error: (_, __) => _buildIntegrationItem(
                    platform: integration.platformName,
                    icon: _getIntegrationIcon(integration.platformName),
                    iconUrl: integration.platformIcon,
                    unreadCount: 0,
                    isSelected: selectedIntegrationId == integration.id,
                    onTap: () {
                      final accountName =
                          _getAccountNameFromIntegration(integration);
                      setState(() {
                        selectedIntegrationId = integration.id;
                        selectedIntegrationName = integration.platformName;
                        selectedAccountName = accountName;
                        selectedConversation = null;
                      });
                    },
                  ),
                );
              },
            );
          },
        ),

        // Left Arrow Indicator
        if (_showLeftArrow)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.chevron_left,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),

        // Right Arrow Indicator
        if (_showRightArrow)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIntegrationItem({
    required String platform,
    required IconData icon,
    String? iconUrl,
    required int unreadCount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isSelected
                ? _getPlatformColor(platform).withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Icon or Image
              Center(
                child: iconUrl != null && iconUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: iconUrl.startsWith('http')
                            ? Image.network(
                                iconUrl,
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback to material icon if image fails
                                  return Icon(
                                    icon,
                                    size: 24,
                                    color: isSelected
                                        ? _getPlatformColor(platform)
                                        : AppTheme.textSecondary,
                                  );
                                },
                              )
                            : Image.asset(
                                iconUrl,
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback to material icon if image fails
                                  return Icon(
                                    icon,
                                    size: 24,
                                    color: isSelected
                                        ? _getPlatformColor(platform)
                                        : AppTheme.textSecondary,
                                  );
                                },
                              ),
                      )
                    : Icon(
                        icon,
                        size: 24,
                        color: isSelected
                            ? _getPlatformColor(platform)
                            : AppTheme.textSecondary,
                      ),
              ),

              // Unread badge - Always show, even when 0
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: unreadCount > 0
                        ? Colors.red
                        : Colors.grey.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(WidgetRef ref) {
    final conversationsAsync = selectedIntegrationId != null
        ? ref.watch(messagesProviderFiltered(selectedIntegrationId!))
        : ref.watch(messagesProvider);

    return conversationsAsync.when(
      data: (conversations) {
        final showGroupedValue = selectedIntegrationId == null;
        print(
            '🖥️ Desktop layout: showGrouped=$showGroupedValue, selectedIntegrationId=$selectedIntegrationId, conversations=${conversations.length}');

        return Row(
          children: [
            // Conversations List
            SizedBox(
              width: 380,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(
                      color: AppTheme.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: ConversationMasterList(
                  conversations: conversations, // Pass filtered conversations
                  selectedChannel: selectedIntegrationName,
                  selectedConversationId: selectedConversation?.id,
                  onConversationSelected: (conversation) async {
                    print(
                        '💬 Desktop: Conversation selected: ${conversation.id}, unreadCount: ${conversation.unreadCount}');

                    // Mark conversation as read if it has unread messages
                    if (conversation.unreadCount > 0) {
                      try {
                        final messagesService =
                            ref.read(messagesServiceProvider);
                        await messagesService
                            .markConversationAsRead(conversation.id);
                        print(
                            '✅ Desktop: Marked conversation ${conversation.id} as read');

                        // Refresh conversations to update UI
                        ref.invalidate(messagesProvider);
                        if (selectedIntegrationId != null) {
                          ref.invalidate(
                              messagesProviderFiltered(selectedIntegrationId!));
                        }
                        // Also refresh integration unread counts
                        ref.invalidate(integrationUnreadCountsProvider(null));
                        ref.invalidate(integrationUnreadCountsProvider(
                            selectedIntegrationId));
                        // Also refresh integration unread counts
                        ref.invalidate(integrationUnreadCountsProvider(null));
                        ref.invalidate(integrationUnreadCountsProvider(
                            selectedIntegrationId));
                      } catch (e) {
                        print(
                            '❌ Desktop: Error marking conversation as read: $e');
                      }
                    }

                    setState(() {
                      selectedConversation = conversation;
                    });
                  },
                  skipPlatformFiltering: selectedIntegrationId != null,
                  showGrouped: selectedIntegrationId ==
                      null, // Group only when showing "All"
                ),
              ),
            ),

            // Detail View
            Expanded(
              child: selectedConversation != null
                  ? ConversationDetailView(
                      conversation: selectedConversation!,
                      showBackButton: false,
                      onBackPressed: () =>
                          setState(() => selectedConversation = null),
                    )
                  : _buildEmptyDetailView(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error: $error'),
      ),
    );
  }

  Widget _buildMobileLayout(WidgetRef ref) {
    if (selectedConversation != null) {
      return ConversationDetailView(
        conversation: selectedConversation!,
        showBackButton: true,
        onBackPressed: () => setState(() => selectedConversation = null),
      );
    }

    final conversationsAsync = selectedIntegrationId != null
        ? ref.watch(messagesProviderFiltered(selectedIntegrationId!))
        : ref.watch(messagesProvider);

    return conversationsAsync.when(
      data: (conversations) {
        final showGroupedValue = selectedIntegrationId == null;
        print(
            '📱 Mobile layout: showGrouped=$showGroupedValue, selectedIntegrationId=$selectedIntegrationId, conversations=${conversations.length}');

        return ConversationMasterList(
          conversations: conversations, // Pass filtered conversations
          selectedChannel: selectedIntegrationName,
          selectedConversationId: selectedConversation?.id,
          onConversationSelected: (conversation) async {
            print(
                '💬 Conversation selected: ${conversation.id}, unreadCount: ${conversation.unreadCount}');

            // Mark conversation as read if it has unread messages
            if (conversation.unreadCount > 0) {
              try {
                final messagesService = ref.read(messagesServiceProvider);
                await messagesService.markConversationAsRead(conversation.id);
                print('✅ Marked conversation ${conversation.id} as read');

                // Refresh conversations to update UI
                ref.invalidate(messagesProvider);
                if (selectedIntegrationId != null) {
                  ref.invalidate(
                      messagesProviderFiltered(selectedIntegrationId!));
                }
                // Also refresh integration unread counts
                ref.invalidate(integrationUnreadCountsProvider(null));
                ref.invalidate(
                    integrationUnreadCountsProvider(selectedIntegrationId));
              } catch (e) {
                print('❌ Error marking conversation as read: $e');
              }
            }

            setState(() {
              selectedConversation = conversation;
            });
          },
          skipPlatformFiltering: selectedIntegrationId != null,
          showGrouped:
              selectedIntegrationId == null, // Group only when showing "All"
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error: $error'),
      ),
    );
  }

  Widget _buildEmptyDetailView() {
    return Container(
      color: AppTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a conversation',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a conversation from the list to view messages',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBusinessSelectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Business Selected',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please select a business to view messages',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/select-business');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Select Business',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIntegrationIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
      case 'instagram business':
        return Icons.camera_alt;
      case 'facebook':
      case 'facebook page':
        return Icons.facebook;
      case 'whatsapp':
      case 'whatsapp business':
        return Icons.chat;
      case 'telegram':
        return Icons.telegram;
      case 'twitter':
      case 'x':
        return Icons.alternate_email;
      case 'linkedin':
        return Icons.business;
      case 'youtube':
        return Icons.video_library;
      case 'tiktok':
        return Icons.music_video;
      case 'email':
        return Icons.email;
      case 'sms':
        return Icons.sms;
      case 'website':
        return Icons.web;
      case 'messenger':
        return Icons.message;
      default:
        return Icons.chat;
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
      case 'instagram business':
        return const Color(0xFFE4405F);
      case 'facebook':
      case 'facebook page':
        return const Color(0xFF1877F2);
      case 'whatsapp':
      case 'whatsapp business':
        return const Color(0xFF25D366);
      case 'telegram':
        return const Color(0xFF0088CC);
      case 'twitter':
      case 'x':
        return const Color(0xFF1DA1F2);
      case 'linkedin':
        return const Color(0xFF0A66C2);
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'tiktok':
        return const Color(0xFF000000);
      case 'email':
        return const Color(0xFF34495E);
      case 'sms':
        return const Color(0xFF2ECC71);
      case 'website':
        return const Color(0xFF9B59B6);
      case 'messenger':
        return const Color(0xFF006AFF);
      case 'all':
        return AppTheme.primary;
      default:
        return AppTheme.primary;
    }
  }

  String _getAccountNameFromIntegration(Integration integration) {
    // Use the same pattern as dashboard integration cards
    return integration.pageName ?? integration.platformName;
  }
}

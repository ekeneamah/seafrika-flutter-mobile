import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/smart_reply_service.dart';
import '../../models/message.dart';

/// Smart Reply Chips Widget
///
/// Displays AI-generated reply suggestions as horizontal chips above
/// the message input field. Users can tap a chip to quickly send a response.
///
/// **Features:**
/// - ✅ Shows 3-5 contextual suggestions
/// - ✅ Smooth fade-in animation
/// - ✅ One-tap to insert text
/// - ✅ Loading state with shimmer
/// - ✅ Auto-hides if no suggestions
///
/// **Usage:**
/// ```dart
/// SmartReplyChips(
///   messages: conversationMessages,
///   userId: currentUserId,
///   onSuggestionTap: (text) {
///     messageController.text = text;
///     // User can still edit before sending
///   },
/// )
/// ```
class SmartReplyChips extends StatefulWidget {
  /// Recent messages for context (last 10 recommended)
  final List<Message> messages;

  /// Current user ID (to identify which messages are from user)
  final String userId;

  /// Callback when user taps a suggestion
  final Function(String) onSuggestionTap;

  /// Whether to show loading indicator
  final bool isLoading;

  const SmartReplyChips({
    Key? key,
    required this.messages,
    required this.userId,
    required this.onSuggestionTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<SmartReplyChips> createState() => _SmartReplyChipsState();
}

class _SmartReplyChipsState extends State<SmartReplyChips>
    with SingleTickerProviderStateMixin {
  final SmartReplyService _smartReplyService = SmartReplyService();
  List<String> _suggestions = [];
  bool _isLoadingSuggestions = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize fade animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // Load suggestions on init
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(SmartReplyChips oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload suggestions if messages changed
    if (widget.messages.length != oldWidget.messages.length) {
      _loadSuggestions();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _smartReplyService.dispose();
    super.dispose();
  }

  /// Load smart reply suggestions from ML Kit
  Future<void> _loadSuggestions() async {
    if (widget.messages.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoadingSuggestions = true);

    try {
      final suggestions = await _smartReplyService.getSuggestions(
        messages: widget.messages,
        userId: widget.userId,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoadingSuggestions = false;
        });

        // Animate in if we have suggestions
        if (suggestions.isNotEmpty) {
          _animationController.forward();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if loading or no suggestions
    if (_isLoadingSuggestions || _suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Smart reply icon
            Icon(
              Icons.auto_awesome,
              size: 16,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(width: 8),

            // Suggestion chips
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return _SuggestionChip(
                    text: suggestion,
                    onTap: () {
                      widget.onSuggestionTap(suggestion);

                      // Optional: Hide chips after selection
                      _animationController.reverse().then((_) {
                        if (mounted) {
                          setState(() => _suggestions = []);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual suggestion chip
class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Suggestion text
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 4),

              // Tap to insert icon
              Icon(
                Icons.arrow_forward_ios,
                size: 10,
                color: theme.colorScheme.primary.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

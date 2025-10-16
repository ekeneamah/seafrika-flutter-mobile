import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/typing_indicator_service.dart';

/// Animated typing indicator widget
///
/// Shows "User is typing..." with animated dots.
/// Displays platform icon for external users (Instagram, Messenger, WhatsApp).
class TypingIndicatorWidget extends StatefulWidget {
  final List<TypingUser> typingUsers;
  final EdgeInsetsGeometry? padding;

  const TypingIndicatorWidget({
    Key? key,
    required this.typingUsers,
    this.padding,
  }) : super(key: key);

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (widget.typingUsers.isNotEmpty) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(TypingIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.typingUsers.isNotEmpty && oldWidget.typingUsers.isEmpty) {
      _animationController.forward();
    } else if (widget.typingUsers.isEmpty && oldWidget.typingUsers.isNotEmpty) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final user = widget.typingUsers.first;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: widget.padding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Platform icon
            _buildPlatformIcon(user.platform, theme),
            const SizedBox(width: 8),

            // Typing text
            Expanded(
              child: Text(
                _getTypingText(widget.typingUsers),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            // Animated dots
            const SizedBox(width: 8),
            _AnimatedDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(String platform, ThemeData theme) {
    IconData? icon;
    Color? color;

    switch (platform.toLowerCase()) {
      case 'messenger':
        icon = Icons.messenger_outline;
        color = const Color(0xFF0084FF);
        break;
      case 'instagram':
        icon = Icons.camera_alt_outlined;
        color = const Color(0xFFE4405F);
        break;
      case 'whatsapp':
        icon = Icons.phone_outlined;
        color = const Color(0xFF25D366);
        break;
      case 'app':
        // Business user - use generic icon
        icon = Icons.person_outline;
        color = theme.colorScheme.primary;
        break;
      default:
        icon = Icons.chat_bubble_outline;
        color = theme.colorScheme.onSurfaceVariant;
    }

    return Icon(
      icon,
      size: 16,
      color: color.withOpacity(0.7),
    );
  }

  String _getTypingText(List<TypingUser> users) {
    if (users.isEmpty) return '';

    if (users.length == 1) {
      return '${users.first.userName} is typing';
    } else if (users.length == 2) {
      return '${users[0].userName} and ${users[1].userName} are typing';
    } else {
      return '${users[0].userName} and ${users.length - 1} others are typing';
    }
  }
}

/// Animated dots for typing indicator
class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = IntTween(begin: 0, end: 3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final dotCount = _animation.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final isActive = index < dotCount;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5)
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Compact typing indicator bubble for message list
///
/// Shows a small bubble with animated dots, similar to iMessage/WhatsApp.
class TypingBubble extends StatelessWidget {
  final bool isVisible;

  const TypingBubble({
    Key? key,
    this.isVisible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BouncingDot(delay: 0),
                const SizedBox(width: 4),
                _BouncingDot(delay: 200),
                const SizedBox(width: 4),
                _BouncingDot(delay: 400),
              ],
            ),
          ),
          const SizedBox(width: 50),
        ],
      ),
    );
  }
}

/// Bouncing dot animation for typing bubble
class _BouncingDot extends StatefulWidget {
  final int delay;

  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        );
      },
    );
  }
}

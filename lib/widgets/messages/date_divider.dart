import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Date divider widget for message list
///
/// Shows a divider with date text in the middle.
/// Used to separate messages by day (Today, Yesterday, dates, etc.)
class DateDivider extends StatelessWidget {
  final String dateText;
  final EdgeInsetsGeometry? margin;

  const DateDivider({
    Key? key,
    required this.dateText,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dateText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky date header for scrolling message list
///
/// Can be used with SliverPersistentHeader for sticky date headers.
class StickyDateHeader extends StatelessWidget {
  final String dateText;

  const StickyDateHeader({
    Key? key,
    required this.dateText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.scaffoldBackgroundColor.withOpacity(0.95),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            dateText,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

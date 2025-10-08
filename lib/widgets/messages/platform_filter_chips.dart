import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/message.dart';
import '../../providers/messages_provider.dart';

class PlatformFilterChips extends ConsumerWidget {
  const PlatformFilterChips({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPlatforms = ref.watch(selectedPlatformsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Platforms',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                if (selectedPlatforms.length == MessagePlatform.values.length) {
                  ref.read(selectedPlatformsProvider.notifier).selectNone();
                } else {
                  ref.read(selectedPlatformsProvider.notifier).selectAll();
                }
              },
              child: Text(
                selectedPlatforms.length == MessagePlatform.values.length
                    ? 'Clear All'
                    : 'Select All',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MessagePlatform.values.map((platform) {
            final isSelected = selectedPlatforms.contains(platform);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(platform.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    platform.displayName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                ref
                    .read(selectedPlatformsProvider.notifier)
                    .togglePlatform(platform);
              },
              selectedColor: _getPlatformColor(platform).withOpacity(0.2),
              checkmarkColor: _getPlatformColor(platform),
              backgroundColor:
                  theme.colorScheme.surfaceVariant.withOpacity(0.5),
              side: BorderSide(
                color: isSelected
                    ? _getPlatformColor(platform)
                    : theme.colorScheme.outline.withOpacity(0.5),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getPlatformColor(MessagePlatform platform) {
    switch (platform) {
      case MessagePlatform.facebook:
        return const Color(0xFF1877F2);
      case MessagePlatform.instagram:
        return const Color(0xFFE4405F);
      case MessagePlatform.messenger:
        return const Color(0xFF00B2FF);
      case MessagePlatform.whatsapp:
        return const Color(0xFF25D366);
      case MessagePlatform.tiktok:
        return const Color(0xFF000000);
      case MessagePlatform.youtube:
        return const Color(0xFFFF0000);
      case MessagePlatform.email:
        return const Color(0xFF34A853);
      case MessagePlatform.sms:
        return const Color(0xFF2196F3);
      case MessagePlatform.website:
        return const Color(0xFF9C27B0);
      case MessagePlatform.phone:
        return const Color(0xFF4CAF50);
    }
  }
}

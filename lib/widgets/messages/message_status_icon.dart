import 'package:flutter/material.dart';
import '../../models/message.dart';

/// Widget that displays message delivery status icons
/// Mimics WhatsApp-style status indicators:
/// - Clock icon: Sending
/// - Single check: Sent
/// - Double check: Delivered
/// - Double check (blue): Read
/// - Exclamation: Failed
class MessageStatusIcon extends StatelessWidget {
  final MessageStatus status;
  final double size;
  final Color? color;

  const MessageStatusIcon({
    Key? key,
    required this.status,
    this.size = 16,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return _buildIcon(
          Icons.access_time,
          color ?? Colors.grey[400]!,
          'Sending...',
        );

      case MessageStatus.sent:
        return _buildCheckmarks(
          1,
          color ?? Colors.grey[400]!,
          'Sent',
        );

      case MessageStatus.delivered:
        return _buildCheckmarks(
          2,
          color ?? Colors.grey[400]!,
          'Delivered',
        );

      case MessageStatus.read:
        return _buildCheckmarks(
          2,
          color ?? Colors.blue[400]!,
          'Read',
        );

      case MessageStatus.failed:
        return _buildIcon(
          Icons.error_outline,
          color ?? Colors.red[400]!,
          'Failed to send',
        );
    }
  }

  Widget _buildIcon(IconData icon, Color iconColor, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: size,
        color: iconColor,
      ),
    );
  }

  Widget _buildCheckmarks(int count, Color iconColor, String tooltip) {
    if (count == 1) {
      return Tooltip(
        message: tooltip,
        child: Icon(
          Icons.check,
          size: size,
          color: iconColor,
        ),
      );
    }

    // Double checkmarks (for delivered/read)
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size * 1.2,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: Icon(
                Icons.check,
                size: size,
                color: iconColor,
              ),
            ),
            Positioned(
              left: size * 0.4,
              child: Icon(
                Icons.check,
                size: size,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../config/theme.dart';

class AttachmentPreview extends StatelessWidget {
  final File file;
  final String attachmentType;
  final VoidCallback? onRemove;
  final VoidCallback? onView;

  const AttachmentPreview({
    Key? key,
    required this.file,
    required this.attachmentType,
    this.onRemove,
    this.onView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          _buildPreviewContent(context),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    switch (attachmentType) {
      case 'image':
        return _ImagePreview(file: file, onView: onView);
      case 'video':
        return _VideoPreview(file: file, onView: onView);
      case 'document':
        return _DocumentPreview(file: file, onView: onView);
      default:
        return _GenericFilePreview(file: file, onView: onView);
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onView != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon:
                    const Icon(Icons.visibility, color: Colors.white, size: 20),
                onPressed: onView,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
          const SizedBox(width: 4),
          if (onRemove != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: onRemove,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File file;
  final VoidCallback? onView;

  const _ImagePreview({required this.file, this.onView});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onView,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.softGreen,
          ),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: AppTheme.softGreen,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, color: AppTheme.textSecondary, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      'Image',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final File file;
  final VoidCallback? onView;

  const _VideoPreview({required this.file, this.onView});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.file);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onView,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.softGreen,
          ),
          child: _isInitialized && _controller != null
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam,
                        color: AppTheme.textSecondary, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  final File file;
  final VoidCallback? onView;

  const _DocumentPreview({required this.file, this.onView});

  @override
  Widget build(BuildContext context) {
    final fileName = file.path.split('/').last;
    final fileSize = _formatFileSize(file.lengthSync());
    final fileExtension = _getFileExtension(fileName);

    return GestureDetector(
      onTap: onView,
      child: Container(
        width: 200,
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.softGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getFileIcon(fileExtension),
              color: AppTheme.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              fileName,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              fileSize,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    return lastDot != -1 ? fileName.substring(lastDot + 1) : '';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _GenericFilePreview extends StatelessWidget {
  final File file;
  final VoidCallback? onView;

  const _GenericFilePreview({required this.file, this.onView});

  @override
  Widget build(BuildContext context) {
    final fileName = file.path.split('/').last;
    final fileSize = _formatFileSize(file.lengthSync());

    return GestureDetector(
      onTap: onView,
      child: Container(
        width: 200,
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.softGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.attachment,
              color: AppTheme.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              fileName,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              fileSize,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Widget to show multiple attachment previews
class AttachmentPreviewList extends StatelessWidget {
  final List<File> files;
  final List<String> attachmentTypes;
  final Function(int index)? onRemove;
  final Function(int index)? onView;

  const AttachmentPreviewList({
    Key? key,
    required this.files,
    required this.attachmentTypes,
    this.onRemove,
    this.onView,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        itemBuilder: (context, index) {
          return AttachmentPreview(
            file: files[index],
            attachmentType: attachmentTypes[index],
            onRemove: onRemove != null ? () => onRemove!(index) : null,
            onView: onView != null ? () => onView!(index) : null,
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

/// Search bar with debounced input for message search
class MessageSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final Function()? onClear;
  final Function()? onClose;
  final String? initialQuery;
  final Duration debounceDuration;
  final bool autoFocus;
  final String hintText;

  const MessageSearchBar({
    Key? key,
    required this.onSearch,
    this.onClear,
    this.onClose,
    this.initialQuery,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.autoFocus = true,
    this.hintText = 'Search messages...',
  }) : super(key: key);

  @override
  State<MessageSearchBar> createState() => _MessageSearchBarState();
}

class _MessageSearchBarState extends State<MessageSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  Timer? _debounceTimer;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    final query = _controller.text.trim();

    if (query.isEmpty) {
      setState(() => _isSearching = false);
      widget.onClear?.call();
      return;
    }

    // Show searching state immediately
    setState(() => _isSearching = true);

    // Debounce the search
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted && query.isNotEmpty) {
        widget.onSearch(query);
      }
    });
  }

  void _clearSearch() {
    _controller.clear();
    _focusNode.requestFocus();
    setState(() => _isSearching = false);
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back/Close button
          IconButton(
            onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Close search',
          ),
          const SizedBox(width: 8),

          // Search input field
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.search,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),

                  // Clear button or searching indicator
                  if (_isSearching && _controller.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  else if (_controller.text.isNotEmpty)
                    IconButton(
                      onPressed: _clearSearch,
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Clear',
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact search button for app bars
class SearchButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const SearchButton({
    Key? key,
    required this.onPressed,
    this.tooltip = 'Search messages',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.search),
      tooltip: tooltip,
    );
  }
}

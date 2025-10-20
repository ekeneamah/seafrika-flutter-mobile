import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/search_api_service.dart';
import '../widgets/messages/message_search_bar.dart';
import '../widgets/messages/search_results_list.dart';

/// Full-screen message search with conversation and business-wide search
class MessageSearchScreen extends ConsumerStatefulWidget {
  final String? conversationId;
  final String? businessId;
  final String? initialQuery;

  const MessageSearchScreen({
    Key? key,
    this.conversationId,
    this.businessId,
    this.initialQuery,
  }) : super(key: key);

  @override
  ConsumerState<MessageSearchScreen> createState() =>
      _MessageSearchScreenState();
}

class _MessageSearchScreenState extends ConsumerState<MessageSearchScreen> {
  final SearchApiService _searchService = SearchApiService();

  List<Map<String, dynamic>> _results = [];
  String _currentQuery = '';
  bool _isLoading = false;
  bool _hasMore = false;
  int _currentPage = 0;
  int _totalResults = 0;
  DateTime? _searchStartTime;
  Duration? _searchDuration;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _performSearch(widget.initialQuery!);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _currentQuery = '';
        _totalResults = 0;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _currentQuery = query;
      _currentPage = 0;
      _results = [];
      _error = null;
      _searchStartTime = DateTime.now();
    });

    try {
      Map<String, dynamic> response;

      if (widget.conversationId != null) {
        // Search within conversation
        response = await _searchService.searchMessages(
          conversationId: widget.conversationId!,
          query: query,
          limit: 50,
          page: 0,
        );
      } else if (widget.businessId != null) {
        // Search across all business conversations
        response = await _searchService.searchBusinessMessages(
          businessId: widget.businessId!,
          query: query,
          limit: 50,
          page: 0,
        );
      } else {
        throw Exception('Either conversationId or businessId must be provided');
      }

      if (mounted) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(response['results'] ?? []);
          _totalResults = response['total'] ?? 0;
          _hasMore = response['hasMore'] ?? false;
          _isLoading = false;
          _searchDuration = DateTime.now().difference(_searchStartTime!);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final nextPage = _currentPage + 1;
      Map<String, dynamic> response;

      if (widget.conversationId != null) {
        response = await _searchService.searchMessages(
          conversationId: widget.conversationId!,
          query: _currentQuery,
          limit: 50,
          page: nextPage,
        );
      } else if (widget.businessId != null) {
        response = await _searchService.searchBusinessMessages(
          businessId: widget.businessId!,
          query: _currentQuery,
          limit: 50,
          page: nextPage,
        );
      } else {
        return;
      }

      if (mounted) {
        setState(() {
          _results.addAll(
            List<Map<String, dynamic>>.from(response['results'] ?? []),
          );
          _hasMore = response['hasMore'] ?? false;
          _currentPage = nextPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: $e')),
        );
      }
    }
  }

  void _onResultTap(String messageId, String conversationId) {
    // Navigate to the conversation and scroll to the message
    Navigator.of(context).pop({
      'action': 'navigate',
      'messageId': messageId,
      'conversationId': conversationId,
    });
  }

  void _onClear() {
    setState(() {
      _results = [];
      _currentQuery = '';
      _totalResults = 0;
      _error = null;
      _searchDuration = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            MessageSearchBar(
              onSearch: _performSearch,
              onClear: _onClear,
              initialQuery: widget.initialQuery,
              hintText: widget.conversationId != null
                  ? 'Search in conversation...'
                  : 'Search all messages...',
            ),

            // Search stats
            if (_totalResults > 0 && !_isLoading)
              SearchStats(
                totalResults: _totalResults,
                query: _currentQuery,
                searchDuration: _searchDuration,
              ),

            // Results or error
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorState();
    }

    if (_currentQuery.isEmpty) {
      return _buildInitialState();
    }

    return SearchResultsList(
      results: _results,
      query: _currentQuery,
      isLoading: _isLoading,
      hasMore: _hasMore,
      onLoadMore: _loadMore,
      onResultTap: _onResultTap,
      emptyMessage: 'No messages found for "$_currentQuery"',
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              widget.conversationId != null
                  ? 'Search messages in this conversation'
                  : 'Search all your messages',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Type a keyword to start searching',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _performSearch(_currentQuery),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

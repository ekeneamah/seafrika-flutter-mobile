import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/search_api_service.dart';

/// Provider for the SearchApiService singleton
final searchApiServiceProvider = Provider<SearchApiService>((ref) {
  return SearchApiService();
});

/// State class for search results
class SearchState {
  final List<Map<String, dynamic>> results;
  final bool isLoading;
  final bool hasMore;
  final int totalResults;
  final int currentPage;
  final String query;
  final String? error;
  final Duration? searchDuration;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.totalResults = 0,
    this.currentPage = 0,
    this.query = '',
    this.error,
    this.searchDuration,
  });

  SearchState copyWith({
    List<Map<String, dynamic>>? results,
    bool? isLoading,
    bool? hasMore,
    int? totalResults,
    int? currentPage,
    String? query,
    String? error,
    Duration? searchDuration,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      totalResults: totalResults ?? this.totalResults,
      currentPage: currentPage ?? this.currentPage,
      query: query ?? this.query,
      error: error ?? this.error,
      searchDuration: searchDuration ?? this.searchDuration,
    );
  }

  SearchState clearError() {
    return copyWith(error: null);
  }

  SearchState reset() {
    return const SearchState();
  }
}

/// StateNotifier for managing search state
class SearchNotifier extends StateNotifier<SearchState> {
  final SearchApiService _searchService;

  SearchNotifier(this._searchService) : super(const SearchState());

  /// Perform a new search
  Future<void> search({
    required String query,
    String? conversationId,
    String? businessId,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) {
      state = state.reset();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      query: query,
      currentPage: 0,
      results: [],
      error: null,
    );

    final startTime = DateTime.now();

    try {
      Map<String, dynamic> response;

      if (conversationId != null) {
        response = await _searchService.searchMessages(
          conversationId: conversationId,
          query: query,
          limit: limit,
          page: 0,
        );
      } else if (businessId != null) {
        response = await _searchService.searchBusinessMessages(
          businessId: businessId,
          query: query,
          limit: limit,
          page: 0,
        );
      } else {
        throw Exception('Either conversationId or businessId must be provided');
      }

      final duration = DateTime.now().difference(startTime);

      state = state.copyWith(
        results: List<Map<String, dynamic>>.from(response['results'] ?? []),
        totalResults: response['total'] ?? 0,
        hasMore: response['hasMore'] ?? false,
        isLoading: false,
        searchDuration: duration,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load more results (pagination)
  Future<void> loadMore({
    String? conversationId,
    String? businessId,
    int limit = 50,
  }) async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      Map<String, dynamic> response;

      if (conversationId != null) {
        response = await _searchService.searchMessages(
          conversationId: conversationId,
          query: state.query,
          limit: limit,
          page: nextPage,
        );
      } else if (businessId != null) {
        response = await _searchService.searchBusinessMessages(
          businessId: businessId,
          query: state.query,
          limit: limit,
          page: nextPage,
        );
      } else {
        return;
      }

      state = state.copyWith(
        results: [
          ...state.results,
          ...List<Map<String, dynamic>>.from(response['results'] ?? []),
        ],
        hasMore: response['hasMore'] ?? false,
        currentPage: nextPage,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear search results
  void clear() {
    state = state.reset();
  }

  /// Clear error message
  void clearError() {
    state = state.clearError();
  }
}

/// Provider for search state management
final searchProvider =
    StateNotifierProvider.autoDispose<SearchNotifier, SearchState>((ref) {
  final searchService = ref.watch(searchApiServiceProvider);
  return SearchNotifier(searchService);
});

/// Search history provider
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const String _storageKey = 'search_history';
  static const int _maxHistoryItems = 20;

  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_storageKey) ?? [];
      state = history;
    } catch (e) {
      // Ignore errors loading history
      state = [];
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, state);
    } catch (e) {
      // Ignore errors saving history
    }
  }

  /// Add a search query to history
  Future<void> addQuery(String query) async {
    if (query.trim().isEmpty) return;

    final trimmedQuery = query.trim();

    // Remove duplicates and add to front
    final newHistory = [
      trimmedQuery,
      ...state.where((q) => q != trimmedQuery),
    ];

    // Limit history size
    state = newHistory.take(_maxHistoryItems).toList();

    await _saveHistory();
  }

  /// Remove a query from history
  Future<void> removeQuery(String query) async {
    state = state.where((q) => q != query).toList();
    await _saveHistory();
  }

  /// Clear all history
  Future<void> clearHistory() async {
    state = [];
    await _saveHistory();
  }

  /// Get suggestions based on partial query
  List<String> getSuggestions(String query) {
    if (query.trim().isEmpty) return state;

    final lowerQuery = query.toLowerCase();
    return state.where((q) => q.toLowerCase().contains(lowerQuery)).toList();
  }
}

/// Provider for search history
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

/// Provider for search suggestions
final searchSuggestionsProvider = FutureProvider.family<List<String>, String>(
  (ref, query) async {
    if (query.trim().isEmpty) {
      // Return recent search history
      return ref.watch(searchHistoryProvider);
    }

    try {
      // Get suggestions from backend
      final searchService = ref.watch(searchApiServiceProvider);
      final suggestions = await searchService.getSuggestions(query: query);

      // Combine with local history suggestions
      final historyNotifier = ref.read(searchHistoryProvider.notifier);
      final historySuggestions = historyNotifier.getSuggestions(query);

      // Merge and deduplicate
      final allSuggestions = {...suggestions, ...historySuggestions}.toList();

      return allSuggestions;
    } catch (e) {
      // Fallback to history suggestions only
      final historyNotifier = ref.read(searchHistoryProvider.notifier);
      return historyNotifier.getSuggestions(query);
    }
  },
);

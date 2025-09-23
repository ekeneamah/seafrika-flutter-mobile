import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/services/tiktok_service.dart';
import 'package:vendor_app/models/tiktok_models.dart';
import 'dart:io';

// TikTok Service Provider
final tikTokServiceProvider = Provider<TikTokService>((ref) {
  return TikTokService();
});

// TikTok Authentication State
class TikTokAuthState {
  final bool isAuthenticated;
  final TikTokUser? user;
  final String? error;
  final bool isLoading;

  TikTokAuthState({
    this.isAuthenticated = false,
    this.user,
    this.error,
    this.isLoading = false,
  });

  TikTokAuthState copyWith({
    bool? isAuthenticated,
    TikTokUser? user,
    String? error,
    bool? isLoading,
  }) {
    return TikTokAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// TikTok Authentication Provider
class TikTokAuthNotifier extends StateNotifier<TikTokAuthState> {
  final TikTokService _tikTokService;

  TikTokAuthNotifier(this._tikTokService) : super(TikTokAuthState());

  Future<void> authenticate({
    required String code,
    required String redirectUri,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _tikTokService.authenticateTikTok(
        code: code,
        redirectUri: redirectUri,
        businessId: businessId,
        userId: userId,
        token: token,
      );

      final user = TikTokUser.fromJson(result['user']);
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> loadUserProfile({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _tikTokService.getUserProfile(
        businessId: businessId,
        userId: userId,
        token: token,
      );

      final user = TikTokUser.fromJson(result);
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> disconnect({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _tikTokService.disconnectTikTok(
        businessId: businessId,
        userId: userId,
        token: token,
      );

      state = TikTokAuthState(); // Reset to initial state
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final tikTokAuthProvider =
    StateNotifierProvider<TikTokAuthNotifier, TikTokAuthState>((ref) {
  final tikTokService = ref.watch(tikTokServiceProvider);
  return TikTokAuthNotifier(tikTokService);
});

// TikTok Videos State Provider
class TikTokVideosNotifier extends StateNotifier<TikTokVideosState> {
  final TikTokService _tikTokService;

  TikTokVideosNotifier(this._tikTokService) : super(TikTokVideosState());

  Future<void> loadVideos({
    required String businessId,
    int limit = 20,
    bool refresh = false,
    String? userId,
    String? token,
  }) async {
    if (refresh) {
      state = TikTokVideosState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final result = await _tikTokService.getUserVideos(
        businessId: businessId,
        limit: limit,
        cursor: refresh ? null : state.cursor,
        userId: userId,
        token: token,
      );

      final newVideos = (result['data']['videos'] as List)
          .map((video) => TikTokVideo.fromJson(video))
          .toList();

      final videos = refresh ? newVideos : [...state.videos, ...newVideos];

      state = state.copyWith(
        videos: videos,
        cursor: result['data']['cursor'],
        hasMore: result['data']['has_more'] ?? false,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> refreshVideos({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    await loadVideos(
      businessId: businessId,
      refresh: true,
      userId: userId,
      token: token,
    );
  }

  Future<void> loadMoreVideos({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    if (!state.hasMore || state.isLoading) return;

    await loadVideos(
      businessId: businessId,
      userId: userId,
      token: token,
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final tikTokVideosProvider =
    StateNotifierProvider<TikTokVideosNotifier, TikTokVideosState>((ref) {
  final tikTokService = ref.watch(tikTokServiceProvider);
  return TikTokVideosNotifier(tikTokService);
});

// TikTok Comments State Provider
class TikTokCommentsNotifier extends StateNotifier<TikTokCommentsState> {
  final TikTokService _tikTokService;

  TikTokCommentsNotifier(this._tikTokService) : super(TikTokCommentsState());

  Future<void> loadComments({
    required String videoId,
    required String businessId,
    int limit = 20,
    bool refresh = false,
    String? userId,
    String? token,
  }) async {
    if (refresh) {
      state = TikTokCommentsState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final result = await _tikTokService.getVideoComments(
        videoId: videoId,
        businessId: businessId,
        limit: limit,
        cursor: refresh ? null : state.cursor,
        userId: userId,
        token: token,
      );

      final newComments = (result['data']['comments'] as List)
          .map((comment) => TikTokComment.fromJson(comment))
          .toList();

      final comments =
          refresh ? newComments : [...state.comments, ...newComments];

      state = state.copyWith(
        comments: comments,
        cursor: result['data']['cursor'],
        hasMore: result['data']['has_more'] ?? false,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> replyToComment({
    required String videoId,
    required String commentId,
    required String text,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    try {
      await _tikTokService.replyToComment(
        videoId: videoId,
        commentId: commentId,
        text: text,
        businessId: businessId,
        userId: userId,
        token: token,
      );

      // Refresh comments to show the new reply
      await loadComments(
        videoId: videoId,
        businessId: businessId,
        refresh: true,
        userId: userId,
        token: token,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final tikTokCommentsProvider =
    StateNotifierProvider<TikTokCommentsNotifier, TikTokCommentsState>((ref) {
  final tikTokService = ref.watch(tikTokServiceProvider);
  return TikTokCommentsNotifier(tikTokService);
});

// TikTok Integration Status Provider
class TikTokIntegrationState {
  final bool isConnected;
  final Map<String, dynamic>? settings;
  final bool isLoading;
  final String? error;
  final DateTime? lastSyncAt;

  TikTokIntegrationState({
    this.isConnected = false,
    this.settings,
    this.isLoading = false,
    this.error,
    this.lastSyncAt,
  });

  TikTokIntegrationState copyWith({
    bool? isConnected,
    Map<String, dynamic>? settings,
    bool? isLoading,
    String? error,
    DateTime? lastSyncAt,
  }) {
    return TikTokIntegrationState(
      isConnected: isConnected ?? this.isConnected,
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

class TikTokIntegrationNotifier extends StateNotifier<TikTokIntegrationState> {
  final TikTokService _tikTokService;

  TikTokIntegrationNotifier(this._tikTokService)
      : super(TikTokIntegrationState());

  Future<void> loadIntegrationStatus({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _tikTokService.getIntegrationStatus(
        businessId: businessId,
        userId: userId,
        token: token,
      );

      state = state.copyWith(
        isConnected: result['is_connected'] ?? false,
        settings: result['settings'],
        lastSyncAt: result['last_sync_at'] != null
            ? DateTime.parse(result['last_sync_at'])
            : null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> updateSettings({
    required String businessId,
    required Map<String, dynamic> settings,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _tikTokService.updateIntegrationSettings(
        businessId: businessId,
        settings: settings,
        userId: userId,
        token: token,
      );

      state = state.copyWith(
        settings: settings,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> syncData({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _tikTokService.syncTikTokData(
        businessId: businessId,
        userId: userId,
        token: token,
      );

      state = state.copyWith(
        lastSyncAt: DateTime.now(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final tikTokIntegrationProvider =
    StateNotifierProvider<TikTokIntegrationNotifier, TikTokIntegrationState>(
        (ref) {
  final tikTokService = ref.watch(tikTokServiceProvider);
  return TikTokIntegrationNotifier(tikTokService);
});

// Analytics Provider
final tikTokAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, String>>(
        (ref, params) async {
  final tikTokService = ref.watch(tikTokServiceProvider);

  return await tikTokService.getUserAnalytics(
    businessId: params['businessId']!,
    dateRange: params['dateRange'],
    userId: params['userId'],
    token: params['token'],
  );
});

// Video Analytics Provider
final tikTokVideoAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, Map<String, String>>(
        (ref, params) async {
  final tikTokService = ref.watch(tikTokServiceProvider);

  return await tikTokService.getVideoAnalytics(
    videoId: params['videoId']!,
    businessId: params['businessId']!,
    userId: params['userId'],
    token: params['token'],
  );
});

// Integration Logs Provider
final tikTokLogsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, Map<String, String>>(
        (ref, params) async {
  final tikTokService = ref.watch(tikTokServiceProvider);

  return await tikTokService.getIntegrationLogs(
    businessId: params['businessId']!,
    limit: int.tryParse(params['limit'] ?? '50') ?? 50,
    userId: params['userId'],
    token: params['token'],
  );
});

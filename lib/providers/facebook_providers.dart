import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/services/facebook_service.dart';
import 'package:vendor_app/models/facebook_models.dart';
import 'dart:io';

// Facebook Service Provider
final facebookServiceProvider = Provider<FacebookService>((ref) {
  return FacebookService();
});

// Facebook Authentication State
class FacebookAuthState {
  final bool isAuthenticated;
  final FacebookUser? user;
  final String? error;
  final bool isLoading;

  FacebookAuthState({
    this.isAuthenticated = false,
    this.user,
    this.error,
    this.isLoading = false,
  });

  FacebookAuthState copyWith({
    bool? isAuthenticated,
    FacebookUser? user,
    String? error,
    bool? isLoading,
  }) {
    return FacebookAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Facebook Authentication Provider
class FacebookAuthNotifier extends StateNotifier<FacebookAuthState> {
  final FacebookService _facebookService;

  FacebookAuthNotifier(this._facebookService) : super(FacebookAuthState());

  Future<void> authenticate({
    required String code,
    required String redirectUri,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _facebookService.authenticateFacebook(
        code: code,
        redirectUri: redirectUri,
        businessId: businessId,
        userId: userId,
        token: token,
      );
      
      final user = FacebookUser.fromJson(result['user']);
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
      final result = await _facebookService.getUserProfile(
        businessId: businessId,
        userId: userId,
        token: token,
      );
      
      final user = FacebookUser.fromJson(result);
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
    state = state.copyWith(isLoading: true);
    
    try {
      await _facebookService.disconnectFacebook(
        businessId: businessId,
        userId: userId,
        token: token,
      );
      
      state = FacebookAuthState();
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }
}

final facebookAuthProvider = StateNotifierProvider<FacebookAuthNotifier, FacebookAuthState>((ref) {
  final facebookService = ref.watch(facebookServiceProvider);
  return FacebookAuthNotifier(facebookService);
});

// Facebook Pages State
class FacebookPagesState {
  final List<FacebookPage> pages;
  final FacebookPage? selectedPage;
  final String? error;
  final bool isLoading;

  FacebookPagesState({
    this.pages = const [],
    this.selectedPage,
    this.error,
    this.isLoading = false,
  });

  FacebookPagesState copyWith({
    List<FacebookPage>? pages,
    FacebookPage? selectedPage,
    String? error,
    bool? isLoading,
  }) {
    return FacebookPagesState(
      pages: pages ?? this.pages,
      selectedPage: selectedPage ?? this.selectedPage,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Facebook Pages Provider
class FacebookPagesNotifier extends StateNotifier<FacebookPagesState> {
  final FacebookService _facebookService;

  FacebookPagesNotifier(this._facebookService) : super(FacebookPagesState());

  Future<void> loadPages({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final pagesData = await _facebookService.getUserPages(
        businessId: businessId,
        userId: userId,
        token: token,
      );
      
      final pages = pagesData.map((pageData) => FacebookPage.fromJson(pageData)).toList();
      state = state.copyWith(
        pages: pages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  void selectPage(FacebookPage page) {
    state = state.copyWith(selectedPage: page);
  }

  Future<void> subscribePageWebhooks({
    required String pageId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    try {
      await _facebookService.subscribePageWebhooks(
        pageId: pageId,
        businessId: businessId,
        userId: userId,
        token: token,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final facebookPagesProvider = StateNotifierProvider<FacebookPagesNotifier, FacebookPagesState>((ref) {
  final facebookService = ref.watch(facebookServiceProvider);
  return FacebookPagesNotifier(facebookService);
});

// Facebook Posts State
class FacebookPostsState {
  final List<FacebookPost> posts;
  final String? error;
  final bool isLoading;

  FacebookPostsState({
    this.posts = const [],
    this.error,
    this.isLoading = false,
  });

  FacebookPostsState copyWith({
    List<FacebookPost>? posts,
    String? error,
    bool? isLoading,
  }) {
    return FacebookPostsState(
      posts: posts ?? this.posts,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Facebook Posts Provider
class FacebookPostsNotifier extends StateNotifier<FacebookPostsState> {
  final FacebookService _facebookService;

  FacebookPostsNotifier(this._facebookService) : super(FacebookPostsState());

  Future<void> loadPagePosts({
    required String pageId,
    required String businessId,
    int? limit,
    String? fields,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final postsData = await _facebookService.getPagePosts(
        pageId: pageId,
        businessId: businessId,
        limit: limit,
        fields: fields,
        userId: userId,
        token: token,
      );
      
      final posts = postsData.map((postData) => FacebookPost.fromJson(postData)).toList();
      state = state.copyWith(
        posts: posts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> createPost({
    required String pageId,
    required String message,
    required String businessId,
    String? link,
    String? imageUrl,
    bool published = true,
    String? userId,
    String? token,
  }) async {
    try {
      await _facebookService.createPagePost(
        pageId: pageId,
        message: message,
        businessId: businessId,
        link: link,
        imageUrl: imageUrl,
        published: published,
        userId: userId,
        token: token,
      );
      
      // Reload posts after creating
      await loadPagePosts(
        pageId: pageId,
        businessId: businessId,
        userId: userId,
        token: token,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> uploadPhoto({
    required String pageId,
    required File photo,
    required String businessId,
    String? caption,
    bool published = true,
    String? userId,
    String? token,
  }) async {
    try {
      await _facebookService.uploadPagePhoto(
        pageId: pageId,
        photo: photo,
        businessId: businessId,
        caption: caption,
        published: published,
        userId: userId,
        token: token,
      );
      
      // Reload posts after uploading
      await loadPagePosts(
        pageId: pageId,
        businessId: businessId,
        userId: userId,
        token: token,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> uploadVideo({
    required String pageId,
    required File video,
    required String businessId,
    String? title,
    String? description,
    bool published = true,
    String? userId,
    String? token,
  }) async {
    try {
      await _facebookService.uploadPageVideo(
        pageId: pageId,
        video: video,
        businessId: businessId,
        title: title,
        description: description,
        published: published,
        userId: userId,
        token: token,
      );
      
      // Reload posts after uploading
      await loadPagePosts(
        pageId: pageId,
        businessId: businessId,
        userId: userId,
        token: token,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deletePost({
    required String postId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    try {
      await _facebookService.deletePost(
        postId: postId,
        businessId: businessId,
        userId: userId,
        token: token,
      );
      
      // Remove post from state
      state = state.copyWith(
        posts: state.posts.where((post) => post.id != postId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleLike({
    required String postId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    try {
      await _facebookService.toggleLike(
        postId: postId,
        businessId: businessId,
        userId: userId,
        token: token,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addReaction({
    required String postId,
    required FacebookReactionType reactionType,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    try {
      await _facebookService.addReaction(
        postId: postId,
        reactionType: reactionType.value,
        businessId: businessId,
        userId: userId,
        token: token,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> commentOnPost({
    required String postId,
    required String message,
    required String businessId,
    String? pageId,
    String? userId,
    String? token,
  }) async {
    try {
      await _facebookService.commentOnPost(
        postId: postId,
        message: message,
        businessId: businessId,
        pageId: pageId,
        userId: userId,
        token: token,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final facebookPostsProvider = StateNotifierProvider<FacebookPostsNotifier, FacebookPostsState>((ref) {
  final facebookService = ref.watch(facebookServiceProvider);
  return FacebookPostsNotifier(facebookService);
});

// Facebook Messages State
class FacebookMessagesState {
  final List<FacebookMessage> messages;
  final String? error;
  final bool isLoading;

  FacebookMessagesState({
    this.messages = const [],
    this.error,
    this.isLoading = false,
  });

  FacebookMessagesState copyWith({
    List<FacebookMessage>? messages,
    String? error,
    bool? isLoading,
  }) {
    return FacebookMessagesState(
      messages: messages ?? this.messages,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Facebook Messages Provider
class FacebookMessagesNotifier extends StateNotifier<FacebookMessagesState> {
  final FacebookService _facebookService;

  FacebookMessagesNotifier(this._facebookService) : super(FacebookMessagesState());

  Future<void> loadConversationMessages({
    required String conversationId,
    required String businessId,
    int? limit,
    String? userId,
    String? token,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final messagesData = await _facebookService.getConversationMessages(
        conversationId: conversationId,
        businessId: businessId,
        limit: limit,
        userId: userId,
        token: token,
      );
      
      final messages = messagesData.map((messageData) => FacebookMessage.fromJson(messageData)).toList();
      state = state.copyWith(
        messages: messages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> sendMessage({
    required String pageId,
    required String recipientId,
    required String message,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    try {
      await _facebookService.sendMessage(
        pageId: pageId,
        recipientId: recipientId,
        message: message,
        businessId: businessId,
        userId: userId,
        token: token,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final facebookMessagesProvider = StateNotifierProvider<FacebookMessagesNotifier, FacebookMessagesState>((ref) {
  final facebookService = ref.watch(facebookServiceProvider);
  return FacebookMessagesNotifier(facebookService);
});

// Facebook Insights Provider
final facebookInsightsProvider = FutureProvider.family<List<FacebookInsights>, Map<String, dynamic>>((ref, params) async {
  final facebookService = ref.watch(facebookServiceProvider);
  
  final result = await facebookService.getPageInsights(
    pageId: params['pageId'] as String,
    businessId: params['businessId'] as String,
    metric: params['metric'] as String?,
    period: params['period'] as String?,
    userId: params['userId'] as String?,
    token: params['token'] as String?,
  );
  
  return (result['data'] as List?)?.map((insightData) => FacebookInsights.fromJson(insightData)).toList() ?? [];
});

// Facebook Page Roles Provider
final facebookPageRolesProvider = FutureProvider.family<List<FacebookPageRole>, Map<String, String>>((ref, params) async {
  final facebookService = ref.watch(facebookServiceProvider);
  
  final rolesData = await facebookService.getPageRoles(
    pageId: params['pageId']!,
    businessId: params['businessId']!,
    userId: params['userId'],
    token: params['token'],
  );
  
  return rolesData.map((roleData) => FacebookPageRole.fromJson(roleData)).toList();
});

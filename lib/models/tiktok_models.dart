class TikTokUser {
  final String openId;
  final String unionId;
  final String? username;
  final String? displayName;
  final String? profilePictureUrl;
  final bool? isVerified;
  final int? followerCount;
  final int? followingCount;
  final int? likesCount;
  final int? videoCount;

  TikTokUser({
    required this.openId,
    required this.unionId,
    this.username,
    this.displayName,
    this.profilePictureUrl,
    this.isVerified,
    this.followerCount,
    this.followingCount,
    this.likesCount,
    this.videoCount,
  });

  factory TikTokUser.fromJson(Map<String, dynamic> json) {
    return TikTokUser(
      openId: json['open_id'] as String,
      unionId: json['union_id'] as String,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      profilePictureUrl: json['avatar_url'] as String?,
      isVerified: json['is_verified'] as bool?,
      followerCount: json['follower_count'] as int?,
      followingCount: json['following_count'] as int?,
      likesCount: json['likes_count'] as int?,
      videoCount: json['video_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'open_id': openId,
      'union_id': unionId,
      'username': username,
      'display_name': displayName,
      'avatar_url': profilePictureUrl,
      'is_verified': isVerified,
      'follower_count': followerCount,
      'following_count': followingCount,
      'likes_count': likesCount,
      'video_count': videoCount,
    };
  }
}

class TikTokVideo {
  final String id;
  final String title;
  final String? description;
  final String coverImageUrl;
  final String shareUrl;
  final String embedLink;
  final int duration;
  final int height;
  final int width;
  final String createTime;
  final String publicationTime;
  final TikTokVideoStatistics? statistics;
  final bool isCommentDisabled;
  final bool isDuetDisabled;
  final bool isStitchDisabled;

  TikTokVideo({
    required this.id,
    required this.title,
    this.description,
    required this.coverImageUrl,
    required this.shareUrl,
    required this.embedLink,
    required this.duration,
    required this.height,
    required this.width,
    required this.createTime,
    required this.publicationTime,
    this.statistics,
    required this.isCommentDisabled,
    required this.isDuetDisabled,
    required this.isStitchDisabled,
  });

  factory TikTokVideo.fromJson(Map<String, dynamic> json) {
    return TikTokVideo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['video_description'] as String?,
      coverImageUrl: json['cover_image_url'] as String,
      shareUrl: json['share_url'] as String,
      embedLink: json['embed_link'] as String,
      duration: json['duration'] as int,
      height: json['height'] as int,
      width: json['width'] as int,
      createTime: json['create_time'] as String,
      publicationTime: json['publication_time'] as String,
      statistics: json['statistics'] != null
          ? TikTokVideoStatistics.fromJson(json['statistics'])
          : null,
      isCommentDisabled: json['is_comment_disabled'] as bool? ?? false,
      isDuetDisabled: json['is_duet_disabled'] as bool? ?? false,
      isStitchDisabled: json['is_stitch_disabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'video_description': description,
      'cover_image_url': coverImageUrl,
      'share_url': shareUrl,
      'embed_link': embedLink,
      'duration': duration,
      'height': height,
      'width': width,
      'create_time': createTime,
      'publication_time': publicationTime,
      'statistics': statistics?.toJson(),
      'is_comment_disabled': isCommentDisabled,
      'is_duet_disabled': isDuetDisabled,
      'is_stitch_disabled': isStitchDisabled,
    };
  }
}

class TikTokVideoStatistics {
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  TikTokVideoStatistics({
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
  });

  factory TikTokVideoStatistics.fromJson(Map<String, dynamic> json) {
    return TikTokVideoStatistics(
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'view_count': viewCount,
      'like_count': likeCount,
      'comment_count': commentCount,
      'share_count': shareCount,
    };
  }
}

class TikTokComment {
  final String id;
  final String text;
  final String createTime;
  final int likeCount;
  final int replyCount;
  final String status;
  final TikTokCommentUser? user;
  final String? parentCommentId;

  TikTokComment({
    required this.id,
    required this.text,
    required this.createTime,
    required this.likeCount,
    required this.replyCount,
    required this.status,
    this.user,
    this.parentCommentId,
  });

  factory TikTokComment.fromJson(Map<String, dynamic> json) {
    return TikTokComment(
      id: json['id'] as String,
      text: json['text'] as String,
      createTime: json['create_time'] as String,
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'published',
      user: json['user'] != null
          ? TikTokCommentUser.fromJson(json['user'])
          : null,
      parentCommentId: json['parent_comment_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'create_time': createTime,
      'like_count': likeCount,
      'reply_count': replyCount,
      'status': status,
      'user': user?.toJson(),
      'parent_comment_id': parentCommentId,
    };
  }
}

class TikTokCommentUser {
  final String displayName;
  final String? avatarUrl;

  TikTokCommentUser({
    required this.displayName,
    this.avatarUrl,
  });

  factory TikTokCommentUser.fromJson(Map<String, dynamic> json) {
    return TikTokCommentUser(
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'avatar_url': avatarUrl,
    };
  }
}

class TikTokAuth {
  final TikTokUser? user;
  final String? accessToken;
  final String? refreshToken;
  final String? scope;
  final DateTime? expiresAt;
  final bool isLoading;
  final String? error;

  TikTokAuth({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.scope,
    this.expiresAt,
    this.isLoading = false,
    this.error,
  });

  TikTokAuth copyWith({
    TikTokUser? user,
    String? accessToken,
    String? refreshToken,
    String? scope,
    DateTime? expiresAt,
    bool? isLoading,
    String? error,
  }) {
    return TikTokAuth(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      scope: scope ?? this.scope,
      expiresAt: expiresAt ?? this.expiresAt,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class TikTokVideosState {
  final List<TikTokVideo> videos;
  final bool isLoading;
  final String? error;
  final String? cursor;
  final bool hasMore;

  TikTokVideosState({
    this.videos = const [],
    this.isLoading = false,
    this.error,
    this.cursor,
    this.hasMore = true,
  });

  TikTokVideosState copyWith({
    List<TikTokVideo>? videos,
    bool? isLoading,
    String? error,
    String? cursor,
    bool? hasMore,
  }) {
    return TikTokVideosState(
      videos: videos ?? this.videos,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class TikTokCommentsState {
  final List<TikTokComment> comments;
  final bool isLoading;
  final String? error;
  final String? cursor;
  final bool hasMore;

  TikTokCommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
    this.cursor,
    this.hasMore = true,
  });

  TikTokCommentsState copyWith({
    List<TikTokComment>? comments,
    bool? isLoading,
    String? error,
    String? cursor,
    bool? hasMore,
  }) {
    return TikTokCommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

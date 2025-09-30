/// YouTube integration models for Seafrika Vendor App
/// Provides data structures for YouTube OAuth flow and channel management

/// YouTube Channel Thumbnails
class YouTubeChannelThumbnails {
  final YouTubeThumbnail? defaultThumbnail;
  final YouTubeThumbnail? medium;
  final YouTubeThumbnail? high;

  YouTubeChannelThumbnails({
    this.defaultThumbnail,
    this.medium,
    this.high,
  });

  factory YouTubeChannelThumbnails.fromJson(Map<String, dynamic> json) {
    return YouTubeChannelThumbnails(
      defaultThumbnail: json['default'] != null
          ? YouTubeThumbnail.fromJson(json['default'])
          : null,
      medium: json['medium'] != null
          ? YouTubeThumbnail.fromJson(json['medium'])
          : null,
      high:
          json['high'] != null ? YouTubeThumbnail.fromJson(json['high']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'default': defaultThumbnail?.toJson(),
      'medium': medium?.toJson(),
      'high': high?.toJson(),
    };
  }
}

/// Individual YouTube Thumbnail
class YouTubeThumbnail {
  final String url;
  final int width;
  final int height;

  YouTubeThumbnail({
    required this.url,
    required this.width,
    required this.height,
  });

  factory YouTubeThumbnail.fromJson(Map<String, dynamic> json) {
    return YouTubeThumbnail(
      url: json['url'] ?? '',
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'width': width,
      'height': height,
    };
  }
}

/// YouTube Channel Information
class YouTubeChannelInfo {
  final String channelId;
  final String title;
  final String description;
  final String? customUrl;
  final DateTime publishedAt;
  final YouTubeChannelThumbnails thumbnails;
  final String? country;
  final int viewCount;
  final int subscriberCount;
  final int videoCount;
  final bool hiddenSubscriberCount;

  YouTubeChannelInfo({
    required this.channelId,
    required this.title,
    required this.description,
    this.customUrl,
    required this.publishedAt,
    required this.thumbnails,
    this.country,
    required this.viewCount,
    required this.subscriberCount,
    required this.videoCount,
    required this.hiddenSubscriberCount,
  });

  factory YouTubeChannelInfo.fromJson(Map<String, dynamic> json) {
    return YouTubeChannelInfo(
      channelId: json['channelId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      customUrl: json['customUrl'],
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'])
          : DateTime.now(),
      thumbnails: YouTubeChannelThumbnails.fromJson(json['thumbnails'] ?? {}),
      country: json['country'],
      viewCount: json['viewCount'] ?? 0,
      subscriberCount: json['subscriberCount'] ?? 0,
      videoCount: json['videoCount'] ?? 0,
      hiddenSubscriberCount: json['hiddenSubscriberCount'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channelId': channelId,
      'title': title,
      'description': description,
      'customUrl': customUrl,
      'publishedAt': publishedAt.toIso8601String(),
      'thumbnails': thumbnails.toJson(),
      'country': country,
      'viewCount': viewCount,
      'subscriberCount': subscriberCount,
      'videoCount': videoCount,
      'hiddenSubscriberCount': hiddenSubscriberCount,
    };
  }

  /// Get the best available thumbnail URL
  String get thumbnailUrl {
    return thumbnails.high?.url ??
        thumbnails.medium?.url ??
        thumbnails.defaultThumbnail?.url ??
        '';
  }

  /// Format subscriber count for display
  String get formattedSubscriberCount {
    if (hiddenSubscriberCount) {
      return 'Hidden';
    }
    return _formatNumber(subscriberCount);
  }

  /// Format video count for display
  String get formattedVideoCount {
    return _formatNumber(videoCount);
  }

  /// Format view count for display
  String get formattedViewCount {
    return _formatNumber(viewCount);
  }

  /// Format large numbers for display (K, M, B)
  String _formatNumber(int number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// Get channel URL
  String get channelUrl {
    if (customUrl != null) {
      return 'https://youtube.com/$customUrl';
    }
    return 'https://youtube.com/channel/$channelId';
  }
}

/// YouTube OAuth Credentials
class YouTubeCredentials {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final String tokenType;
  final List<String> scopes;
  final YouTubeChannelInfo? channelInfo;

  YouTubeCredentials({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    required this.tokenType,
    required this.scopes,
    this.channelInfo,
  });

  factory YouTubeCredentials.fromJson(Map<String, dynamic> json) {
    return YouTubeCredentials(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'],
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : DateTime.now().add(const Duration(hours: 1)),
      tokenType: json['token_type'] ?? 'Bearer',
      scopes: List<String>.from(json['scopes'] ?? []),
      channelInfo: json['userInfo'] != null || json['channel_info'] != null
          ? YouTubeChannelInfo.fromJson(
              json['userInfo'] ?? json['channel_info'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt.toIso8601String(),
      'token_type': tokenType,
      'scopes': scopes,
      'userInfo': channelInfo?.toJson(),
    };
  }

  /// Check if access token is expired
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  /// Check if token expires soon (within 5 minutes)
  bool get expiresSoon {
    return DateTime.now()
        .isAfter(expiresAt.subtract(const Duration(minutes: 5)));
  }
}

/// YouTube Integration Configuration
class YouTubeIntegrationConfig {
  final bool autoSync;
  final int syncInterval;
  final bool syncVideos;
  final bool syncComments;
  final bool syncAnalytics;
  final bool notifyNewComments;
  final bool autoModerateComments;

  YouTubeIntegrationConfig({
    this.autoSync = true,
    this.syncInterval = 3600, // 1 hour
    this.syncVideos = true,
    this.syncComments = true,
    this.syncAnalytics = true,
    this.notifyNewComments = true,
    this.autoModerateComments = false,
  });

  factory YouTubeIntegrationConfig.fromJson(Map<String, dynamic> json) {
    return YouTubeIntegrationConfig(
      autoSync: json['autoSync'] ?? true,
      syncInterval: json['syncInterval'] ?? 3600,
      syncVideos: json['syncVideos'] ?? true,
      syncComments: json['syncComments'] ?? true,
      syncAnalytics: json['syncAnalytics'] ?? true,
      notifyNewComments: json['notifyNewComments'] ?? true,
      autoModerateComments: json['autoModerateComments'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoSync': autoSync,
      'syncInterval': syncInterval,
      'syncVideos': syncVideos,
      'syncComments': syncComments,
      'syncAnalytics': syncAnalytics,
      'notifyNewComments': notifyNewComments,
      'autoModerateComments': autoModerateComments,
    };
  }

  YouTubeIntegrationConfig copyWith({
    bool? autoSync,
    int? syncInterval,
    bool? syncVideos,
    bool? syncComments,
    bool? syncAnalytics,
    bool? notifyNewComments,
    bool? autoModerateComments,
  }) {
    return YouTubeIntegrationConfig(
      autoSync: autoSync ?? this.autoSync,
      syncInterval: syncInterval ?? this.syncInterval,
      syncVideos: syncVideos ?? this.syncVideos,
      syncComments: syncComments ?? this.syncComments,
      syncAnalytics: syncAnalytics ?? this.syncAnalytics,
      notifyNewComments: notifyNewComments ?? this.notifyNewComments,
      autoModerateComments: autoModerateComments ?? this.autoModerateComments,
    );
  }
}

/// YouTube OAuth URL Response
class YouTubeOAuthUrlResponse {
  final String authUrl;
  final String? state;

  YouTubeOAuthUrlResponse({
    required this.authUrl,
    this.state,
  });

  factory YouTubeOAuthUrlResponse.fromJson(Map<String, dynamic> json) {
    return YouTubeOAuthUrlResponse(
      authUrl: json['auth_url'] ?? '',
      state: json['state'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auth_url': authUrl,
      'state': state,
    };
  }
}

/// YouTube Integration Status Response
class YouTubeIntegrationStatus {
  final bool isConnected;
  final YouTubeIntegrationConfig settings;
  final DateTime? lastSyncAt;
  final DateTime? createdAt;
  final String status;
  final YouTubeChannelInfo? channelInfo;

  YouTubeIntegrationStatus({
    required this.isConnected,
    required this.settings,
    this.lastSyncAt,
    this.createdAt,
    required this.status,
    this.channelInfo,
  });

  factory YouTubeIntegrationStatus.fromJson(Map<String, dynamic> json) {
    return YouTubeIntegrationStatus(
      isConnected: json['is_connected'] ?? false,
      settings: YouTubeIntegrationConfig.fromJson(json['settings'] ?? {}),
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.parse(json['last_sync_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      status: json['status'] ?? 'disconnected',
      channelInfo: json['channel_info'] != null
          ? YouTubeChannelInfo.fromJson(json['channel_info'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_connected': isConnected,
      'settings': settings.toJson(),
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'status': status,
      'channel_info': channelInfo?.toJson(),
    };
  }
}

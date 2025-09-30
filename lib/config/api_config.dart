class ApiConfig {
  // Use your deployed backend URL
  static const String baseUrl = 'https://seafrikaapi-u53tcgosiq-uc.a.run.app';

  // API version prefix
  static const String apiVersion = '/api/v1';

  // Base API paths
  static const String authNotificationsPath = '/auth_notifications';
  static const String integrationsBasePath = '/api/integrations';

  // Meta Integration endpoints
  static const String metaConfigBasePath = '/api/config/meta';
  static const String metaAuthPath = '$metaConfigBasePath/auth-url';
  static const String metaOAuthRedirectPath =
      '$metaConfigBasePath/oauth/redirect';

  // Facebook Integration endpoints
  static const String facebookBasePath = '$integrationsBasePath/facebook';
  static const String facebookConfigBasePath = '$apiVersion/config/facebook';

  // Instagram Integration endpoints
  static const String instagramBasePath = '$integrationsBasePath/instagram';
  static const String instagramConfigBasePath =
      '$facebookConfigBasePath/instagram';

  // Messenger Integration endpoints
  static const String messengerBasePath = '$integrationsBasePath/messenger';

  // TikTok Integration endpoints
  static const String tiktokBasePath = '$integrationsBasePath/tiktok';
  static const String tiktokConfigBasePath = '$apiVersion/config/tiktok';
  static const String tiktokAuthPath = '$tiktokConfigBasePath/auth-url';
  static const String tiktokOAuthRedirectPath =
      '$tiktokConfigBasePath/oauth/redirect';

  // YouTube Integration endpoints
  static const String youtubeBasePath = '$integrationsBasePath/youtube';
  static const String youtubeConfigBasePath = '/api/config/youtube';
  static const String youtubeAuthPath = '$youtubeConfigBasePath/auth-url';
  static const String youtubeOAuthRedirectPath =
      '$youtubeConfigBasePath/oauth/redirect';

  // WhatsApp Integration endpoints
  static const String whatsappBasePath = '$integrationsBasePath/whatsapp';

  // Helper methods for building URLs
  static String getFullUrl(String path) => '$baseUrl$path';

  // Meta/Facebook URLs
  static String getMetaAuthUrl() => getFullUrl(metaAuthPath);
  static String getMetaRedirectUrl() => getFullUrl(metaOAuthRedirectPath);

  // Facebook specific URLs
  static String getFacebookAuth() => getFullUrl('$facebookBasePath/auth');
  static String getFacebookUserProfile() =>
      getFullUrl('$facebookBasePath/user/profile');
  static String getFacebookUserPages() =>
      getFullUrl('$facebookBasePath/user/pages');
  static String getFacebookPageSubscribeWebhook(String pageId) =>
      getFullUrl('$facebookBasePath/pages/$pageId/subscribe-webhook');
  static String getFacebookPageRoles(String pageId) =>
      getFullUrl('$facebookBasePath/pages/$pageId/roles');
  static String getFacebookPageInsights(String pageId) =>
      getFullUrl('$facebookBasePath/pages/$pageId/insights');
  static String getFacebookShareTimeline() =>
      getFullUrl('$facebookBasePath/share/timeline');
  static String getFacebookPagePosts(String pageId) =>
      getFullUrl('$facebookBasePath/pages/$pageId/posts');
  static String getFacebookPagePhotos(String pageId) =>
      getFullUrl('$facebookBasePath/pages/$pageId/photos');
  static String getFacebookPageVideos(String pageId) =>
      getFullUrl('$facebookBasePath/pages/$pageId/videos');
  static String getFacebookPost(String postId) =>
      getFullUrl('$facebookBasePath/posts/$postId');
  static String getFacebookPostLike(String postId) =>
      getFullUrl('$facebookBasePath/posts/$postId/like');
  static String getFacebookPostReactions(String postId) =>
      getFullUrl('$facebookBasePath/posts/$postId/reactions');
  static String getFacebookPostComments(String postId) =>
      getFullUrl('$facebookBasePath/posts/$postId/comments');
  static String getFacebookMessagesSend() =>
      getFullUrl('$facebookBasePath/messages/send');
  static String getFacebookConversationMessages(String conversationId) =>
      getFullUrl('$facebookBasePath/conversations/$conversationId/messages');
  static String getFacebookPageInfo(String integrationId) =>
      getFullUrl('$facebookBasePath/$integrationId/page-info');
  static String getFacebookPosts(String integrationId) =>
      getFullUrl('$facebookBasePath/$integrationId/posts');
  static String getFacebookComments(String integrationId) =>
      getFullUrl('$facebookBasePath/$integrationId/comments');
  static String getFacebookMessages(String integrationId) =>
      getFullUrl('$facebookBasePath/$integrationId/messages');
  static String getFacebookInsights(String integrationId) =>
      getFullUrl('$facebookBasePath/$integrationId/insights');
  static String getFacebookCommentReply(
          String integrationId, String commentId) =>
      getFullUrl('$facebookBasePath/$integrationId/comments/$commentId/reply');

  // Instagram specific URLs
  static String getInstagramAuthUrl() =>
      getFullUrl('$instagramConfigBasePath/auth-url');
  static String getInstagramRedirectUrl() =>
      getFullUrl('$instagramConfigBasePath/oauth/redirect');
  static String getInstagramBusinessProfile() =>
      getFullUrl('$instagramConfigBasePath/business-profile');
  static String getInstagramIntegrationLogs() =>
      getFullUrl('$instagramConfigBasePath/integration-logs');

  // Facebook config URLs
  static String getFacebookConfigPageInfo() =>
      getFullUrl('$facebookConfigBasePath/page-info');
  static String getFacebookConfigAuthUrlWithRedirect(
          String redirectUri, String state) =>
      getFullUrl(
          '$instagramConfigBasePath/auth-url?redirect_uri=${Uri.encodeComponent(redirectUri)}&state=${Uri.encodeComponent(state)}');
  static String getFacebookOAuthRedirect() =>
      getFullUrl('$facebookConfigBasePath/oauth/redirect');

  // Messenger specific URLs
  static String getMessengerAnalytics(String integrationId) =>
      getFullUrl('$messengerBasePath/$integrationId/analytics');
  static String getMessengerConversations(String integrationId) =>
      getFullUrl('$messengerBasePath/$integrationId/conversations');

  // TikTok specific URLs
  static String getTikTokAuthUrl() => getFullUrl(tiktokAuthPath);
  static String getTikTokRedirectUrl() => getFullUrl(tiktokOAuthRedirectPath);
  static String getTikTokProfileInfo(String integrationId) =>
      getFullUrl('$tiktokConfigBasePath/$integrationId/profile-info');
  static String getTikTokUserProfile() =>
      getFullUrl('$tiktokConfigBasePath/user/profile');
  static String getTikTokUserInfo() =>
      getFullUrl('$tiktokConfigBasePath/user/info');
  static String getTikTokVideos() => getFullUrl(
      '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/videos');
  static String getTikTokVideo(String videoId) => getFullUrl(
      '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/videos/$videoId');
  static String getTikTokVideoComments(String videoId) => getFullUrl(
      '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/videos/$videoId/comments');
  static String getTikTokCommentReply(String videoId, String commentId) =>
      getFullUrl(
          '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/videos/$videoId/comments/$commentId/reply');
  static String getTikTokVideoAnalytics(String videoId) => getFullUrl(
      '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/videos/$videoId/analytics');
  static String getTikTokUserAnalytics() => getFullUrl(
      '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/analytics/user');
  static String getTikTokIntegrationStatus() =>
      getFullUrl('$tiktokConfigBasePath/integration/status');
  static String getTikTokIntegrationSettings() =>
      getFullUrl('$tiktokConfigBasePath/integration/settings');
  static String getTikTokIntegrationSync() =>
      getFullUrl('$tiktokConfigBasePath/integration/sync');
  static String getTikTokUploadVideo() => getFullUrl(
      '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/upload/video');
  static String getTikTokUploadStatus(String uploadId) => getFullUrl(
      '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/upload/$uploadId/status');
  static String getTikTokInfo() => getFullUrl(
      '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/info');
  static String getTikTokSubscribe() => getFullUrl(
      '${tiktokConfigBasePath.replaceFirst('/config/', '/webhooks/')}/subscribe');
  static String getTikTokIntegrationLogs() =>
      getFullUrl('$tiktokConfigBasePath/integration/logs');

  // YouTube specific URLs
  static String getYouTubeAuthUrl({String? businessId}) {
    final url = getFullUrl(youtubeAuthPath);
    if (businessId != null) {
      return '$url?businessId=$businessId';
    }
    return url;
  }

  static String getYouTubeRedirectUrl() => getFullUrl(youtubeOAuthRedirectPath);
  static String getYouTubeIntegrationStatus() =>
      getFullUrl('$youtubeConfigBasePath/integration/status');
  static String getYouTubeUserInfo() =>
      getFullUrl('$youtubeConfigBasePath/user-info');
  static String getYouTubeIntegrationSettings() =>
      getFullUrl('$youtubeConfigBasePath/integration/settings');
  static String getYouTubeIntegrationDisconnect() =>
      getFullUrl('$youtubeConfigBasePath/integration/disconnect');

  // WhatsApp specific URLs
  static String getWhatsAppBusinessProfile(String integrationId) =>
      getFullUrl('$whatsappBasePath/$integrationId/business-profile');

  // Legacy methods (for backward compatibility)
  @deprecated
  static const String instagramAuthPath = metaAuthPath;
  @deprecated
  static const String instagramOAuthRedirectPath = metaOAuthRedirectPath;
}

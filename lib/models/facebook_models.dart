class FacebookUser {
  final String id;
  final String name;
  final String? email;
  final String? picture;
  final String? locale;

  FacebookUser({
    required this.id,
    required this.name,
    this.email,
    this.picture,
    this.locale,
  });

  factory FacebookUser.fromJson(Map<String, dynamic> json) {
    return FacebookUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      picture: json['picture']?['data']?['url'] as String?,
      locale: json['locale'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'picture': picture,
      'locale': locale,
    };
  }
}

class FacebookPage {
  final String id;
  final String name;
  final String? category; // Made optional to handle null values
  final String? picture;
  final String? about;
  final String? website;
  final String? accessToken; // Made optional since it's not always provided
  final List<String> tasks;
  final int? fanCount;
  final int? followersCount;
  final bool? isPublished;

  FacebookPage({
    required this.id,
    required this.name,
    this.category,
    this.picture,
    this.about,
    this.website,
    this.accessToken,
    required this.tasks,
    this.fanCount,
    this.followersCount,
    this.isPublished,
  });

  factory FacebookPage.fromJson(Map<String, dynamic> json) {
    return FacebookPage(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?, // Allow null category
      picture: json['picture']?['data']?['url'] as String?,
      about: json['about'] as String?,
      website: json['website'] as String?,
      accessToken: json['access_token'] as String?, // Allow null access_token
      tasks: List<String>.from(json['tasks'] ?? []),
      fanCount: json['fan_count'] as int?,
      followersCount: json['followers_count'] as int?,
      isPublished: json['is_published'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'picture': picture,
      'about': about,
      'website': website,
      'access_token': accessToken,
      'tasks': tasks,
      'fan_count': fanCount,
      'followers_count': followersCount,
      'is_published': isPublished,
    };
  }
}

class FacebookPost {
  final String id;
  final String? message;
  final String? story;
  final String createdTime;
  final String? permalink;
  final String? picture;
  final String? fullPicture;
  final FacebookPostStats? stats;
  final List<FacebookComment>? comments;

  FacebookPost({
    required this.id,
    this.message,
    this.story,
    required this.createdTime,
    this.permalink,
    this.picture,
    this.fullPicture,
    this.stats,
    this.comments,
  });

  factory FacebookPost.fromJson(Map<String, dynamic> json) {
    return FacebookPost(
      id: json['id'] as String,
      message: json['message'] as String?,
      story: json['story'] as String?,
      createdTime: json['created_time'] as String,
      permalink: json['permalink_url'] as String?,
      picture: json['picture'] as String?,
      fullPicture: json['full_picture'] as String?,
      stats: json['stats'] != null
          ? FacebookPostStats.fromJson(json['stats'])
          : null,
      comments: json['comments']?['data'] != null
          ? (json['comments']['data'] as List)
              .map((comment) => FacebookComment.fromJson(comment))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'story': story,
      'created_time': createdTime,
      'permalink_url': permalink,
      'picture': picture,
      'full_picture': fullPicture,
      'stats': stats?.toJson(),
      'comments': comments?.map((comment) => comment.toJson()).toList(),
    };
  }
}

class FacebookPostStats {
  final int? likes;
  final int? shares;
  final int? comments;
  final int? reactions;

  FacebookPostStats({
    this.likes,
    this.shares,
    this.comments,
    this.reactions,
  });

  factory FacebookPostStats.fromJson(Map<String, dynamic> json) {
    return FacebookPostStats(
      likes: json['likes'] as int?,
      shares: json['shares'] as int?,
      comments: json['comments'] as int?,
      reactions: json['reactions'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'likes': likes,
      'shares': shares,
      'comments': comments,
      'reactions': reactions,
    };
  }
}

class FacebookComment {
  final String id;
  final String message;
  final String createdTime;
  final FacebookUser from;
  final int? likeCount;

  FacebookComment({
    required this.id,
    required this.message,
    required this.createdTime,
    required this.from,
    this.likeCount,
  });

  factory FacebookComment.fromJson(Map<String, dynamic> json) {
    return FacebookComment(
      id: json['id'] as String,
      message: json['message'] as String,
      createdTime: json['created_time'] as String,
      from: FacebookUser.fromJson(json['from']),
      likeCount: json['like_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'created_time': createdTime,
      'from': from.toJson(),
      'like_count': likeCount,
    };
  }
}

class FacebookMessage {
  final String id;
  final String message;
  final String createdTime;
  final FacebookUser from;
  final FacebookUser? to;
  final List<FacebookAttachment>? attachments;

  FacebookMessage({
    required this.id,
    required this.message,
    required this.createdTime,
    required this.from,
    this.to,
    this.attachments,
  });

  factory FacebookMessage.fromJson(Map<String, dynamic> json) {
    return FacebookMessage(
      id: json['id'] as String,
      message: json['message'] as String,
      createdTime: json['created_time'] as String,
      from: FacebookUser.fromJson(json['from']),
      to: json['to'] != null ? FacebookUser.fromJson(json['to']) : null,
      attachments: json['attachments']?['data'] != null
          ? (json['attachments']['data'] as List)
              .map((attachment) => FacebookAttachment.fromJson(attachment))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'created_time': createdTime,
      'from': from.toJson(),
      'to': to?.toJson(),
      'attachments':
          attachments?.map((attachment) => attachment.toJson()).toList(),
    };
  }
}

class FacebookAttachment {
  final String type;
  final String? imageUrl;
  final String? videoUrl;
  final String? fileUrl;

  FacebookAttachment({
    required this.type,
    this.imageUrl,
    this.videoUrl,
    this.fileUrl,
  });

  factory FacebookAttachment.fromJson(Map<String, dynamic> json) {
    return FacebookAttachment(
      type: json['type'] as String,
      imageUrl: json['image_data']?['url'] as String?,
      videoUrl: json['video_data']?['url'] as String?,
      fileUrl: json['file_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'file_url': fileUrl,
    };
  }
}

class FacebookInsights {
  final String metric;
  final String period;
  final List<FacebookInsightValue> values;
  final String title;
  final String description;

  FacebookInsights({
    required this.metric,
    required this.period,
    required this.values,
    required this.title,
    required this.description,
  });

  factory FacebookInsights.fromJson(Map<String, dynamic> json) {
    return FacebookInsights(
      metric: json['name'] as String,
      period: json['period'] as String,
      values: (json['values'] as List)
          .map((value) => FacebookInsightValue.fromJson(value))
          .toList(),
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': metric,
      'period': period,
      'values': values.map((value) => value.toJson()).toList(),
      'title': title,
      'description': description,
    };
  }
}

class FacebookInsightValue {
  final dynamic value;
  final String? endTime;

  FacebookInsightValue({
    required this.value,
    this.endTime,
  });

  factory FacebookInsightValue.fromJson(Map<String, dynamic> json) {
    return FacebookInsightValue(
      value: json['value'],
      endTime: json['end_time'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'end_time': endTime,
    };
  }
}

class FacebookPageRole {
  final String userId;
  final String name;
  final String role;
  final List<String> tasks;

  FacebookPageRole({
    required this.userId,
    required this.name,
    required this.role,
    required this.tasks,
  });

  factory FacebookPageRole.fromJson(Map<String, dynamic> json) {
    return FacebookPageRole(
      userId: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      tasks: List<String>.from(json['tasks'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': userId,
      'name': name,
      'role': role,
      'tasks': tasks,
    };
  }
}

enum FacebookReactionType {
  like('LIKE'),
  love('LOVE'),
  wow('WOW'),
  haha('HAHA'),
  sad('SAD'),
  angry('ANGRY');

  const FacebookReactionType(this.value);
  final String value;

  static FacebookReactionType fromString(String value) {
    return values.firstWhere(
      (type) => type.value == value.toUpperCase(),
      orElse: () => FacebookReactionType.like,
    );
  }
}

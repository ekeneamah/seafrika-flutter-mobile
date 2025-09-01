import 'package:flutter/foundation.dart';

class Media {
  final String id;
  final String type; // 'image' or 'video'
  final String url;
  final String? thumbnail;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String? productId; // If this media is associated with a product

  Media({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnail,
    required this.timestamp,
    this.metadata,
    this.productId,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'] as String,
      type: json['type'] as String,
      url: json['url'] as String,
      thumbnail: json['thumbnail'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
      productId: json['productId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'url': url,
      'thumbnail': thumbnail,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'productId': productId,
    };
  }

  Media copyWith({
    String? id,
    String? type,
    String? url,
    String? thumbnail,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    String? productId,
  }) {
    return Media(
      id: id ?? this.id,
      type: type ?? this.type,
      url: url ?? this.url,
      thumbnail: thumbnail ?? this.thumbnail,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      productId: productId ?? this.productId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Media &&
        other.id == id &&
        other.type == type &&
        other.url == url &&
        other.thumbnail == thumbnail &&
        other.timestamp == timestamp &&
        mapEquals(other.metadata, metadata) &&
        other.productId == productId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      type,
      url,
      thumbnail,
      timestamp,
      metadata != null ? Object.hashAll(metadata!.entries) : null,
      productId,
    );
  }
} 
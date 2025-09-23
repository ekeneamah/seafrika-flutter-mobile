import { IsString, IsOptional, IsArray, IsNumber, IsBoolean, ValidateNested, IsEnum } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * TikTok Webhook and API DTOs
 * 
 * Comprehensive data transfer objects for TikTok Business API integration
 * following TikTok's webhook and API specifications.
 */

/**
 * TikTok OAuth callback query parameters
 */
export class TikTokOAuthCallbackDto {
  @IsOptional()
  @IsString()
  code?: string;

  @IsOptional()
  @IsString()
  state?: string;

  @IsOptional()
  @IsString()
  redirect_uri?: string;

  @IsOptional()
  @IsString()
  business_id?: string;

  @IsOptional()
  @IsString()
  scopes?: string;

  @IsOptional()
  @IsString()
  error?: string;

  @IsOptional()
  @IsString()
  error_description?: string;
}

/**
 * TikTok webhook event types
 */
export enum TikTokWebhookEventType {
  VIDEO_PUBLISH = 'video_publish',
  VIDEO_DELETE = 'video_delete',
  VIDEO_UPDATE = 'video_update',
  COMMENT_CREATE = 'comment_create',
  COMMENT_DELETE = 'comment_delete',
  COMMENT_UPDATE = 'comment_update',
  USER_FOLLOW = 'user_follow',
  USER_UNFOLLOW = 'user_unfollow',
  LIVE_START = 'live_start',
  LIVE_END = 'live_end',
  ACCOUNT_UPDATE = 'account_update',
}

/**
 * TikTok video data structure
 */
export class TikTokVideoDto {
  @IsString()
  video_id: string;

  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  cover_image_url?: string;

  @IsOptional()
  @IsString()
  video_url?: string;

  @IsOptional()
  @IsString()
  share_url?: string;

  @IsOptional()
  @IsNumber()
  duration?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  hashtags?: string[];

  @IsOptional()
  @IsNumber()
  view_count?: number;

  @IsOptional()
  @IsNumber()
  like_count?: number;

  @IsOptional()
  @IsNumber()
  comment_count?: number;

  @IsOptional()
  @IsNumber()
  share_count?: number;

  @IsOptional()
  @IsNumber()
  create_time?: number;

  @IsOptional()
  @IsNumber()
  update_time?: number;

  @IsOptional()
  @IsBoolean()
  is_private?: boolean;

  @IsOptional()
  @IsString()
  status?: string;
}

/**
 * TikTok comment data structure
 */
export class TikTokCommentDto {
  @IsString()
  comment_id: string;

  @IsString()
  video_id: string;

  @IsString()
  text: string;

  @IsOptional()
  @IsString()
  parent_comment_id?: string;

  @IsOptional()
  @IsNumber()
  like_count?: number;

  @IsOptional()
  @IsNumber()
  reply_count?: number;

  @IsOptional()
  @IsNumber()
  create_time?: number;

  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  commenter?: {
    open_id: string;
    display_name: string;
    username: string;
    avatar_url?: string;
    is_verified?: boolean;
  };
}

/**
 * TikTok user data structure
 */
export class TikTokUserDto {
  @IsString()
  open_id: string;

  @IsOptional()
  @IsString()
  union_id?: string;

  @IsOptional()
  @IsString()
  display_name?: string;

  @IsOptional()
  @IsString()
  username?: string;

  @IsOptional()
  @IsString()
  avatar_url?: string;

  @IsOptional()
  @IsString()
  profile_deep_link?: string;

  @IsOptional()
  @IsBoolean()
  is_verified?: boolean;

  @IsOptional()
  @IsNumber()
  follower_count?: number;

  @IsOptional()
  @IsNumber()
  following_count?: number;

  @IsOptional()
  @IsNumber()
  likes_count?: number;

  @IsOptional()
  @IsNumber()
  video_count?: number;

  @IsOptional()
  @IsString()
  bio_description?: string;

  @IsOptional()
  @IsString()
  profile_type?: string;
}

/**
 * TikTok live stream data structure
 */
export class TikTokLiveStreamDto {
  @IsString()
  live_id: string;

  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  cover_image_url?: string;

  @IsOptional()
  @IsString()
  live_url?: string;

  @IsOptional()
  @IsNumber()
  viewer_count?: number;

  @IsOptional()
  @IsNumber()
  like_count?: number;

  @IsOptional()
  @IsNumber()
  comment_count?: number;

  @IsOptional()
  @IsNumber()
  start_time?: number;

  @IsOptional()
  @IsNumber()
  end_time?: number;

  @IsOptional()
  @IsString()
  status?: string;
}

/**
 * TikTok webhook event data
 */
export class TikTokWebhookEventDto {
  @IsEnum(TikTokWebhookEventType)
  type: TikTokWebhookEventType;

  @IsOptional()
  @IsString()
  event_id?: string;

  @IsOptional()
  @IsNumber()
  timestamp?: number;

  @IsOptional()
  @ValidateNested()
  @Type(() => TikTokVideoDto)
  video?: TikTokVideoDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => TikTokCommentDto)
  comment?: TikTokCommentDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => TikTokUserDto)
  user?: TikTokUserDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => TikTokLiveStreamDto)
  live_stream?: TikTokLiveStreamDto;

  @IsOptional()
  data?: any; // Generic data field for unknown event types
}

/**
 * Main TikTok webhook payload
 */
export class TikTokWebhookDto {
  @IsOptional()
  @IsString()
  webhook_id?: string;

  @IsOptional()
  @IsNumber()
  timestamp?: number;

  @IsOptional()
  @IsString()
  signature?: string;

  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TikTokWebhookEventDto)
  events?: TikTokWebhookEventDto[];
}

/**
 * TikTok API response wrapper
 */
export class TikTokApiResponseDto<T = any> {
  @IsNumber()
  code: number;

  @IsString()
  message: string;

  @IsOptional()
  data?: T;

  @IsOptional()
  @IsString()
  request_id?: string;
}

/**
 * TikTok token response
 */
export class TikTokTokenResponseDto {
  @IsString()
  access_token: string;

  @IsString()
  refresh_token: string;

  @IsNumber()
  expires_in: number;

  @IsNumber()
  refresh_expires_in: number;

  @IsString()
  open_id: string;

  @IsString()
  scope: string;

  @IsOptional()
  @IsString()
  token_type?: string;
}

/**
 * TikTok user info response
 */
export class TikTokUserInfoResponseDto {
  @ValidateNested()
  @Type(() => TikTokUserDto)
  user: TikTokUserDto;
}

/**
 * TikTok video list response
 */
export class TikTokVideoListResponseDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TikTokVideoDto)
  videos: TikTokVideoDto[];

  @IsOptional()
  @IsString()
  cursor?: string;

  @IsOptional()
  @IsBoolean()
  has_more?: boolean;
}

/**
 * TikTok comment list response
 */
export class TikTokCommentListResponseDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TikTokCommentDto)
  comments: TikTokCommentDto[];

  @IsOptional()
  @IsString()
  cursor?: string;

  @IsOptional()
  @IsBoolean()
  has_more?: boolean;
}

/**
 * TikTok analytics data
 */
export class TikTokAnalyticsDto {
  @IsOptional()
  @IsString()
  metric_type?: string;

  @IsOptional()
  @IsString()
  date_range?: string;

  @IsOptional()
  @IsNumber()
  total_views?: number;

  @IsOptional()
  @IsNumber()
  total_likes?: number;

  @IsOptional()
  @IsNumber()
  total_comments?: number;

  @IsOptional()
  @IsNumber()
  total_shares?: number;

  @IsOptional()
  @IsNumber()
  profile_views?: number;

  @IsOptional()
  @IsNumber()
  follower_growth?: number;

  @IsOptional()
  @IsArray()
  daily_metrics?: {
    date: string;
    views: number;
    likes: number;
    comments: number;
    shares: number;
  }[];
}

/**
 * TikTok error response
 */
export class TikTokErrorResponseDto {
  @IsNumber()
  code: number;

  @IsString()
  message: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  request_id?: string;

  @IsOptional()
  @IsString()
  log_id?: string;
}
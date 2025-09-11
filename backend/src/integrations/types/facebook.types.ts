export interface FacebookPage {
  id: string;
  name: string;
  category: string;
  category_list: Array<{
    id: string;
    name: string;
  }>;
  access_token: string;
  about?: string;
  description?: string;
  website?: string;
  phone?: string;
  email?: string;
  location?: {
    street?: string;
    city?: string;
    state?: string;
    country?: string;
    zip?: string;
    latitude?: number;
    longitude?: number;
  };
  cover?: {
    id: string;
    source: string;
  };
  picture?: {
    data: {
      height: number;
      is_silhouette: boolean;
      url: string;
      width: number;
    };
  };
  fan_count?: number;
  followers_count?: number;
  link: string;
  username?: string;
  verification_status?: string;
  is_published?: boolean;
  is_verified?: boolean;
  tasks?: string[];
  instagram_business_account?: {
    id: string;
  };
}

export interface FacebookPost {
  id: string;
  message?: string;
  story?: string;
  created_time: string;
  updated_time?: string;
  type: 'link' | 'status' | 'photo' | 'video' | 'offer';
  status_type?: 'mobile_status_update' | 'created_note' | 'added_photos' | 'added_video' | 'shared_story' | 'created_group' | 'created_event' | 'wall_post' | 'app_created_story' | 'published_story' | 'tagged_in_photo' | 'approved_friend';
  permalink_url: string;
  full_picture?: string;
  picture?: string;
  source?: string;
  description?: string;
  name?: string;
  caption?: string;
  link?: string;
  object_id?: string;
  parent_id?: string;
  place?: {
    id: string;
    name: string;
    location: {
      city?: string;
      country?: string;
      latitude?: number;
      longitude?: number;
      street?: string;
      zip?: string;
    };
  };
  privacy?: {
    value: 'EVERYONE' | 'ALL_FRIENDS' | 'FRIENDS_OF_FRIENDS' | 'CUSTOM' | 'SELF';
    description?: string;
    friends?: 'ALL_FRIENDS' | 'FRIENDS_OF_FRIENDS' | 'SOME_FRIENDS';
    allow?: string;
    deny?: string;
  };
  shares?: {
    count: number;
  };
  reactions?: {
    data: Array<{
      id: string;
      name: string;
      type: 'LIKE' | 'LOVE' | 'WOW' | 'HAHA' | 'SAD' | 'ANGRY' | 'THANKFUL' | 'PRIDE';
    }>;
    summary: {
      total_count: number;
      can_like: boolean;
      has_liked: boolean;
    };
  };
  comments?: {
    data: Array<{
      id: string;
      message: string;
      created_time: string;
      from: {
        id: string;
        name: string;
        picture?: {
          data: {
            url: string;
          };
        };
      };
      like_count: number;
      comment_count: number;
      parent?: {
        id: string;
      };
      attachment?: {
        media?: {
          image?: {
            height: number;
            src: string;
            width: number;
          };
        };
        target?: {
          id: string;
          url: string;
        };
        type: string;
        url: string;
      };
      can_comment: boolean;
      can_remove: boolean;
      can_hide: boolean;
      can_like: boolean;
      can_reply_privately: boolean;
    }>;
    paging?: {
      cursors: {
        before: string;
        after: string;
      };
      next?: string;
      previous?: string;
    };
    summary: {
      order: 'ranked' | 'chronological' | 'reverse_chronological';
      total_count: number;
      can_comment: boolean;
    };
  };
  likes?: {
    data: Array<{
      id: string;
      name: string;
      picture?: {
        data: {
          url: string;
        };
      };
    }>;
    paging?: {
      cursors: {
        before: string;
        after: string;
      };
      next?: string;
    };
    summary: {
      total_count: number;
      can_like: boolean;
      has_liked: boolean;
    };
  };
  insights?: {
    data: Array<{
      name: string;
      period: 'day' | 'week' | 'days_28' | 'month' | 'lifetime';
      values: Array<{
        value: number;
        end_time?: string;
      }>;
      title: string;
      description: string;
      id: string;
    }>;
  };
}

export interface FacebookPageInsights {
  data: Array<{
    name: string;
    period: 'day' | 'week' | 'days_28' | 'month' | 'lifetime';
    values: Array<{
      value: number;
      end_time?: string;
    }>;
    title: string;
    description: string;
    id: string;
  }>;
  paging?: {
    previous?: string;
    next?: string;
  };
}

export interface FacebookComment {
  id: string;
  message: string;
  created_time: string;
  from: {
    id: string;
    name: string;
    picture?: {
      data: {
        url: string;
      };
    };
  };
  like_count: number;
  comment_count: number;
  parent?: {
    id: string;
  };
  attachment?: {
    media?: {
      image?: {
        height: number;
        src: string;
        width: number;
      };
    };
    target?: {
      id: string;
      url: string;
    };
    type: string;
    url: string;
  };
  can_comment: boolean;
  can_remove: boolean;
  can_hide: boolean;
  can_like: boolean;
  can_reply_privately: boolean;
}

export interface FacebookMediaUpload {
  id: string;
  source?: string;
  url?: string;
  published?: boolean;
}

export interface FacebookCredentials {
  access_token: string;
  page_id: string;
  page_access_token: string;
  app_id: string;
  app_secret?: string;
  user_id: string;
  scopes: string[];
  expires_at?: string;
  created_at: string;
}

export interface FacebookIntegrationDocument {
  id?: string;
  businessId: string;
  platformId: 'facebook';
  platformName: 'Facebook Page';
  platformIcon: string;
  status: 'active' | 'inactive' | 'error' | 'pending';
  credentials: FacebookCredentials;
  settings: {
    autoSync: boolean;
    syncInterval: number;
    syncPosts: boolean;
    syncComments: boolean;
    syncMessages: boolean;
    syncInsights: boolean;
    autoResponder: boolean;
    moderateComments: boolean;
    hideOffensiveComments: boolean;
    autoPublish: boolean;
    crossPostToInstagram: boolean;
    businessHours: {
      enabled: boolean;
      timezone: string;
      monday: { start: string; end: string; enabled: boolean };
      tuesday: { start: string; end: string; enabled: boolean };
      wednesday: { start: string; end: string; enabled: boolean };
      thursday: { start: string; end: string; enabled: boolean };
      friday: { start: string; end: string; enabled: boolean };
      saturday: { start: string; end: string; enabled: boolean };
      sunday: { start: string; end: string; enabled: boolean };
    };
    awayMessage: {
      enabled: boolean;
      message: string;
    };
    welcomeMessage: {
      enabled: boolean;
      message: string;
    };
    postScheduling: {
      enabled: boolean;
      optimalTimes: boolean;
    };
  };
  createdAt: string;
  updatedAt?: string;
  errorMessage?: string;
}

export interface FacebookWebhookEntry {
  id: string;
  time: number;
  changes: Array<{
    value: {
      item: 'comment' | 'post' | 'reaction' | 'share' | 'message';
      verb: 'add' | 'edit' | 'delete' | 'hide' | 'unhide' | 'remove';
      post_id?: string;
      comment_id?: string;
      parent_id?: string;
      created_time?: number;
      message?: string;
      from?: {
        id: string;
        name: string;
      };
      post?: {
        id: string;
        type: string;
        created_time: number;
        message?: string;
        link?: string;
        picture?: string;
        video?: string;
        photos?: string[];
        status_type?: string;
        updated_time?: number;
        is_published?: boolean;
        permalink_url?: string;
        promotion_status?: 'not_promoted' | 'pending' | 'approved' | 'rejected' | 'deleted';
      };
      reaction_type?: 'like' | 'love' | 'wow' | 'haha' | 'sad' | 'angry' | 'thankful' | 'pride';
      share?: {
        id: string;
        link: string;
      };
    };
    field: 'feed' | 'mention' | 'name' | 'picture' | 'category' | 'description' | 'general_info' | 'location' | 'phone' | 'website' | 'hours' | 'parking' | 'public_transit' | 'restaurant_services' | 'restaurant_specialties';
  }>;
}

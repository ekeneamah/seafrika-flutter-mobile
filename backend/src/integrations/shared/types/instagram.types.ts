export interface InstagramMediaItem {
  id: string;
  media_type: 'IMAGE' | 'VIDEO' | 'CAROUSEL_ALBUM';
  media_url: string;
  thumbnail_url?: string;
  caption?: string;
  timestamp: string;
  permalink: string;
  like_count?: number;
  comments_count?: number;
}

export interface InstagramMediaResponse {
  data: InstagramMediaItem[];
  paging?: {
    cursors?: {
      after?: string;
      before?: string;
    };
    next?: string;
    previous?: string;
  };
}

export interface IntegrationCredentials {
  access_token: string;
  user_id: string;
  expires_in?: number;
  created_at?: string;
  // New fields for Instagram integration
  ig_user_id?: string;
  facebook_page_id?: string;
  facebook_page_name?: string;
}

export interface IntegrationDocument {
  id: string;
  businessId: string;
  platformId: string;
  status: 'active' | 'inactive' | 'disconnected' | 'error';
  credentials: IntegrationCredentials;
  createdAt: string;
  updatedAt: string;
  platformName?: string;
  platformIcon?: string;
}

export interface InstagramInsightsResponse {
  like_count: number;
  comments_count: number;
  impressions?: number;
  reach?: number;
  saves?: number;
}

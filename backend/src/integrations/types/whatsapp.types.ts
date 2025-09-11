export interface WhatsAppMessage {
  id: string;
  from: string;
  to: string;
  type: 'text' | 'image' | 'document' | 'audio' | 'video' | 'location' | 'contacts' | 'template';
  timestamp: string;
  text?: {
    body: string;
  };
  image?: {
    id: string;
    mime_type: string;
    sha256: string;
    caption?: string;
  };
  document?: {
    id: string;
    filename: string;
    mime_type: string;
    sha256: string;
    caption?: string;
  };
  audio?: {
    id: string;
    mime_type: string;
    sha256: string;
    voice?: boolean;
  };
  video?: {
    id: string;
    mime_type: string;
    sha256: string;
    caption?: string;
  };
  location?: {
    latitude: number;
    longitude: number;
    name?: string;
    address?: string;
  };
  contacts?: Array<{
    name: {
      formatted_name: string;
      first_name?: string;
      last_name?: string;
    };
    phones?: Array<{
      phone: string;
      type?: string;
      wa_id?: string;
    }>;
  }>;
  template?: {
    name: string;
    language: {
      code: string;
    };
    components?: Array<{
      type: 'header' | 'body' | 'footer' | 'button';
      parameters?: Array<{
        type: 'text' | 'currency' | 'date_time' | 'image' | 'document' | 'video';
        text?: string;
        currency?: {
          fallback_value: string;
          code: string;
          amount_1000: number;
        };
        date_time?: {
          fallback_value: string;
        };
        image?: {
          link: string;
        };
        document?: {
          link: string;
          filename: string;
        };
        video?: {
          link: string;
        };
      }>;
    }>;
  };
  context?: {
    message_id: string;
  };
  errors?: Array<{
    code: number;
    title: string;
    message: string;
    error_data: {
      details: string;
    };
  }>;
}

export interface WhatsAppContact {
  wa_id: string;
  profile: {
    name: string;
  };
}

export interface WhatsAppMessageResponse {
  messaging_product: 'whatsapp';
  contacts: WhatsAppContact[];
  messages: Array<{
    id: string;
    message_status?: 'accepted' | 'sent' | 'delivered' | 'read' | 'failed';
  }>;
}

export interface WhatsAppTemplate {
  id: string;
  name: string;
  category: 'AUTHENTICATION' | 'MARKETING' | 'UTILITY';
  status: 'APPROVED' | 'PENDING' | 'REJECTED' | 'DISABLED';
  language: string;
  components: Array<{
    type: 'HEADER' | 'BODY' | 'FOOTER' | 'BUTTONS';
    format?: 'TEXT' | 'IMAGE' | 'DOCUMENT' | 'VIDEO' | 'LOCATION';
    text?: string;
    example?: {
      header_text?: string[];
      body_text?: string[][];
    };
    buttons?: Array<{
      type: 'QUICK_REPLY' | 'URL' | 'PHONE_NUMBER';
      text: string;
      url?: string;
      phone_number?: string;
    }>;
  }>;
}

export interface WhatsAppBusinessProfile {
  messaging_product: 'whatsapp';
  address?: string;
  description?: string;
  email?: string;
  profile_picture_url?: string;
  websites?: string[];
  vertical: 'UNDEFINED' | 'OTHER' | 'AUTO' | 'BEAUTY' | 'APPAREL' | 'EDU' | 'ENTERTAIN' | 'EVENT_PLAN' | 'FINANCE' | 'GROCERY' | 'GOVT' | 'HOTEL' | 'HEALTH' | 'NONPROFIT' | 'PROF_SERVICES' | 'RETAIL' | 'TRAVEL' | 'RESTAURANT';
}

export interface WhatsAppAnalytics {
  messaging_product: 'whatsapp';
  granularity: 'HALF_HOUR' | 'DAY' | 'MONTH';
  data_points: Array<{
    start: number;
    end: number;
    sent: number;
    delivered: number;
    read: number;
    failed: number;
  }>;
}

export interface WhatsAppWebhookEntry {
  id: string;
  changes: Array<{
    value: {
      messaging_product: 'whatsapp';
      metadata: {
        display_phone_number: string;
        phone_number_id: string;
      };
      contacts?: WhatsAppContact[];
      messages?: WhatsAppMessage[];
      statuses?: Array<{
        id: string;
        status: 'sent' | 'delivered' | 'read' | 'failed';
        timestamp: string;
        recipient_id: string;
        conversation?: {
          id: string;
          expiration_timestamp?: string;
          origin: {
            type: 'business_initiated' | 'user_initiated' | 'referral_conversion';
          };
        };
        pricing?: {
          billable: boolean;
          pricing_model: 'CBP';
          category: 'business_initiated' | 'user_initiated' | 'referral_conversion';
        };
        errors?: Array<{
          code: number;
          title: string;
          message: string;
          error_data: {
            details: string;
          };
        }>;
      }>;
      errors?: Array<{
        code: number;
        title: string;
        message: string;
        error_data: {
          details: string;
        };
      }>;
    };
    field: 'messages';
  }>;
}

export interface WhatsAppCredentials {
  access_token: string;
  phone_number_id: string;
  business_account_id: string;
  app_id: string;
  app_secret?: string;
  webhook_verify_token?: string;
  created_at: string;
  expires_at?: string;
}

export interface WhatsAppIntegrationDocument {
  id?: string;
  businessId: string;
  platformId: 'whatsapp';
  platformName: 'WhatsApp Business';
  platformIcon: string;
  status: 'active' | 'inactive' | 'error' | 'pending';
  credentials: WhatsAppCredentials;
  settings: {
    autoSync: boolean;
    syncInterval: number;
    syncMessages: boolean;
    syncContacts: boolean;
    autoResponder: boolean;
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
    templates: {
      orderConfirmation: boolean;
      orderUpdates: boolean;
      promotions: boolean;
      customerSupport: boolean;
    };
  };
  createdAt: string;
  updatedAt?: string;
  errorMessage?: string;
}

import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirestoreService } from '../../firestore/firestore.service';
import axios, { AxiosError } from 'axios';
import * as crypto from 'crypto';

/**
 * Meta Integration Service
 * 
 * Unified service for Facebook Pages, Messenger, and Instagram Business integrations
 * using Meta Graph API v21.0.
 * 
 * Features:
 * - Multi-channel OAuth with least-privilege scopes
 * - Token management and Page access token retrieval
 * - Webhook subscription management
 * - Secure credential storage
 * 
 * Supported Channels:
 * - facebook_pages: Facebook Page management
 * - messenger: Messenger messaging
 * - instagram: Instagram Business account management
 */

export interface MetaChannel {
  id: string;
  name: string;
  scopes: string[];
  webhookFields?: string[];
}

export interface IntegrationCredentials {
  accessToken: string;
  expiresAt?: number;
  scopes: string[];
  userId: string;
  pageInfo?: PageAccessToken; // For Facebook pages
  createdAt: Date;
  updatedAt: Date;
}

export interface PageAccessToken {
  pageId: string;
  pageName: string;
  accessToken: string;
  category: string;
  tasks?: string[];
  instagramBusinessAccount?: {
    id: string;
    username: string;
  };
}

export interface MetaOAuthParams {
  channels: string[];
  redirectUri: string;
  state?: string;
}

@Injectable()
export class MetaService {
  private readonly logger = new Logger(MetaService.name);

  // Meta App Configuration
  private readonly appId = this.configService.get<string>('META_APP_ID');
  private readonly appSecret = this.configService.get<string>('META_APP_SECRET');
  private readonly graphApiVersion = this.configService.get<string>('META_GRAPH_API_VERSION', 'v21.0');
  private readonly baseUrl = `https://graph.facebook.com/${this.graphApiVersion}`;

  // Channel Definitions
  private readonly channels: Record<string, MetaChannel> = {
    facebook_pages: {
      id: 'facebook_pages',
      name: 'Facebook Pages',
      scopes: [
        'pages_show_list',
        'pages_manage_metadata',
        'pages_manage_posts',
        'pages_manage_engagement',
        'pages_read_engagement',
      ],
      webhookFields: ['feed', 'mention'],
    },
    messenger: {
      id: 'messenger',
      name: 'Messenger',
      scopes: [
        'pages_show_list',
        'pages_manage_metadata',
        'pages_messaging',
      ],
      webhookFields: ['messages', 'messaging_postbacks',  'message_deliveries', 'message_reads','message_edits', 'message_mention'],
    },
    instagram: {
      id: 'instagram',
      name: 'Instagram Business',
      scopes: [
        'instagram_basic',
        'instagram_content_publish',
        'instagram_manage_comments',
        'instagram_manage_messages',
        'pages_show_list',
        'pages_manage_metadata',
        'business_management',
      ],
      webhookFields: ['messages'],
    },
  };

  constructor(
    private readonly configService: ConfigService,
    private readonly firestoreService: FirestoreService,
  ) {
    this.validateConfiguration();
  }

  // HMAC(app_secret, access_token) -> hex
public appSecretProof(token: string) {
  return crypto.createHmac('sha256', this.appSecret).update(token).digest('hex');
}

  /**
   * Validate Meta app configuration
   */
  private validateConfiguration(): void {
    if (!this.appId || !this.appSecret) {
      throw new Error('Meta app configuration missing. Please set META_APP_ID and META_APP_SECRET');
    }
    this.logger.log('Meta service initialized with app ID:', this.appId);
  }

  /**
   * Generate OAuth URL for multiple channels with least-privilege scopes
   */
  generateAuthUrl(params: MetaOAuthParams): {
    authUrl: string;
    redirectUri: string;
    channels: string[];
    scopes: string[];
    appId: string;
    instructions: Record<string, string>;
  } {
    const { channels, redirectUri, state } = params;

    // Validate channels
    const invalidChannels = channels.filter(channel => !this.channels[channel]);
    if (invalidChannels.length > 0) {
      throw new BadRequestException(`Invalid channels: ${invalidChannels.join(', ')}`);
    }

    // Build least-privilege scope list
    const scopes = this.buildScopesForChannels(channels);
    
    // Generate random nonce for auth_nonce parameter
    const authNonce = crypto.randomUUID();
    
    // Build OAuth URL with parameters to prevent app interception
    const oauthParams = new URLSearchParams({
      client_id: this.appId,
      redirect_uri: redirectUri,
      scope: scopes.join(','),
      response_type: 'code',
      display: 'popup',         // helps avoid app intercepts
      auth_type: 'reauthenticate', // force reauthentication and show dialog
      auth_nonce: authNonce,    // random nonce to prevent app interception
      return_scopes: 'true',    // return actual granted scopes
      ...(state && { state }),
    });

    const authUrl = `https://www.facebook.com/v21.0/dialog/oauth?${oauthParams.toString()}`;

    // Generate setup instructions
    const instructions = this.generateInstructions(channels);

    this.logger.log(`Generated OAuth URL for channels: ${channels.join(', ')}`);

    return {
      authUrl,
      redirectUri,
      channels,
      scopes,
      appId: this.appId,
      instructions,
    };
  }

  /**
   * Build minimum required scopes for given channels
   */
  private buildScopesForChannels(channels: string[]): string[] {
    const scopeSet = new Set<string>();
    
    channels.forEach(channelId => {
      const channel = this.channels[channelId];
      if (channel) {
        channel.scopes.forEach(scope => scopeSet.add(scope));
      }
    });

    return Array.from(scopeSet);
  }

  /**
   * Generate setup instructions for channels
   */
  private generateInstructions(channels: string[]): Record<string, string> {
    const instructions: Record<string, string> = {};

    if (channels.includes('facebook_pages')) {
      instructions.facebook_pages = 'Grant access to your Facebook Pages for content management';
    }
    
    if (channels.includes('messenger')) {
      instructions.messenger = 'Enable Messenger permissions for customer communication';
    }
    
    if (channels.includes('instagram')) {
      instructions.instagram = 'Connect Instagram Business accounts linked to your Facebook Pages';
    }

    return instructions;
  }

  /**
   * Exchange authorization code for access tokens and retrieve Page access tokens
   */
  async exchangeCodeForTokens(
    code: string,
    redirectUri: string,
    channels: string[],
     expectedState?: string,   // <— add
  receivedState?: string,   
  ): Promise<{
    userAccessToken: string;
    expiresAt: number | undefined;
    scopes: string[];
    userId: string;
    integrations: Array<{
      channel: string;
      platformId: string;
      platformName: string;
      accountInfo: any;
      pageInfo?: PageAccessToken;
    }>;
  }> {
    this.logger.log('Exchanging authorization code for tokens');

    try {
       // 0) CSRF: state check
    
      // Step 1: Exchange code for user access token
      const tokenResponse = await axios.post(
        `${this.baseUrl}/oauth/access_token`,
        new URLSearchParams({
          client_id: this.appId,
          client_secret: this.appSecret,
          redirect_uri: redirectUri,
          code,
        }),
        
        { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
      );
const shortUserToken = tokenResponse.data.access_token as string;
    const shortExpiresIn = tokenResponse.data.expires_in as number | undefined;
    this.logger.log(`User token (short) ${shortUserToken.slice(0, 8)}… expIn=${shortExpiresIn}`);

      // Log complete token response
      this.logger.log('Facebook Token Response:', JSON.stringify(tokenResponse.data, null, 2));

      const { access_token, expires_in } = tokenResponse.data;
     // const expiresAt = expires_in ? Date.now() + (expires_in * 1000) : undefined;

      this.logger.log(`Access Token: ${access_token?.substring(0, 20)}...`);
      this.logger.log(`Expires In: ${expires_in}`);

      // 1b) Exchange -> long-lived user token (~60 days). Recommended.
    const longRes = await axios.get(`${this.baseUrl}/oauth/access_token`, {
      params: {
        grant_type: 'fb_exchange_token',
        client_id: this.appId,
        client_secret: this.appSecret,
        fb_exchange_token: shortUserToken,
      },
      timeout: 15000,
    });

const userAccessToken = (longRes.data.access_token as string) || shortUserToken;
    const userExpiresIn = (longRes.data.expires_in as number | undefined) ?? shortExpiresIn;
    const expiresAt = userExpiresIn ? Date.now() + userExpiresIn * 1000 : undefined;

    const proof = this.appSecretProof(userAccessToken);
      // Step 2: Get user information
       const userResponse = await axios.get(`${this.baseUrl}/me`, {
      params: { fields: 'id,name,email', access_token: userAccessToken, appsecret_proof: proof },
      timeout: 15000,
    });
      const user = userResponse.data;

      // Log user response
      this.logger.log('Facebook User Response:', JSON.stringify(user, null, 2));

      // Step 3: Get granted permissions
        // 3) Granted permissions
    const permissionsResponse = await axios.get(`${this.baseUrl}/me/permissions`, {
      params: { access_token: userAccessToken, appsecret_proof: proof },
      timeout: 15000,
    });
      
      // Log permissions response
      this.logger.log('Facebook Permissions Response:', JSON.stringify(permissionsResponse.data, null, 2));
      
       const grantedScopes: string[] = (permissionsResponse.data?.data ?? [])
      .filter((p: any) => p.status === 'granted')
      .map((p: any) => p.permission);
    this.logger.log(`Granted: ${grantedScopes.join(', ')}`);

      this.logger.log('Granted Scopes:', grantedScopes);

      // Step 4: Fetch Page access tokens
      const pages = await this.fetchPageAccessTokens(access_token);

      // Log pages data
      this.logger.log('Facebook Pages Data:', JSON.stringify(pages, null, 2));

      // Step 5: Determine available integrations based on pages and channels
      const integrations = await this.determineAvailableIntegrations(pages, channels);

      // Log integrations data
      this.logger.log('Generated Integrations:', JSON.stringify(integrations, null, 2));

      this.logger.log(`Successfully exchanged tokens for user ${user.id}, ${pages.length} pages, ${integrations.length} integrations`);

      return { 
        userAccessToken: access_token,
        expiresAt,
        scopes: grantedScopes,
        userId: user.id,
        integrations 
      };
    } catch (error) {
      this.logger.error('Token exchange failed:', error.response?.data || error.message);
      throw new BadRequestException('Failed to exchange authorization code for tokens');
    }
  }

  /**
   * Fetch Page access tokens for all user's pages
   */
  
   
   
      private async fetchPageAccessTokens(userAccessToken: string): Promise<PageAccessToken[]> {
  const proof = this.appSecretProof(userAccessToken);
  const pages: PageAccessToken[] = [];

  // Facebook paginates /me/accounts; follow cursors
  let nextUrl: string | null = `${this.baseUrl}/me/accounts`;

  try {
    while (nextUrl) {
      const res = await axios.get(nextUrl, {
        params: {
          fields: [
            'id',
            'name',
            'access_token',                     // requires pages_manage_metadata
            'category',
            'tasks',                             // useful to check capabilities (CREATE_CONTENT, MODERATE, etc.)
            'instagram_business_account{id,username}'
          ].join(','),
          access_token: userAccessToken,
          appsecret_proof: proof,
          limit: 50,
        },
        timeout: 15000,
      });

      this.logger.log('Facebook Pages Raw Response:', JSON.stringify(res.data, null, 2));

      const batch = (res.data?.data ?? []).map((p: any): PageAccessToken => ({
        pageId: p.id,
        pageName: p.name,
        accessToken: p.access_token,        // may be undefined if permission missing
        category: p.category,
        tasks: p.tasks,
        ...(p.instagram_business_account && {
          instagramBusinessAccount: {
            id: p.instagram_business_account.id,
            username: p.instagram_business_account.username,
          },
        }),
      }));

      pages.push(...batch);

      // Follow pagination if present
      const paging = res.data?.paging;
      nextUrl = paging?.next ?? null;
    }

    // Helpful warnings
    const missingToken = pages.filter(p => !p.accessToken);
    if (missingToken.length) {
      this.logger.warn(
        `Some pages returned without access_token. Ensure user granted pages_manage_metadata. Pages: ${missingToken.map(p => p.pageName).join(', ')}`
      );
    }

    this.logger.log('Processed Pages:', JSON.stringify(pages, null, 2));
    return pages;

  } catch (e) {
    const err = e as AxiosError<any>;
    const fbErr = err.response?.data?.error;
    const code = fbErr?.code;
    const trace = fbErr?.fbtrace_id;
    const msg = fbErr?.message || err.message;

    this.logger.error(`Failed to fetch page access tokens. code=${code} fbtrace_id=${trace} msg=${msg}`);
    return [];
  }
}

    
    

  /*   const response = await axios.get(
      `${this.baseUrl}/me/accounts?fields=id,name,access_token,category,instagram_business_account{id,username}&access_token=${userAccessToken}`
    );

      // Log raw page response from Facebook
      this.logger.log('Facebook Pages Raw Response:', JSON.stringify(response.data, null, 2));

      const processedPages = response.data.data.map((page: any) => ({
        pageId: page.id,
        pageName: page.name,
        accessToken: page.access_token,
        category: page.category,
        ...(page.instagram_business_account && {
          instagramBusinessAccount: {
            id: page.instagram_business_account.id,
            username: page.instagram_business_account.username,
          },
        }),
      }));

      this.logger.log('Processed Pages:', JSON.stringify(processedPages, null, 2));
      
      return processedPages;
    } catch (error) {
      this.logger.error('Failed to fetch page access tokens:', error.response?.data || error.message);
      return [];
    } 
  }*/

  /**
   * Determine available integrations based on pages and requested channels
   */
  private async determineAvailableIntegrations(
    pages: PageAccessToken[],
    channels: string[],
  ): Promise<Array<{
    channel: string;
    platformId: string;
    platformName: string;
    accountInfo: any;
    pageInfo?: PageAccessToken;
  }>> {
    const integrations = [];

    for (const page of pages) {
      // Facebook Pages integration
      if (channels.includes('facebook_pages')) {
        integrations.push({
          channel: 'facebook_pages',
          platformId: page.pageId, // Use actual page ID
          platformName: 'Facebook Pages',
          accountInfo: {
            pageId: page.pageId,
            pageName: page.pageName,
            category: page.category,
          },
          pageInfo: page, // Include page info with access token
        });
      }

      // Messenger integration (requires Facebook Page)
      if (channels.includes('messenger')) {
        integrations.push({
          channel: 'messenger',
          platformId: page.pageId, // Use actual page ID
          platformName: 'Messenger',
          accountInfo: {
            pageId: page.pageId,
            pageName: page.pageName,
          },
          pageInfo: page, // Include page info with access token
        });
      }

      // Instagram Business integration (requires connected Instagram account)
      if (channels.includes('instagram') && page.instagramBusinessAccount) {
        // Fetch comprehensive Instagram Business Account metrics
        let instagramMetrics = {
          followers_count: '--',
          follows_count: '--',
          media_count: '--',
        };

        try {
          const instagramResponse = await fetch(
            `https://graph.facebook.com/v18.0/${page.instagramBusinessAccount.id}?fields=followers_count,follows_count,media_count&access_token=${page.accessToken}`
          );
          
          if (instagramResponse.ok) {
            const instagramData = await instagramResponse.json();
            console.log('Instagram Business Account metrics:', instagramData);
            
            instagramMetrics = {
              followers_count: instagramData.followers_count || '--',
              follows_count: instagramData.follows_count || '--',
              media_count: instagramData.media_count || '--',
            };
          } else {
            console.warn('Failed to fetch Instagram metrics:', await instagramResponse.text());
          }
        } catch (error) {
          console.error('Error fetching Instagram metrics:', error);
        }

        integrations.push({
          channel: 'instagram',
          platformId: page.instagramBusinessAccount.id, // Use actual Instagram account ID
          platformName: 'Instagram Business',
          accountInfo: {
            pageId: page.pageId,
            pageName: page.pageName,
            instagramId: page.instagramBusinessAccount.id,
            instagramUsername: page.instagramBusinessAccount.username,
            ...instagramMetrics, // Include fetched metrics
          },
          pageInfo: page, // Include page info with access token
        });
      }
    }

    return integrations;
  }

  /**
   * Subscribe page to webhook events
   */
  async subscribePageToWebhooks(
    pageAccessToken: string,
    pageId: string,
    callbackUrl: string,
    channels: string[],
  ): Promise<void> {
    try {
      // Determine webhook fields based on channels
      const webhookFields = new Set<string>();
      channels.forEach(channelId => {
        const channel = this.channels[channelId];
        if (channel?.webhookFields) {
          channel.webhookFields.forEach(field => webhookFields.add(field));
        }
      });
     const proof = this.appSecretProof(pageAccessToken);
      if (webhookFields.size === 0) {
        this.logger.warn(`No webhook fields defined for channels: ${channels.join(', ')}`);
        return;
      }

      // Subscribe to webhook
      const response = await axios.post(  
        `${this.baseUrl}/${pageId}/subscribed_apps`,
        new URLSearchParams({
          subscribed_fields: Array.from(webhookFields).join(','),
          access_token: pageAccessToken,
          appsecret_proof: proof,
        }),
        { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
      );

      this.logger.log('Webhook Subscription Response:', Array.from(webhookFields).join(', '));
      if (response.data.success) {
        this.logger.log(`Successfully subscribed page ${pageId} to webhooks: ${Array.from(webhookFields).join(', ')}`);
      } else {
        throw new Error('Webhook subscription failed');
      }

        const verify = await axios.get(`${this.baseUrl}/${pageId}/subscribed_apps`, {
      params: { access_token: pageAccessToken, appsecret_proof: proof },
      timeout: 15000,
    });
    this.logger.log(`Current subscriptions for ${pageId}: ${JSON.stringify(verify.data)}`);
  
    } catch (error) {
      this.logger.error(`Failed to subscribe page ${pageId} to webhooks:`, error.response?.data || error.message);
      throw error;
    }
  }

  /**
   * Store credentials securely in Firestore
   */
  async storeCredentials(
    businessId: string,
    userAccessToken: string,
    expiresAt: number | undefined,
    scopes: string[],
    userId: string,
    integrations: Array<{
      channel: string;
      platformId: string;
      platformName: string;
      accountInfo: any;
      pageInfo?: PageAccessToken; // For Facebook pages with their own tokens
    }>,
  ): Promise<string[]> {
    try {
      this.logger.log('=== STORE CREDENTIALS START ===');
      this.logger.log(`Business ID: ${businessId}`);
      this.logger.log(`User Access Token: ${userAccessToken?.substring(0, 20)}...`);
      this.logger.log(`Expires At: ${expiresAt}`);
      this.logger.log(`Scopes: ${JSON.stringify(scopes)}`);
      this.logger.log(`User ID: ${userId}`);
      this.logger.log(`Integrations Count: ${integrations.length}`);
      
      const integrationIds: string[] = [];
      
      for (const integration of integrations) {
        this.logger.log(`--- Processing Integration: ${integration.channel} ---`);
        this.logger.log(`Platform ID: ${integration.platformId}`);
        this.logger.log(`Platform Name: ${integration.platformName}`);
        this.logger.log(`Has Page Info: ${!!integration.pageInfo}`);
        if (integration.pageInfo) {
          this.logger.log(`Page Info: ${JSON.stringify({
            pageId: integration.pageInfo.pageId,
            pageName: integration.pageInfo.pageName,
            category: integration.pageInfo.category,
            hasAccessToken: !!integration.pageInfo.accessToken,
            hasInstagramAccount: !!integration.pageInfo.instagramBusinessAccount
          })}`);
        }
        
        // Determine the access token for this integration
        let integrationAccessToken = userAccessToken;
        let integrationPageInfo = undefined;
        
        // For Facebook pages and Messenger, use page-specific access token if available
        if ((integration.channel === 'facebook_pages' || integration.channel === 'messenger') && integration.pageInfo) {
          integrationAccessToken = integration.pageInfo.accessToken;
          integrationPageInfo = integration.pageInfo;
          this.logger.log(`Using page-specific access token for ${integration.channel}`);
        } else if (integration.channel === 'instagram' && integration.pageInfo) {
          // For Instagram, we might still want to store the connected page info for reference
          integrationPageInfo = integration.pageInfo;
          // But use user access token for Instagram API calls
          this.logger.log(`Using user access token for Instagram, but storing page info for reference`);
        }
        
        this.logger.log(`Final integrationPageInfo is: ${integrationPageInfo ? 'defined' : 'undefined'}`);

        this.logger.log(`Integration Access Token: ${integrationAccessToken}`);
        
        // Encrypt the access token
        const encryptedAccessToken = this.encryptData(integrationAccessToken);
        
        // Prepare credentials object for this integration
        const integrationCredentials: IntegrationCredentials = {
          accessToken: encryptedAccessToken,
          scopes,
          userId,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
        
        // Only add optional fields if they're defined
        if (expiresAt !== undefined) {
          integrationCredentials.expiresAt = expiresAt;
          this.logger.log(`Adding expiresAt: ${expiresAt}`);
        } else {
          this.logger.log('expiresAt is undefined, skipping');
        }
        
        if (integrationPageInfo !== undefined) {
          integrationCredentials.pageInfo = integrationPageInfo;
          this.logger.log('Adding pageInfo to credentials');
        } else {
          this.logger.log('integrationPageInfo is undefined, skipping');
        }
        
        this.logger.log('Final credentials object structure:', JSON.stringify({
          hasAccessToken: !!integrationCredentials.accessToken,
          hasExpiresAt: integrationCredentials.hasOwnProperty('expiresAt'),
          expiresAtValue: integrationCredentials.expiresAt,
          hasPageInfo: integrationCredentials.hasOwnProperty('pageInfo'),
          pageInfoType: typeof integrationCredentials.pageInfo,
          scopes: integrationCredentials.scopes,
          userId: integrationCredentials.userId,
          createdAt: integrationCredentials.createdAt,
          updatedAt: integrationCredentials.updatedAt
        }, null, 2));

        // Check if integration already exists
        const existingDocs = await this.firestoreService.getDocuments('integrations', [
          { field: 'businessId', operator: '==', value: businessId },
          { field: 'channel', operator: '==', value: integration.channel },
          { field: 'platformId', operator: '==', value: integration.platformId }
        ]);

        let integrationId: string;
        
        if (existingDocs.length > 0) {
          // Update existing integration with new credentials
          integrationId = existingDocs[0].id;
          const existingIntegration = existingDocs[0];
          
          await this.firestoreService.updateDocument('integrations', integrationId, {
            platformName: integration.platformName,
            platformIcon: this.getPlatformIcon(integration.channel),
            accountInfo: integration.accountInfo,
            credentials: integrationCredentials,
            status: 'active',
            // Preserve existing settings, only set defaults if none exist
            settings: existingIntegration.settings || this.getDefaultSettings(integration.channel),
            lastSyncAt: new Date(),
            updatedAt: new Date(),
          });
          this.logger.log(`Updated existing integration ${integrationId} for channel ${integration.channel} with credentials`);
        } else {
          // Create new integration with credentials
          const integrationDoc = await this.firestoreService.createDocument('integrations', {
            businessId,
            platformId: integration.platformId,
            platformName: integration.platformName,
            platformIcon: this.getPlatformIcon(integration.channel),
            channel: integration.channel,
            accountInfo: integration.accountInfo,
            credentials: integrationCredentials,
            status: 'active',
            settings: this.getDefaultSettings(integration.channel),
            connectedAt: new Date(),
            lastSyncAt: new Date(),
            createdAt: new Date(),
            updatedAt: new Date(),
          });
          integrationId = integrationDoc.id;
          this.logger.log(`Created new integration ${integrationId} for channel ${integration.channel} with credentials`);
        }
        
        integrationIds.push(integrationId);
      }

      this.logger.log(`Processed ${integrations.length} integrations with embedded credentials for business ${businessId}`);
      this.logger.log(`Integration IDs: ${integrationIds.join(', ')}`);
      
      return integrationIds;
    } catch (error) {
      this.logger.error('Failed to store integrations with credentials:', error);
      throw error;
    }
  }

  /**
   * Encrypt sensitive data
   */
  private encryptData(data: string): string {
    // Use modern crypto methods
    const algorithm = 'aes-256-cbc';
    const key = crypto.scryptSync(this.appSecret, 'salt', 32);
    const iv = crypto.randomBytes(16);
    
    const cipher = crypto.createCipheriv(algorithm, key, iv);
    let encrypted = cipher.update(data, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    // Prepend IV to encrypted data
    return iv.toString('hex') + ':' + encrypted;
  }

  /**
   * Decrypt sensitive data
   */
  public decryptData(encryptedData: string): string {
    // Split IV and encrypted data
    const parts = encryptedData.split(':');
    if (parts.length !== 2) {
      throw new Error('Invalid encrypted data format');
    }
    
    const algorithm = 'aes-256-cbc';
    const key = crypto.scryptSync(this.appSecret, 'salt', 32);
    const iv = Buffer.from(parts[0], 'hex');
    const encrypted = parts[1];
    
    const decipher = crypto.createDecipheriv(algorithm, key, iv);
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  }

  /**
   * Get credentials for a specific integration
   */
  async getIntegrationCredentials(integrationId: string): Promise<IntegrationCredentials | null> {
    try {
      const integrationDoc = await this.firestoreService.getDocument('integrations', integrationId);
      if (!integrationDoc || !(integrationDoc as any).credentials) return null;

      const credentials = (integrationDoc as any).credentials;
      
      // Decrypt sensitive data
      const decryptedAccessToken = this.decryptData(credentials.accessToken);
      
      return {
        accessToken: decryptedAccessToken,
        expiresAt: credentials.expiresAt,
        scopes: credentials.scopes,
        userId: credentials.userId,
        pageInfo: credentials.pageInfo,
        createdAt: credentials.createdAt,
        updatedAt: credentials.updatedAt,
      };
    } catch (error) {
      this.logger.error('Failed to get integration credentials:', error);
      return null;
    }
  }

  /**
   * Get all integrations with credentials for a business
   */
  async getBusinessIntegrations(businessId: string): Promise<Array<{
    id: string;
    channel: string;
    platformId: string;
    platformName: string;
    accountInfo: any;
    credentials: IntegrationCredentials;
    status: string;
    settings: any;
  }>> {
    try {
      const docs = await this.firestoreService.getDocuments('integrations', [
        { field: 'businessId', operator: '==', value: businessId }
      ]);

      const integrations = [];
      for (const doc of docs) {
        if (doc.credentials) {
          // Decrypt credentials
          const decryptedCredentials = {
            ...doc.credentials,
            accessToken: this.decryptData(doc.credentials.accessToken),
          };

          integrations.push({
            id: doc.id,
            channel: doc.channel,
            platformId: doc.platformId,
            platformName: doc.platformName,
            accountInfo: doc.accountInfo,
            credentials: decryptedCredentials,
            status: doc.status,
            settings: doc.settings,
          });
        }
      }

      return integrations;
    } catch (error) {
      this.logger.error('Failed to get business integrations:', error);
      return [];
    }
  }

  /**
   * Verify webhook signature
   */
  verifyWebhookSignature(payload: string, signature: string): boolean {
    const expectedSignature = crypto
      .createHmac('sha256', this.configService.get('META_WEBHOOK_VERIFY_TOKEN'))
      .update(payload)
      .digest('hex');
    
    const receivedSignature = signature.replace('sha256=', '');
    return crypto.timingSafeEqual(
      Buffer.from(expectedSignature, 'hex'),
      Buffer.from(receivedSignature, 'hex')
    );
  }

  /**
   * Get channel information
   */
  getChannelInfo(channelId: string): MetaChannel | null {
    return this.channels[channelId] || null;
  }

  /**
   * Get all supported channels
   */
  getAllChannels(): MetaChannel[] {
    return Object.values(this.channels);
  }

  /**
   * Get platform icon based on channel
   */
  private getPlatformIcon(channel: string): string {
    const iconMap: Record<string, string> = {
      'facebook_pages': 'assets/icons/facebook.png',
      'messenger': 'assets/icons/messenger.png',
      'instagram': 'assets/icons/instagram.png',
    };
    return iconMap[channel] || 'assets/icons/default.png';
  }

  /**
   * Get default settings for a channel
   */
  private getDefaultSettings(channel: string): Record<string, any> {
    // Base settings that match Flutter IntegrationSettings model
    const baseSettings = {
      autoSync: true,
      syncInterval: 3600, // 1 hour in seconds
      syncInventory: false,
      syncOrders: false,
      syncProducts: false,
      syncReviews: false,
      syncRatings: false,
      autoRespondReviews: false,
      notifyNewReviews: true,
      syncCustomerFeedback: false,
    };

    // Channel-specific settings adjustments
    const channelSettings: Record<string, Partial<typeof baseSettings>> = {
      'facebook_pages': {
        syncProducts: true,
        syncReviews: true,
        syncRatings: true,
        notifyNewReviews: true,
      },
      'messenger': {
        autoRespondReviews: false,
        notifyNewReviews: true,
        syncCustomerFeedback: true,
      },
      'instagram': {
        syncProducts: true,
        syncReviews: true,
        syncRatings: true,
        syncCustomerFeedback: true,
      },
    };
    
    return {
      ...baseSettings,
      ...channelSettings[channel],
    };
  }
}
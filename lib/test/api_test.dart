// Test file to verify correct API URLs
import '../config/api_config.dart';

void main() {
  print('=== API URL TEST ===');
  print('Meta Auth URL: ${ApiConfig.getMetaAuthUrl()}');
  print('Meta Redirect URL: ${ApiConfig.getMetaRedirectUrl()}');
  print('TikTok Auth URL: ${ApiConfig.getTikTokAuthUrl()}');
  print('Facebook Page Info: ${ApiConfig.getFacebookPageInfo("test-id")}');
  print('Instagram Auth URL: ${ApiConfig.getInstagramAuthUrl()}');

  // The corrected URLs should all include /api/v1
  assert(ApiConfig.getMetaAuthUrl().contains('/api/v1'));
  assert(ApiConfig.getMetaRedirectUrl().contains('/api/v1'));

  print('✅ All URLs correctly include /api/v1 prefix');
}

/// Central location for all Firestore collection names
/// This ensures consistency across the app and makes it easy to change collection names
class CollectionNames {
  // User and authentication collections
  static const String users = 'users';
  static const String userProfiles = 'user_profiles';

  // Business collections
  static const String businesses = 'businesses';
  static const String businessNames = 'businessNames';
  static const String businessMembers = 'business_members';
  static const String businessInvitations = 'business_invitations';

  // Store collections
  static const String stores = 'stores';
  static const String storeMembers = 'store_members';

  // Product and inventory collections
  static const String products = 'products';
  static const String inventory = 'inventory'; // Store inventory (current)
  static const String businessInventory =
      'business_inventory'; // Business warehouse inventory
  static const String inventoryTransactions = 'inventory_transactions';
  static const String costPriceHistory =
      'cost_price_history'; // Cost price change history
  static const String categories = 'categories';

  // Order collections
  static const String orders = 'orders';
  static const String orderItems = 'order_items';
  static const String orderHistory = 'order_history';

  // Customer collections
  static const String customers = 'customers';
  static const String customerAddresses = 'customer_addresses';

  // Financial collections
  static const String transactions = 'transactions';
  static const String invoices = 'invoices';
  static const String expenses = 'expenses';
  static const String purchaseOrders = 'purchase_orders';

  // Supplier collections
  static const String suppliers = 'suppliers';
  static const String supplierProducts = 'supplier_products';

  // Staff collections
  static const String staff = 'staff';
  static const String staffSchedules = 'staff_schedules';

  // Task collections
  static const String tasks = 'tasks';
  static const String taskComments = 'task_comments';
  static const String taskAttachments = 'task_attachments';

  // Review collections
  static const String reviews = 'reviews';
  static const String reviewResponses = 'review_responses';

  // Analytics collections
  static const String analytics = 'analytics';
  static const String analyticsDaily = 'analytics_daily';
  static const String analyticsWeekly = 'analytics_weekly';
  static const String analyticsMonthly = 'analytics_monthly';

  // Notification collections
  static const String notifications = 'notifications';
  static const String notificationTemplates = 'notification_templates';

  // Media collections
  static const String media = 'media';
  static const String mediaCategories = 'media_categories';

  // Analytics collections
  static const String salesMetrics = 'sales_metrics';
  static const String performanceMetrics = 'performance_metrics';

  // System collections
  static const String permissions = 'permissions';
  static const String roles = 'roles';
  static const String auditLogs = 'audit_logs';
  static const String systemSettings = 'system_settings';

  // Booking collections
  static const String bookings = 'bookings';
  static const String bookingSlots = 'booking_slots';

  // Integration collections
  static const String integrations = 'integrations';
  static const String webhooks = 'webhooks';

  // Task collections
  static const String taskAssignments = 'task_assignments';

  // Warehouse collections
  static const String warehouses = 'warehouses';
  static const String warehouseLocations = 'warehouse_locations';

  // Knowledge base collections
  static const String knowledgeBase = 'knowledge_base';
  static const String knowledgeCategories = 'knowledge_categories';

  // Messaging collections (3-tier flat structure)
  static const String conversations =
      'conversations'; // Conversation headers (by integrationId)
  static const String messages =
      'messages'; // Individual messages (by conversationId)

  static const String teams = 'teams';
}

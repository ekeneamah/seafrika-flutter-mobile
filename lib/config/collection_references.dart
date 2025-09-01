import 'package:cloud_firestore/cloud_firestore.dart';
import 'collection_names.dart';

/// Collection references and common queries for Firestore collections
class CollectionReferences {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Products Collection References
  static CollectionReference<Map<String, dynamic>> get products => 
      _firestore.collection(CollectionNames.products);

  static Query<Map<String, dynamic>> productsForBusiness(String businessId) => 
      products.where('businessId', isEqualTo: businessId);

  static Query<Map<String, dynamic>> productsForStore(String storeId) => 
      products.where('storeId', isEqualTo: storeId);

  static Query<Map<String, dynamic>> productsForCategory(String businessId, String category) => 
      productsForBusiness(businessId)
          .where('category', isEqualTo: category);

  static Query<Map<String, dynamic>> activeProductsForBusiness(String businessId) => 
      productsForBusiness(businessId)
          .where('status', isEqualTo: 'active');

  static Query<Map<String, dynamic>> lowStockProducts(String businessId) => 
      productsForBusiness(businessId)
          .where('quantity', isLessThanOrEqualTo: 'lowStockThreshold');

  static Query<Map<String, dynamic>> searchProductsByName(String businessId, String searchTerm) => 
      productsForBusiness(businessId)
          .orderBy('name')
          .startAt([searchTerm])
          .endAt([searchTerm + '\uf8ff']);

  // Orders Collection References
  static CollectionReference get orders => 
      _firestore.collection(CollectionNames.orders);

  static Query ordersForBusiness(String businessId) => 
      orders.where('businessId', isEqualTo: businessId);

  static Query ordersForStore(String storeId) => 
      orders.where('storeId', isEqualTo: storeId);

  static Query pendingOrders(String businessId) => 
      ordersForBusiness(businessId)
          .where('status', isEqualTo: 'pending');

  static Query ordersByDateRange(String businessId, DateTime start, DateTime end) => 
      ordersForBusiness(businessId)
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThanOrEqualTo: end);

  // Customers Collection References
  static CollectionReference get customers => 
      _firestore.collection(CollectionNames.customers);

  static Query customersForBusiness(String businessId) => 
      customers.where('businessId', isEqualTo: businessId);

  static Query activeCustomers(String businessId) => 
      customersForBusiness(businessId)
          .where('isActive', isEqualTo: true);

  static Query searchCustomersByName(String businessId, String searchTerm) => 
      customersForBusiness(businessId)
          .orderBy('firstName')
          .startAt([searchTerm])
          .endAt([searchTerm + '\uf8ff']);

  // Inventory Collection References (Store Level)
  static CollectionReference<Map<String, dynamic>> get inventory => 
      _firestore.collection(CollectionNames.inventory);

  static Query<Map<String, dynamic>> inventoryForBusiness(String businessId) => 
      inventory.where('businessId', isEqualTo: businessId);

  static Query<Map<String, dynamic>> inventoryForStore(String businessId, String storeId) => 
      inventory
          .where('businessId', isEqualTo: businessId)
          .where('storeId', isEqualTo: storeId);

  static Query<Map<String, dynamic>> activeInventoryForStore(String businessId, String storeId) => 
      inventoryForStore(businessId, storeId)
          .where('status', isEqualTo: 'active');

  static Query<Map<String, dynamic>> lowStockInventory(String businessId) => 
      inventoryForBusiness(businessId)
          .where('quantity', isLessThanOrEqualTo: 'lowStockThreshold');

  static Query<Map<String, dynamic>> lowStockInventoryForStore(String businessId, String storeId) => 
      inventoryForStore(businessId, storeId)
          .where('quantity', isLessThanOrEqualTo: 'lowStockThreshold');

  static Query<Map<String, dynamic>> searchInventoryByName(String businessId, String storeId, String searchTerm) => 
      inventoryForStore(businessId, storeId)
          .orderBy('productName')
          .startAt([searchTerm])
          .endAt([searchTerm + '\uf8ff']);

  static Query<Map<String, dynamic>> inventoryByCategory(String businessId, String storeId, String category) => 
      inventoryForStore(businessId, storeId)
          .where('category', isEqualTo: category);

  // Business Inventory Collection References (Warehouse)
  static CollectionReference<Map<String, dynamic>> get businessInventory => 
      _firestore.collection(CollectionNames.businessInventory);

  static Query<Map<String, dynamic>> businessInventoryForBusiness(String businessId) => 
      businessInventory.where('businessId', isEqualTo: businessId);

  static Query<Map<String, dynamic>> activeBusinessInventory(String businessId) => 
      businessInventoryForBusiness(businessId)
          .where('status', isEqualTo: 'active');

  static Query<Map<String, dynamic>> lowStockBusinessInventory(String businessId) => 
      businessInventoryForBusiness(businessId)
          .where('availableQuantity', isLessThanOrEqualTo: 10);

  static Query<Map<String, dynamic>> searchBusinessInventoryByName(String businessId, String searchTerm) => 
      businessInventoryForBusiness(businessId)
          .orderBy('productName')
          .startAt([searchTerm])
          .endAt([searchTerm + '\uf8ff']);

  static Query<Map<String, dynamic>> businessInventoryByCategory(String businessId, String category) => 
      businessInventoryForBusiness(businessId)
          .where('category', isEqualTo: category);

  // Cost Price History Collection References
  static CollectionReference<Map<String, dynamic>> get costPriceHistory => 
      _firestore.collection(CollectionNames.costPriceHistory);

  static Query<Map<String, dynamic>> costPriceHistoryForBusiness(String businessId) => 
      costPriceHistory.where('businessId', isEqualTo: businessId);

  static Query<Map<String, dynamic>> costPriceHistoryForItem(String businessInventoryId) => 
      costPriceHistory.where('businessInventoryId', isEqualTo: businessInventoryId);

  static Query<Map<String, dynamic>> activeCostPriceHistory(String businessId) => 
      costPriceHistoryForBusiness(businessId)
          .where('status', isEqualTo: 'active');

  static Query<Map<String, dynamic>> costPriceHistoryByDateRange(String businessId, DateTime start, DateTime end) => 
      costPriceHistoryForBusiness(businessId)
          .where('changedAt', isGreaterThanOrEqualTo: start)
          .where('changedAt', isLessThanOrEqualTo: end);

  // Staff Collection References
  static CollectionReference get staff => 
      _firestore.collection(CollectionNames.staff);

  static Query staffForBusiness(String businessId) => 
      staff.where('businessId', isEqualTo: businessId);

  static Query staffForStore(String storeId) => 
      staff.where('storeIds', arrayContains: storeId);

  static Query activeStaff(String businessId) => 
      staffForBusiness(businessId)
          .where('status', isEqualTo: 'active');

  // Tasks Collection References
  static CollectionReference get tasks => 
      _firestore.collection(CollectionNames.tasks);

  static Query tasksForBusiness(String businessId) => 
      tasks.where('businessId', isEqualTo: businessId);

  static Query tasksForStore(String storeId) => 
      tasks.where('storeId', isEqualTo: storeId);

  static Query tasksForUser(String businessId, String userId) => 
      tasksForBusiness(businessId)
          .where('assignedTo', arrayContains: userId);

  static Query pendingTasks(String businessId) => 
      tasksForBusiness(businessId)
          .where('status', isEqualTo: 'pending');

  // Suppliers Collection References
  static CollectionReference get suppliers => 
      _firestore.collection(CollectionNames.suppliers);

  static Query suppliersForBusiness(String businessId) => 
      suppliers.where('businessId', isEqualTo: businessId);

  static Query activeSuppliers(String businessId) => 
      suppliersForBusiness(businessId)
          .where('status', isEqualTo: 'active');

  // Purchase Orders Collection References
  static CollectionReference get purchaseOrders => 
      _firestore.collection(CollectionNames.purchaseOrders);

  static Query purchaseOrdersForBusiness(String businessId) => 
      purchaseOrders.where('businessId', isEqualTo: businessId);

  static Query purchaseOrdersForSupplier(String businessId, String supplierId) => 
      purchaseOrdersForBusiness(businessId)
          .where('supplierId', isEqualTo: supplierId);

  static Query pendingPurchaseOrders(String businessId) => 
      purchaseOrdersForBusiness(businessId)
          .where('status', isEqualTo: 'pending');

  // Reviews Collection References
  static CollectionReference get reviews => 
      _firestore.collection(CollectionNames.reviews);

  static Query reviewsForBusiness(String businessId) => 
      reviews.where('businessId', isEqualTo: businessId);

  static Query reviewsForProduct(String businessId, String productId) => 
      reviewsForBusiness(businessId)
          .where('productId', isEqualTo: productId);

  static Query pendingReviews(String businessId) => 
      reviewsForBusiness(businessId)
          .where('status', isEqualTo: 'pending');

  // Analytics Collection References
  static CollectionReference get analytics => 
      _firestore.collection(CollectionNames.analytics);

  static Query analyticsForBusiness(String businessId) => 
      analytics.where('businessId', isEqualTo: businessId);

  static Query analyticsForTimeframe(String businessId, String timeframe) => 
      analyticsForBusiness(businessId)
          .where('timeframe', isEqualTo: timeframe);

  static Query analyticsForType(String businessId, String type) => 
      analyticsForBusiness(businessId)
          .where('type', isEqualTo: type);

  // Business Collection References
  static CollectionReference get businesses => 
      _firestore.collection(CollectionNames.businesses);

  static Query businessesForOwner(String ownerId) => 
      businesses.where('ownerId', isEqualTo: ownerId);

  static Query businessesForMember(String userId) => 
      businesses.where('memberIds', arrayContains: userId);

  // Stores Collection References
  static CollectionReference get stores => 
      _firestore.collection(CollectionNames.stores);

  static Query storesForBusiness(String businessId) => 
      stores.where('businessId', isEqualTo: businessId);

  static Query storesForManager(String userId) => 
      stores.where('managerIds', arrayContains: userId);

  static Query activeStores(String businessId) => 
      storesForBusiness(businessId)
          .where('isActive', isEqualTo: true);

  // Teams Collection References
  static CollectionReference get teams => 
      _firestore.collection(CollectionNames.teams);

  static Query teamsForBusiness(String businessId) => 
      teams.where('businessId', isEqualTo: businessId);

  static Query activeTeams(String businessId) => 
      teamsForBusiness(businessId)
          .where('status', isEqualTo: 'active');

  // Booking Collection References
  static CollectionReference get bookings => 
      _firestore.collection(CollectionNames.bookings);

  static Query bookingsForBusiness(String businessId) => 
      bookings.where('businessId', isEqualTo: businessId);

  static Query bookingsForCustomer(String customerId) => 
      bookings.where('customerId', isEqualTo: customerId);

  static Query pendingBookings(String businessId) => 
      bookingsForBusiness(businessId)
          .where('status', isEqualTo: 'pending');

  // Integration Collection References
  static CollectionReference get integrations => 
      _firestore.collection(CollectionNames.integrations);

  static Query integrationsForBusiness(String businessId) => 
      integrations.where('businessId', isEqualTo: businessId);

  static Query integrationsForPlatform(String businessId, String platform) => 
      integrationsForBusiness(businessId)
          .where('platform', isEqualTo: platform);

  static Query activeIntegrations(String businessId) => 
      integrationsForBusiness(businessId)
          .where('isActive', isEqualTo: true);

  static Query activeIntegrationsForPlatform(String businessId, String platform) => 
      integrationsForPlatform(businessId, platform)
          .where('isActive', isEqualTo: true);
}

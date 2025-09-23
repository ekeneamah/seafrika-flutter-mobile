import 'package:flutter/material.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/models/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/providers/service_providers.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static String get currentRoute {
    final currentContext = navigatorKey.currentContext;
    if (currentContext == null) return '/';
    final route = ModalRoute.of(currentContext);
    return route?.settings.name ?? '/';
  }

  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!
        .pushNamed(routeName, arguments: arguments);
  }

  static Future<dynamic> navigateToReplacement(String routeName,
      {Object? arguments}) {
    return navigatorKey.currentState!
        .pushReplacementNamed(routeName, arguments: arguments);
  }

  static Future<dynamic> navigateToAndClearStack(String routeName,
      {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false,
      arguments: arguments,
    );
  }

  static void goBack() {
    return navigatorKey.currentState!.pop();
  }

  // Task Management Navigation Methods
  static Future<dynamic> navigateToTaskList({Object? arguments}) {
    return navigateTo(AppRoutes.taskList, arguments: arguments);
  }

  static Future<dynamic> navigateToCreateTask({
    Task? task,
    String? itemId,
    TaskType? itemType,
    String? title,
    String? description,
  }) {
    if (task != null) {
      return navigateTo(AppRoutes.createTask, arguments: task);
    }

    return navigateTo(AppRoutes.createTask, arguments: {
      'itemId': itemId,
      'itemType': itemType,
      'title': title,
      'description': description,
    });
  }

  static Future<dynamic> navigateToTaskDetail(String taskId) {
    return navigateTo(AppRoutes.taskDetail, arguments: taskId);
  }

  // Product Management Navigation Methods
  static Future<dynamic> navigateToProductList() {
    return navigateTo(AppRoutes.productList);
  }

  static Future<dynamic> navigateToProductDetail(String productId) {
    return navigateTo(AppRoutes.productDetail,
        arguments: {'productId': productId});
  }

  static Future<dynamic> navigateToCreateProduct() {
    return navigateTo(AppRoutes.createProduct);
  }

  static Future<dynamic> navigateToEditProduct(String productId) {
    return navigateTo(AppRoutes.editProduct,
        arguments: {'productId': productId});
  }

  // Order Management Navigation Methods
  static Future<dynamic> navigateToOrderList() {
    return navigateTo(AppRoutes.orders);
  }

  static Future<dynamic> navigateToOrderDetail(String orderId) {
    return navigateTo(AppRoutes.orderDetail, arguments: {'orderId': orderId});
  }

  // Booking Management Navigation Methods
  static Future<dynamic> navigateToCustomerRequests() {
    return navigateTo(AppRoutes.customerRequests);
  }

  static Future<dynamic> navigateToBookingCreation({String? bookingId}) {
    return navigateTo(AppRoutes.bookingCreation,
        arguments: {'bookingId': bookingId});
  }

  static Future<dynamic> navigateToBookingDetail(String bookingId) {
    return navigateTo(AppRoutes.bookingDetail,
        arguments: {'bookingId': bookingId});
  }

  static Future<dynamic> navigateToCreateInvoice({
    String? bookingId,
    String? productId,
    String? customerId,
  }) {
    return navigateTo(AppRoutes.createInvoice, arguments: {
      'bookingId': bookingId,
      'productId': productId,
      'customerId': customerId,
    });
  }

  // Integration Management Navigation Methods
  static Future<dynamic> navigateToIntegrationManagement() {
    return navigateTo(AppRoutes.integrationManagement);
  }

  static Future<dynamic> navigateToAddIntegration() {
    return navigateTo(AppRoutes.addIntegration);
  }

  static Future<dynamic> navigateToIntegrationSettings(String integrationId) {
    return navigateTo(AppRoutes.integrationSettings,
        arguments: {'integrationId': integrationId});
  }

  static Future<dynamic> navigateToFacebookInsights() {
    return navigateTo(AppRoutes.facebookInsights);
  }

  static Future<dynamic> navigateToFacebookPosts(String integrationId) {
    return navigateTo(AppRoutes.facebookPosts,
        arguments: {'integrationId': integrationId});
  }

  static Future<dynamic> navigateToFacebookMessages(String integrationId) {
    return navigateTo(AppRoutes.facebookPosts,
        arguments: {'integrationId': integrationId, 'initialTab': 2});
  }

  // Profile and Settings Navigation Methods
  static Future<dynamic> navigateToProfile() {
    return navigateTo(AppRoutes.profile);
  }

  static Future<dynamic> navigateToSettings() {
    return navigateTo(AppRoutes.settings);
  }

  static Future<dynamic> navigateToHelp() {
    return navigateTo(AppRoutes.help);
  }

  // Review Management
  static Future<dynamic> navigateToReviewPlatforms() {
    return navigateTo(AppRoutes.reviewPlatforms);
  }

  static Future<dynamic> navigateToAddPlatform() {
    return navigateTo(AppRoutes.addPlatform);
  }

  static Future<dynamic> navigateToPlatformSettings(String platformId) {
    return navigateTo(AppRoutes.platformSettings,
        arguments: {'platformId': platformId});
  }

  static Future<dynamic> navigateToReviews({String? productId}) {
    return navigateTo(AppRoutes.reviews,
        arguments: productId == null ? null : {'productId': productId});
  }

  static Future<dynamic> navigateToReviewDetail(String reviewId) {
    return navigateTo(AppRoutes.reviewDetail,
        arguments: {'reviewId': reviewId});
  }

  // Expense Management Navigation Methods
  static Future<dynamic> navigateToExpenseDashboard() {
    return navigateTo(AppRoutes.expenseDashboard);
  }

  static Future<dynamic> navigateToExpenseList() {
    return navigateTo(AppRoutes.expenseList);
  }

  static Future<dynamic> navigateToCreateExpense() {
    return navigateTo(AppRoutes.createExpense);
  }

  static Future<dynamic> navigateToEditExpense(String expenseId) {
    return navigateTo(AppRoutes.editExpense,
        arguments: {'expenseId': expenseId});
  }

  static Future<dynamic> navigateToExpenseDetail(String expenseId) {
    return navigateTo(AppRoutes.expenseDetail,
        arguments: {'expenseId': expenseId});
  }

  static Future<dynamic> navigateToExpenseReports() {
    return navigateTo(AppRoutes.expenseReports);
  }

  // Knowledge Base Navigation Methods
  static Future<dynamic> navigateToKnowledgeBase({String? initialCategory}) {
    return navigateTo(AppRoutes.knowledgeBase,
        arguments: {'initialCategory': initialCategory});
  }

  static Future<dynamic> navigateToCreateArticle() {
    return navigateTo(AppRoutes.createArticle);
  }

  static Future<dynamic> navigateToEditArticle(String articleId) {
    return navigateTo(AppRoutes.editArticle,
        arguments: {'articleId': articleId});
  }

  static Future<dynamic> navigateToArticleDetail(String articleId) {
    return navigateTo(AppRoutes.articleDetail,
        arguments: {'articleId': articleId});
  }

  static Future<dynamic> navigateToArticleCategories() {
    return navigateTo(AppRoutes.articleCategories);
  }

  // Purchase Management Navigation Methods
  static Future<dynamic> navigateToPurchaseOrders() {
    return navigateTo(AppRoutes.purchaseOrders);
  }

  static Future<dynamic> navigateToCreatePurchaseOrder() {
    return navigateTo(AppRoutes.createPurchaseOrder);
  }

  static Future<dynamic> navigateToEditPurchaseOrder(String orderId) {
    return navigateTo(AppRoutes.editPurchaseOrder,
        arguments: {'orderId': orderId});
  }

  static Future<dynamic> navigateToPurchaseOrderDetail(String orderId) {
    return navigateTo(AppRoutes.purchaseOrderDetail,
        arguments: {'orderId': orderId});
  }

  // Supplier Management Navigation Methods
  static Future<dynamic> navigateToSuppliers() {
    return navigateTo(AppRoutes.suppliers);
  }

  static Future<dynamic> navigateToCreateSupplier() {
    return navigateTo(AppRoutes.createSupplier);
  }

  static Future<dynamic> navigateToEditSupplier(String supplierId) {
    return navigateTo(AppRoutes.editSupplier,
        arguments: {'supplierId': supplierId});
  }

  static Future<dynamic> navigateToSupplierDetail(String supplierId) {
    return navigateTo(AppRoutes.supplierDetail,
        arguments: {'supplierId': supplierId});
  }

  static Future<dynamic> navigateToSupplierAnalytics() {
    return navigateTo(AppRoutes.supplierAnalytics);
  }

  // Customer Management Navigation Methods
  static Future<dynamic> navigateToCustomers() {
    return navigateTo(AppRoutes.customers);
  }

  static Future<dynamic> navigateToCreateCustomer() {
    return navigateTo(AppRoutes.createCustomer);
  }

  static Future<dynamic> navigateToEditCustomer(String customerId) {
    return navigateTo(AppRoutes.editCustomer,
        arguments: {'customerId': customerId});
  }

  static Future<dynamic> navigateToCustomerDetail(String customerId) {
    return navigateTo(AppRoutes.customerDetail,
        arguments: {'customerId': customerId});
  }

  static Future<dynamic> navigateToCustomerAnalytics() {
    return navigateTo(AppRoutes.customerAnalytics);
  }

  // Order Management Navigation Methods
  static Future<dynamic> navigateToCreateOrder() {
    return navigateTo(AppRoutes.createOrder);
  }

  static Future<dynamic> navigateToOrderManagement() {
    return navigateTo(AppRoutes.orderManagement);
  }

  // Inventory Management Navigation Methods
  static Future<dynamic> navigateToInventoryDashboard() {
    return navigateTo(AppRoutes.inventoryDashboard);
  }

  static Future<dynamic> navigateToInventoryList() {
    return navigateTo(AppRoutes.inventoryList);
  }

  static Future<dynamic> navigateToCreateInventory({Object? arguments}) {
    return navigateTo(AppRoutes.createInventory, arguments: arguments);
  }

  static Future<dynamic> navigateToEditInventory(String inventoryId) {
    return navigateTo(AppRoutes.editInventory,
        arguments: {'inventoryId': inventoryId});
  }

  static Future<dynamic> navigateToInventoryDetail(String inventoryId) {
    return navigateTo(AppRoutes.inventoryDetail,
        arguments: {'inventoryId': inventoryId});
  }

  static Future<dynamic> navigateToBusinessInventoryDetail(
      String businessInventoryId) {
    return navigateTo(AppRoutes.businessInventoryDetail,
        arguments: {'businessInventoryId': businessInventoryId});
  }

  static Future<dynamic> navigateToBusinessInventoryManagement() {
    return navigateTo(AppRoutes.businessInventoryManagement);
  }

  // Notifications Navigation Methods
  static Future<dynamic> navigateToNotifications() {
    return navigateTo(AppRoutes.notifications);
  }

  static Future<dynamic> navigateToNotificationDetail(String notificationId) {
    return navigateTo(AppRoutes.notificationDetail,
        arguments: {'notificationId': notificationId});
  }

  // Settings Navigation Methods
  static Future<dynamic> navigateToAccountSettings() {
    return navigateTo(AppRoutes.accountSettings);
  }

  static Future<dynamic> navigateToAppPreferences() {
    return navigateTo(AppRoutes.appPreferences);
  }

  static Future<dynamic> navigateToHelpAndSupport() {
    return navigateTo(AppRoutes.helpAndSupport);
  }

  // Invoice Management Navigation Methods
  static Future<dynamic> navigateToInvoiceList() {
    return navigateTo(AppRoutes.invoiceList);
  }

  static Future<dynamic> navigateToInvoiceDetail(String invoiceId) {
    return navigateTo(AppRoutes.invoiceDetail,
        arguments: {'invoiceId': invoiceId});
  }

  static Future<dynamic> navigateToEditInvoice(String invoiceId) {
    return navigateTo(AppRoutes.editInvoice,
        arguments: {'invoiceId': invoiceId});
  }

  // Dashboard Navigation
  static Future<dynamic> navigateToDashboard({Object? arguments}) {
    return navigateTo(AppRoutes.dashboard, arguments: arguments);
  }

  // Inventory Navigation
  static Future<dynamic> navigateToInventory({Object? arguments}) {
    return navigateTo(AppRoutes.inventory, arguments: arguments);
  }

  // Orders Navigation
  static Future<dynamic> navigateToOrders({Object? arguments}) {
    return navigateTo(AppRoutes.orders, arguments: arguments);
  }

  // Customers Navigation
  static Future<dynamic> navigateToCustomersWithArgs({Object? arguments}) {
    return navigateTo(AppRoutes.customers, arguments: arguments);
  }

  // Delivery Navigation
  static Future<dynamic> navigateToDelivery({Object? arguments}) {
    return navigateTo(AppRoutes.delivery, arguments: arguments);
  }

  // Analytics Navigation
  static Future<dynamic> navigateToAnalytics({Object? arguments}) {
    return navigateTo(AppRoutes.analytics, arguments: arguments);
  }

  // Logout
  static Future<void> logout() async {
    // Add logout logic here
    final container = ProviderContainer();
    final authService = container.read(authServiceProvider);
    await authService.logout();
    await navigateToAndClearStack(AppRoutes.login);
  }

  // Admin Panel Navigation Method
  static Future<dynamic> navigateToAdminPanel({Object? arguments}) {
    return navigateTo(AppRoutes.adminPanel, arguments: arguments);
  }

  // New method
  static Future<dynamic> navigateToStaffNavigation() {
    return navigateToReplacement(AppRoutes.staffNavigation);
  }
}

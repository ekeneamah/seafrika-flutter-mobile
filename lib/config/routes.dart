import 'package:flutter/material.dart';
import 'package:vendor_app/models/SelectBusinessInfo.dart';
import 'package:vendor_app/models/team.dart';
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/screens/Dashboard.dart';
import 'package:vendor_app/screens/admin/admin_panel_screen.dart';
import 'package:vendor_app/screens/admin/role_management_screen.dart';
import 'package:vendor_app/screens/auth/staff_registration_screen.dart';
import 'package:vendor_app/screens/admin/teams_screen.dart';
import 'package:vendor_app/screens/admin/user_management_screen.dart';
import 'package:vendor_app/screens/auth/BusinessSelectionScreen.dart';
import 'package:vendor_app/screens/auth/signup_screen.dart';
import 'package:vendor_app/screens/main/staff_navigation_screen.dart';
import 'package:vendor_app/screens/products/product_detail_screen.dart' as pd;
import 'package:vendor_app/screens/profile/profile_screen.dart';
import 'package:vendor_app/screens/help/help_screen.dart';
import 'package:vendor_app/screens/onboarding/onboarding_screen.dart';
import 'package:vendor_app/screens/settings/settings_screen.dart';
import 'package:vendor_app/screens/auth/login_screen.dart';
import 'package:vendor_app/screens/auth/forgot_password_screen.dart';
import 'package:vendor_app/screens/products/create_product_screen.dart';
import 'package:vendor_app/screens/orders/order_list_screen.dart';
import 'package:vendor_app/screens/orders/order_detail_screen.dart';
import 'package:vendor_app/screens/main/media_detail_screen.dart';
import 'package:vendor_app/screens/bookings/customer_requests_screen.dart';
import 'package:vendor_app/screens/bookings/booking_creation_screen.dart';
import 'package:vendor_app/screens/bookings/booking_detail_screen.dart';
import 'package:vendor_app/screens/invoices/create_invoice_screen.dart';
import 'package:vendor_app/screens/integrations/integration_management_screen.dart';
import 'package:vendor_app/screens/integrations/add_integration_screen.dart';
import 'package:vendor_app/screens/integrations/integration_settings_screen.dart';
import 'package:vendor_app/screens/tasks/task_list_screen.dart';
import 'package:vendor_app/screens/tasks/create_task_screen.dart';
import 'package:vendor_app/screens/tasks/task_detail_screen.dart';
import 'package:vendor_app/screens/reviews/review_platforms_screen.dart';
import 'package:vendor_app/screens/reviews/add_platform_screen.dart';
import 'package:vendor_app/screens/reviews/platform_settings_screen.dart';
import 'package:vendor_app/screens/reviews/reviews_screen.dart';
import 'package:vendor_app/screens/reviews/review_detail_screen.dart';
import 'package:vendor_app/screens/expenses/expense_dashboard_screen.dart';
import 'package:vendor_app/screens/expenses/expense_list_screen.dart';
import 'package:vendor_app/screens/expenses/create_expense_screen.dart';
import 'package:vendor_app/screens/expenses/expense_detail_screen.dart';
import 'package:vendor_app/screens/knowledge_base/knowledge_base_screen.dart';
import 'package:vendor_app/screens/knowledge_base/create_article_screen.dart';
import 'package:vendor_app/screens/knowledge_base/article_detail_screen.dart';
import 'package:vendor_app/screens/knowledge_base/article_categories_screen.dart';
import 'package:vendor_app/screens/purchase_orders/purchase_orders_screen.dart';
import 'package:vendor_app/screens/purchase_orders/create_purchase_order_screen.dart';
import 'package:vendor_app/screens/purchase_orders/purchase_order_detail_screen.dart';
import 'package:vendor_app/screens/suppliers/suppliers_screen.dart';
import 'package:vendor_app/screens/suppliers/create_supplier_screen.dart';
import 'package:vendor_app/screens/suppliers/supplier_detail_screen.dart';
import 'package:vendor_app/screens/suppliers/supplier_analytics_screen.dart';
import 'package:vendor_app/screens/customers/customers_screen.dart';
import 'package:vendor_app/screens/customers/create_customer_screen.dart';
import 'package:vendor_app/screens/customers/customer_detail_screen.dart';
import 'package:vendor_app/screens/customers/customer_analytics_screen.dart';
import 'package:vendor_app/screens/inventory/inventory_dashboard_screen.dart';
import 'package:vendor_app/screens/inventory/inventory_list_screen.dart';
import 'package:vendor_app/screens/inventory/create_inventory_screen.dart';
import 'package:vendor_app/screens/inventory/inventory_detail_screen.dart';
import 'package:vendor_app/screens/notifications/notifications_screen.dart';
import 'package:vendor_app/screens/notifications/notification_detail_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:vendor_app/models/booking_request.dart';
import 'package:vendor_app/screens/main/main_screen.dart';
import 'package:vendor_app/screens/invoices/invoice_list_screen.dart';
import 'package:vendor_app/screens/invoices/invoice_detail_screen.dart';
import 'package:vendor_app/models/task.dart';
import 'package:vendor_app/screens/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/screens/admin/permissions_screen.dart';
import 'package:vendor_app/screens/profile/user_profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String inventory = '/inventory';
  static const String orders = '/orders';
  static const String delivery = '/delivery';
  static const String analytics = '/analytics';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String help = '/help';
  static const String productList = '/products';
  static const String productDetail = '/products/detail';
  static const String orderList = '/orders';
  static const String orderDetail = '/orders/detail';
  static const String mediaDetail = '/media-detail';
  static const String createProduct = '/create-product';
  static const String editProduct = '/edit-product';
  static const String customerRequests = '/bookings/requests';
  static const String bookingCreation = '/bookings/create';
  static const String bookingDetail = '/bookings/detail';
  static const String editBooking = '/bookings/edit';
  static const String createInvoice = '/bookings/invoice/create';
  static const String integrationManagement = '/integrations';
  static const String addIntegration = '/integrations/add';
  static const String integrationSettings = '/integrations/settings';
  static const String taskList = '/tasks';
  static const String createTask = '/create-task';
  static const String taskDetail = '/task-detail';
  static const String reviewPlatforms = '/reviews/platforms';
  static const String addPlatform = '/reviews/platforms/add';
  static const String platformSettings = '/reviews/platforms/settings';
  static const String reviews = '/reviews';
  static const String reviewDetail = '/reviews/detail';
  static const String expenseDashboard = '/expenses/dashboard';
  static const String expenseList = '/expenses/list';
  static const String createExpense = '/expenses/create';
  static const String editExpense = '/expenses/edit';
  static const String expenseDetail = '/expenses/detail';
  static const String expenseReports = '/expenses/reports';
  static const String knowledgeBase = '/knowledge-base';
  static const String createArticle = '/knowledge-base/create';
  static const String editArticle = '/knowledge-base/edit';
  static const String articleDetail = '/knowledge-base/detail';
  static const String articleCategories = '/knowledge-base/categories';
  static const String purchaseOrders = '/purchase-orders';
  static const String createPurchaseOrder = '/purchase-orders/create';
  static const String editPurchaseOrder = '/purchase-orders/edit';
  static const String purchaseOrderDetail = '/purchase-orders/detail';
  static const String suppliers = '/suppliers';
  static const String createSupplier = '/suppliers/create';
  static const String editSupplier = '/suppliers/edit';
  static const String supplierDetail = '/suppliers/detail';
  static const String supplierAnalytics = '/suppliers/analytics';
  static const String customers = '/customers';
  static const String createCustomer = '/customers/create';
  static const String editCustomer = '/customers/edit';
  static const String customerDetail = '/customers/detail';
  static const String customerAnalytics = '/customers/analytics';
  static const String inventoryDashboard = '/inventory/dashboard';
  static const String inventoryList = '/inventory/list';
  static const String createInventory = '/inventory/create';
  static const String editInventory = '/inventory/edit';
  static const String inventoryDetail = '/inventory/detail';
  static const String notifications = '/notifications';
  static const String notificationDetail = '/notifications/detail';
  static const String accountSettings = '/settings/account';
  static const String appPreferences = '/settings/preferences';
  static const String helpAndSupport = '/settings/help';
  static const String invoiceList = '/invoices';
  static const String editInvoice = '/invoices/edit';
  static const String invoiceDetail = '/invoices/detail';
  static const String permissions = '/admin/permissions';
  static const String roleManagement = '/admin/roles';
  static const String userManagement = '/admin/users';
  static const String permissionsManagement = '/admin/permissions';
  static const String teamManagement = '/admin/teams';
  static const String storeManagement = '/admin/stores';
  static const String adminPanel = '/admin/panel';
  static const String selectBusiness = '/select-business';
  static const String staffNavigation = '/staff-navigation';
  static const String userProfile = '/user-profile';
  static const String staffRegistration = '/staff-registration';



  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
        case staffRegistration:
  final args = settings.arguments as Map<String, dynamic>?;
  return MaterialPageRoute(
    builder: (_) => StaffRegistrationScreen(
      businessId: args?['businessId'],
      email: args?['email'],
    ),
  );
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case help:
        return MaterialPageRoute(builder: (_) => const HelpScreen());
      case productList:
        return MaterialPageRoute(
          builder: (_) => const MainScreen(initialTab: 1),
        );
      case productDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => pd.ProductDetailScreen(
            productId: args['productId'],
            storeId: args['storeId'],
          ),
        );
      case orderList:
        return MaterialPageRoute(builder: (_) => const OrderListScreen());
      case orderDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: args['orderId']),
        );
      case mediaDetail:
        final args = settings.arguments as Map<String, dynamic>;
        final media = args['media'] as AssetEntity;
        return MaterialPageRoute(
          builder: (context) => MediaDetailScreen(media: media),
        );
      case createProduct:
        final args = settings.arguments as Map<String, dynamic>?;
        final media = args?['media'] as AssetEntity?;
        return MaterialPageRoute(
          builder: (context) => CreateProductScreen(initialMedia: media),
        );
      case editProduct:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => CreateProductScreen(
            productId: args['productId'],
            initialMedia: args['media'] as AssetEntity?,
          ),
        );
      case customerRequests:
        return MaterialPageRoute(
          builder: (context) => const CustomerRequestsScreen(),
        );
      case bookingCreation:
        final args = settings.arguments as Map<String, dynamic>?;
        final request = args?['request'] as BookingRequest?;
        return MaterialPageRoute(
          builder: (context) => BookingCreationScreen(request: request),
        );
      case bookingDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => BookingDetailScreen(
            bookingId: args['bookingId'],
          ),
        );
      case editBooking:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => BookingCreationScreen(
            request: args['request'],
            isDraft: args['isDraft'] ?? false,
          ),
        );
      case createInvoice:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => CreateInvoiceScreen(
            bookingId: args['bookingId'],
          ),
        );
      case integrationManagement:
        return MaterialPageRoute(
          builder: (context) => const IntegrationManagementScreen(),
        );
      case addIntegration:
        return MaterialPageRoute(
          builder: (context) => const AddIntegrationScreen(),
        );
      case integrationSettings:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => IntegrationSettingsScreen(
            integrationId: args['integrationId'],
          ),
        );
      case taskList:
        return MaterialPageRoute(
          builder: (_) => const TaskListScreen(),
        );
      case createTask:
        final args = settings.arguments;
        if (args is Task) {
          return MaterialPageRoute(
            builder: (_) => CreateTaskScreen(task: args),
          );
        } else if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => CreateTaskScreen(arguments: args),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const CreateTaskScreen(),
        );
      case taskDetail:
        final taskId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: taskId),
        );
      case reviewPlatforms:
        return MaterialPageRoute(
          builder: (context) => const ReviewPlatformsScreen(),
        );
      case addPlatform:
        return MaterialPageRoute(
          builder: (context) => const AddPlatformScreen(),
        );
      case platformSettings:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => PlatformSettingsScreen(
            platformId: args['platformId'],
          ),
        );
      case reviews:
        return MaterialPageRoute(
          builder: (context) => const ReviewsScreen(),
        );
      case reviewDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => ReviewDetailScreen(
            reviewId: args['reviewId'],
          ),
        );
      case expenseDashboard:
        return MaterialPageRoute(
          builder: (_) => const ExpenseDashboardScreen(),
        );
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        );
      case expenseList:
        return MaterialPageRoute(
          builder: (_) => const ExpenseListScreen(),
        );
      case createExpense:
        return MaterialPageRoute(
          builder: (_) => const CreateExpenseScreen(),
        );
      case editExpense:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => CreateExpenseScreen(
            expenseId: args['expenseId'],
          ),
        );
      case expenseDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ExpenseDetailScreen(
            expenseId: args['expenseId'],
          ),
        );
      case expenseReports:
        return MaterialPageRoute(
          builder: (_) => const ExpenseDashboardScreen(),
        );
      case knowledgeBase:
        return MaterialPageRoute(
          builder: (_) => const KnowledgeBaseScreen(),
        );
      case createArticle:
        return MaterialPageRoute(
          builder: (_) => const CreateArticleScreen(),
        );
      case editArticle:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => CreateArticleScreen(
            articleId: args['articleId'],
          ),
        );
      case articleDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ArticleDetailScreen(
            articleId: args['articleId'],
          ),
        );
      case articleCategories:
        return MaterialPageRoute(
          builder: (_) => const ArticleCategoriesScreen(),
        );
      case purchaseOrders:
        return MaterialPageRoute(
          builder: (context) => const PurchaseOrdersScreen(),
        );
      case createPurchaseOrder:
        return MaterialPageRoute(
          builder: (context) => const CreatePurchaseOrderScreen(),
        );
      case editPurchaseOrder:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => CreatePurchaseOrderScreen(
            orderId: args['orderId'],
          ),
        );
      case purchaseOrderDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => PurchaseOrderDetailScreen(
            orderId: args['orderId'],
          ),
        );
      case suppliers:
        return MaterialPageRoute(
          builder: (context) => const SuppliersScreen(),
        );
      case createSupplier:
        return MaterialPageRoute(
          builder: (context) => const CreateSupplierScreen(),
        );
      case editSupplier:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => CreateSupplierScreen(
            supplierId: args['supplierId'],
          ),
        );
      case supplierDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => SupplierDetailScreen(
            supplierId: args['supplierId'],
          ),
        );
      case supplierAnalytics:
        return MaterialPageRoute(
          builder: (context) => const SupplierAnalyticsScreen(),
        );
      case customers:
        return MaterialPageRoute(
          builder: (context) => const CustomersScreen(),
        );
      case createCustomer:
        return MaterialPageRoute(
          builder: (context) => const CreateCustomerScreen(),
        );
      case editCustomer:
        final customerId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (context) => CreateCustomerScreen(customerId: customerId),
        );
      case customerDetail:
        final customerId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (context) => CustomerDetailScreen(customerId: customerId),
        );
      case customerAnalytics:
        return MaterialPageRoute(
          builder: (context) => const CustomerAnalyticsScreen(),
        );
      case inventoryDashboard:
        return MaterialPageRoute(
          builder: (context) => const InventoryDashboardScreen(),
        );
      case inventoryList:
        final args = settings.arguments as Map<String, dynamic>?;
        final storeId = args != null ? args['storeId'] as String? : null;
        return MaterialPageRoute(
          builder: (context) => InventoryListScreen(storeId: storeId),
        );
      case createInventory:
        return MaterialPageRoute(
          builder: (context) => const CreateInventoryScreen(),
        );
      case editInventory:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => CreateInventoryScreen(
            inventory: args['inventory'],
          ),
        );
      case inventoryDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => Consumer(
            builder: (context, ref, child) => InventoryDetailScreen(
              inventoryId: args['inventoryId'],
            ),
          ),
        );
      case notifications:
        return MaterialPageRoute(
          builder: (context) => const NotificationsScreen(),
        );
      case notificationDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => NotificationDetailScreen(
            notificationId: args['notificationId'],
          ),
        );
      case accountSettings:
      case appPreferences:
      case helpAndSupport:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case invoiceList:
        return MaterialPageRoute(
          builder: (context) => const InvoiceListScreen(),
        );
      case editInvoice:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => CreateInvoiceScreen(
            bookingId: args['bookingId'],
            productId: args['productId'],
            customerId: args['customerId'],
          ),
        );
      case invoiceDetail:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => InvoiceDetailScreen(
            invoiceId: args['invoiceId'],
          ),
        );
      case permissions:
        return MaterialPageRoute(
          builder: (_) => const PermissionsScreen(),
        );
      case roleManagement:
        return MaterialPageRoute(
          builder: (_) => const RoleManagementScreen(),
        );
      case userManagement:
        return MaterialPageRoute(
          builder: (_) => const UserManagementScreen(),
        );
      case permissionsManagement:
        return MaterialPageRoute(
          builder: (_) => const PermissionsScreen(),
        );
      case teamManagement:
        return MaterialPageRoute(
          builder: (_) => const TeamsScreen(),
        );
      case storeManagement:
        return MaterialPageRoute(
          builder: (_) => const PermissionsScreen(),
        );
      case adminPanel:
        return MaterialPageRoute(
          builder: (_) => const AdminPanelScreen(),
        );
      case AppRoutes.selectBusiness:
        final businesses = settings.arguments as List<BusinessInfo>;
        return MaterialPageRoute(
          builder: (_) => BusinessSelectionScreen(businesses: businesses),
        );
      case staffNavigation:
        return MaterialPageRoute(builder: (_) => const StaffNavigationScreen());
      case userProfile:
        final user = settings.arguments as User?;
        return MaterialPageRoute(
          builder: (_) => UserProfileScreen(user: user),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:vendor_app/services/firestore_service.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/services/product_service.dart';
import 'package:vendor_app/services/media_service.dart';
import 'package:vendor_app/services/analytics_service.dart';

class ServiceLocator {
  static List<SingleChildWidget> get providers => [
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
        ChangeNotifierProxyProvider<FirestoreService, ProductService>(
          create: (context) =>
              ProductService(firestore: context.read<FirestoreService>()),
          update: (context, firestore, previous) =>
              previous ?? ProductService(firestore: firestore),
        ),
        ChangeNotifierProxyProvider<FirestoreService, MediaService>(
          create: (context) =>
              MediaService(firestore: context.read<FirestoreService>()),
          update: (context, firestore, previous) =>
              previous ?? MediaService(firestore: firestore),
        ),
      ];
}

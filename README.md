# Vendor App

A comprehensive multi-vendor e-commerce marketplace mobile application built with Flutter.

## Features

- **Authentication**
  - Sign up and login
  - Password recovery
  - Account management

- **Media Management**
  - Gallery view of device photos and videos
  - Quick product creation from media
  - Media organization and filtering

- **Store Management**
  - Product listing and management
  - Inventory tracking
  - Order management
  - Customer management

- **Analytics**
  - Sales analytics
  - Order analytics
  - Customer analytics
  - Performance metrics

- **Additional Features**
  - Social media integration
  - Review management
  - Task management
  - Expense tracking
  - Knowledge base
  - Supplier management

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / VS Code
- Android SDK / Xcode (for iOS development)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/vendor_app.git
   ```

2. Navigate to the project directory:
   ```bash
   cd vendor_app
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── config/
│   └── theme.dart
├── models/
│   ├── product.dart
│   ├── order.dart
│   └── user.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   └── main/
│       ├── media_screen.dart
│       ├── store_screen.dart
│       └── analytics_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── product_service.dart
│   └── analytics_service.dart
├── widgets/
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   └── analytics_card.dart
└── main.dart
```

## Dependencies

- **provider**: State management
- **fl_chart**: Charts and graphs
- **intl**: Internationalization
- **image_picker**: Media selection
- **shared_preferences**: Local storage
- **http**: API communication
- **url_launcher**: External links
- **share_plus**: Content sharing
- **path_provider**: File system access
- **permission_handler**: Device permissions
- **cached_network_image**: Image caching
- **flutter_svg**: SVG support
- **shimmer**: Loading effects

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- All contributors who have helped shape this project
- The open-source community for their valuable packages and tools

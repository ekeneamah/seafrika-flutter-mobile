import 'package:flutter/material.dart';
import 'package:vendor_app/screens/main/tabs/media_tab.dart';
import 'package:vendor_app/screens/main/tabs/analytics_tab.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/screens/main/tabs/store_tab.dart';
import 'package:vendor_app/widgets/navigation_drawer.dart' as custom_nav;
import 'package:vendor_app/screens/Dashboard.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;
  const MainScreen({super.key, this.initialTab = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _fadeController;
  late final AnimationController _tabController;
  late final Animation<double> _fadeAnimation;
  late final List<Animation<double>> _tabAnimations;

  final List<Widget> _tabs = [
    const DashboardScreen(),
    const MediaTab(),
    const InventoryTab(),
    const AnalyticsTab(),
  ];

  final List<Map<String, dynamic>> _tabItems = [
    {
      'icon': Icons.dashboard_outlined,
      'activeIcon': Icons.dashboard,
      'label': 'Dashboard',
      'color': AppTheme.primary,
    },
    {
      'icon': Icons.photo_library_outlined,
      'activeIcon': Icons.photo_library,
      'label': 'Media',
      'color': AppTheme.primary,
    },
    {
      'icon': Icons.store_outlined,
      'activeIcon': Icons.store,
      'label': 'Store',
      'color': AppTheme.accent,
    },
    {
      'icon': Icons.analytics_outlined,
      'activeIcon': Icons.analytics,
      'label': 'Analytics',
      'color': AppTheme.secondary,
    },
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _tabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _tabAnimations = List.generate(
      _tabItems.length,
      (index) => Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: _tabController,
          curve: Interval(
            index * 0.1,
            (index * 0.1) + 0.3,
            curve: Curves.elasticOut,
          ),
        ),
      ),
    );

    _fadeController.forward();
    _tabController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);

      _tabController.reset();
      _tabController.forward();
    }
  }

  Widget _buildTabItem(int index) {
    final item = _tabItems[index];
    final isSelected = _currentIndex == index;
    final color = item['color'] as Color;

    return AnimatedBuilder(
      animation: _tabAnimations[index],
      builder: (context, child) {
        return Transform.scale(
          scale: _tabAnimations[index].value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _onTabTapped(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: isSelected
                    ? BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: color.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      )
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isSelected
                            ? item['activeIcon'] as IconData
                            : item['icon'] as IconData,
                        key: ValueKey(isSelected),
                        size: isSelected ? 24 : 22,
                        color: isSelected
                            ? color
                            : AppTheme.earth.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: isSelected
                            ? color
                            : AppTheme.earth.withOpacity(0.6),
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                      child: Text(item['label'] as String),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.earthLight.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
          BoxShadow(
            color: AppTheme.earth.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              _tabItems.length,
              (index) => Expanded(child: _buildTabItem(index)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title;
    switch (_currentIndex) {
      case 0:
        title = 'Dashboard';
        break;
      case 1:
        title = 'Media';
        break;
      case 2:
        title = 'Store';
        break;
      case 3:
        title = 'Analytics';
        break;
      default:
        title = 'Dashboard';
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      drawer: custom_nav.NavigationDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildCompactTabBar(),
            ),
          ],
        ),
      ),
    );
  }
}

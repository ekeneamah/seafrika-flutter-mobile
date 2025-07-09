import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

// Search criteria enum for type safety
enum SearchCriteria {
  bookings('Bookings', Icons.event_outlined),
  customers('Customers', Icons.people_outline),
  suppliers('Suppliers', Icons.local_shipping_outlined),
  products('Products', Icons.inventory_2_outlined),
  tasks('Tasks', Icons.task_outlined),
  notifications('Notifications', Icons.notifications_outlined);

  const SearchCriteria(this.label, this.icon);
  final String label;
  final IconData icon;
}

// Search suggestion model
class SearchSuggestion {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final SearchCriteria type;

  const SearchSuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      icon: _getIconFromString(json['icon']),
      type: SearchCriteria.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SearchCriteria.products,
      ),
    );
  }

  static IconData _getIconFromString(String? iconName) {
    switch (iconName) {
      case 'event':
        return Icons.event_outlined;
      case 'person':
        return Icons.person_outline;
      case 'business':
        return Icons.business_outlined;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'task':
        return Icons.task_outlined;
      case 'notification':
        return Icons.notifications_outlined;
      default:
        return Icons.search_outlined;
    }
  }
}

// Rename custom FilterChip class to FilterChipData
typedef FilterChipData = _FilterChipData;

class _FilterChipData {
  final String id;
  final String label;
  final Color color;
  final bool isActive;

  const _FilterChipData({
    required this.id,
    required this.label,
    required this.color,
    this.isActive = false,
  });

  factory _FilterChipData.fromJson(Map<String, dynamic> json) {
    return _FilterChipData(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      color: Color(int.parse(json['color'] ?? '0xFF6366F1')),
      isActive: json['isActive'] ?? false,
    );
  }
}

// Riverpod providers
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCriteriaProvider = StateProvider<SearchCriteria>((ref) => 
    SearchCriteria.products);
final activeFiltersProvider = StateProvider<Set<String>>((ref) => {});

// Search suggestions provider with debouncing
final searchSuggestionsProvider = FutureProvider.family<List<SearchSuggestion>, 
    String>((ref, query) async {
  if (query.isEmpty) return [];
  
  final criteria = ref.watch(selectedCriteriaProvider);
  // TODO: Replace with actual API call
  return _fetchSearchSuggestions(query, criteria);
});

// Filter chips provider
final filterChipsProvider = FutureProvider.family<List<FilterChipData>, 
    SearchCriteria>((ref, criteria) async {
  // TODO: Replace with actual API call
  return _fetchFilterChips(criteria);
});

/// Main search widget with luxury theme and multi-module support
class VendorSearchWidget extends ConsumerStatefulWidget {
  const VendorSearchWidget({
    Key? key,
    this.onSearchSubmitted,
    this.onSuggestionSelected,
  }) : super(key: key);

  final Function(String query, SearchCriteria criteria)? onSearchSubmitted;
  final Function(SearchSuggestion suggestion)? onSuggestionSelected;

  @override
  ConsumerState<VendorSearchWidget> createState() => _VendorSearchWidgetState();
}

class _VendorSearchWidgetState extends ConsumerState<VendorSearchWidget>
    with TickerProviderStateMixin {
  late TextEditingController _searchController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _showSuggestions = false;
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAnimations();
    _loadLastSelectedCriteria();
  }

  void _initializeControllers() {
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  /// Load last selected search criteria from SharedPreferences
  Future<void> _loadLastSelectedCriteria() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCriteria = prefs.getString('last_search_criteria');
      if (savedCriteria != null) {
        final criteria = SearchCriteria.values.firstWhere(
          (e) => e.name == savedCriteria,
          orElse: () => SearchCriteria.products,
        );
        ref.read(selectedCriteriaProvider.notifier).state = criteria;
      }
    } catch (e) {
      debugPrint('Error loading search criteria: $e');
    }
  }

  /// Save selected criteria to SharedPreferences
  Future<void> _saveSelectedCriteria(SearchCriteria criteria) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_search_criteria', criteria.name);
    } catch (e) {
      debugPrint('Error saving search criteria: $e');
    }
  }

  /// Handle search input changes with debouncing
  void _onSearchChanged() {
    final query = _searchController.text;
    ref.read(searchQueryProvider.notifier).state = query;
    
    // Debounce search suggestions
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchController.text == query && query.isNotEmpty) {
        setState(() {
          _debouncedQuery = query;
          _showSuggestions = true;
        });
      } else if (query.isEmpty) {
        setState(() {
          _showSuggestions = false;
        });
      }
    });
  }

  /// Handle search submission
  void _onSearchSubmitted() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final criteria = ref.read(selectedCriteriaProvider);
    setState(() => _showSuggestions = false);
    
    widget.onSearchSubmitted?.call(query, criteria);
    
    // TODO: Navigate to results page
    // Navigator.pushNamed(context, '/results', arguments: {
    //   'query': query,
    //   'criteria': criteria.name,
    // });
  }

  /// Handle suggestion selection
  void _onSuggestionSelected(SearchSuggestion suggestion) {
    _searchController.text = suggestion.title;
    setState(() => _showSuggestions = false);
    
    widget.onSuggestionSelected?.call(suggestion);
    
    // TODO: Navigate to specific item or results
    // Navigator.pushNamed(context, '/item/${suggestion.id}');
  }

  /// Clear search input
  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() => _showSuggestions = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          key: const Key('vendor_search_widget'),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC29FFF), Color(0xFF00E7FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC29FFF).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSearchHeader(),
                _buildSearchField(),
                _buildFilterChips(),
                if (_showSuggestions) _buildSuggestionsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build search criteria selector header
  Widget _buildSearchHeader() {
    final selectedCriteria = ref.watch(selectedCriteriaProvider);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(
            selectedCriteria.icon,
            color: const Color(0xFF6366F1),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SearchCriteria>(
                key: const Key('search_criteria_dropdown'),
                value: selectedCriteria,
                icon: const Icon(Icons.keyboard_arrow_down, 
                    color: Color(0xFF6366F1)),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
                items: SearchCriteria.values.map((criteria) {
                  return DropdownMenuItem(
                    value: criteria,
                    child: Row(
                      children: [
                        Icon(criteria.icon, size: 20, 
                            color: const Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        Text(criteria.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (criteria) {
                  if (criteria != null) {
                    ref.read(selectedCriteriaProvider.notifier).state = criteria;
                    _saveSelectedCriteria(criteria);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build main search input field
  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: TextField(
          key: const Key('search_text_field'),
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search ${ref.watch(selectedCriteriaProvider).label.toLowerCase()}...',
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Semantics(
              label: 'Search',
              child: IconButton(
                key: const Key('search_submit_button'),
                icon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                onPressed: _onSearchSubmitted,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? Semantics(
                    label: 'Clear search',
                    child: IconButton(
                      key: const Key('search_clear_button'),
                      icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF)),
                      onPressed: _clearSearch,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1F2937),
          ),
          onSubmitted: (_) => _onSearchSubmitted(),
        ),
      ),
    );
  }

  /// Build horizontal filter chips
  Widget _buildFilterChips() {
    final selectedCriteria = ref.watch(selectedCriteriaProvider);
    final filterChipsAsync = ref.watch(filterChipsProvider(selectedCriteria));
    final activeFilters = ref.watch(activeFiltersProvider);

    return filterChipsAsync.when(
      data: (chips) {
        if (chips.isEmpty) return const SizedBox.shrink();
        
        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: ListView.separated(
            key: const Key('filter_chips_list'),
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final chip = chips[index];
              final isActive = activeFilters.contains(chip.id);
              
              return Semantics(
                label: 'Filter by ${chip.label}',
                child: FilterChip(
                  key: Key('filter_chip_${chip.id}'),
                  label: Text(
                    chip.label,
                    style: TextStyle(
                      color: isActive ? Colors.white : chip.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  selected: isActive,
                  selectedColor: chip.color,
                  backgroundColor: chip.color.withOpacity(0.1),
                  side: BorderSide(color: chip.color),
                  onSelected: (selected) {
                    final updatedFilters = Set<String>.from(activeFilters);
                    if (selected) {
                      updatedFilters.add(chip.id);
                    } else {
                      updatedFilters.remove(chip.id);
                    }
                    ref.read(activeFiltersProvider.notifier).state = 
                        updatedFilters;
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 50),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Build search suggestions list
  Widget _buildSuggestionsList() {
    final suggestionsAsync = ref.watch(searchSuggestionsProvider(_debouncedQuery));

    return suggestionsAsync.when(
      data: (suggestions) {
        if (suggestions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: const Text(
              'No suggestions found',
              style: TextStyle(color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Container(
          key: const Key('suggestions_list'),
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              
              return Semantics(
                label: 'Select ${suggestion.title}',
                child: ListTile(
                  key: Key('suggestion_${suggestion.id}'),
                  leading: Icon(
                    suggestion.icon,
                    color: const Color(0xFF6366F1),
                    size: 20,
                  ),
                  title: Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  subtitle: suggestion.subtitle.isNotEmpty
                      ? Text(
                          suggestion.subtitle,
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        )
                      : null,
                  onTap: () => _onSuggestionSelected(suggestion),
                ),
              );
            },
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6366F1),
            strokeWidth: 2,
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// TODO: Replace with actual API implementation
Future<List<SearchSuggestion>> _fetchSearchSuggestions(
  String query,
  SearchCriteria criteria,
) async {
  // Simulate API delay
  await Future.delayed(const Duration(milliseconds: 500));
  
  // Mock suggestions based on criteria
  switch (criteria) {
    case SearchCriteria.products:
      return [
        SearchSuggestion(
          id: '1',
          title: 'iPhone 15 Pro',
          subtitle: 'Electronics • In Stock',
          icon: Icons.phone_iphone,
          type: criteria,
        ),
        SearchSuggestion(
          id: '2',
          title: 'MacBook Air M2',
          subtitle: 'Computers • Low Stock',
          icon: Icons.laptop_mac,
          type: criteria,
        ),
      ];
    case SearchCriteria.customers:
      return [
        SearchSuggestion(
          id: '3',
          title: 'John Doe',
          subtitle: 'Premium Customer • 5 orders',
          icon: Icons.person,
          type: criteria,
        ),
      ];
    case SearchCriteria.bookings:
      return [
        SearchSuggestion(
          id: '4',
          title: 'Hair Styling - Sarah Wilson',
          subtitle: 'Today 2:00 PM • Confirmed',
          icon: Icons.event,
          type: criteria,
        ),
      ];
    default:
      return [];
  }
}

// TODO: Replace with actual API implementation
Future<List<FilterChipData>> _fetchFilterChips(SearchCriteria criteria) async {
  // Simulate API delay
  await Future.delayed(const Duration(milliseconds: 300));
  
  // Mock filter chips based on criteria
  switch (criteria) {
    case SearchCriteria.products:
      return [
        const FilterChipData(
          id: 'low_stock',
          label: 'Low Stock',
          color: Color(0xFFEF4444),
        ),
        const FilterChipData(
          id: 'featured',
          label: 'Featured',
          color: Color(0xFF10B981),
        ),
        const FilterChipData(
          id: 'on_sale',
          label: 'On Sale',
          color: Color(0xFFF59E0B),
        ),
      ];
    case SearchCriteria.tasks:
      return [
        const FilterChipData(
          id: 'pending',
          label: 'Pending',
          color: Color(0xFFF59E0B),
        ),
        const FilterChipData(
          id: 'urgent',
          label: 'Urgent',
          color: Color(0xFFEF4444),
        ),
      ];
    case SearchCriteria.notifications:
      return [
        const FilterChipData(
          id: 'unread',
          label: 'Unread',
          color: Color(0xFF6366F1),
        ),
      ];
    default:
      return [];
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/messages_provider.dart';

class MessagesSearchBar extends ConsumerStatefulWidget {
  const MessagesSearchBar({Key? key}) : super(key: key);

  @override
  ConsumerState<MessagesSearchBar> createState() => _MessagesSearchBarState();
}

class _MessagesSearchBarState extends ConsumerState<MessagesSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    ref.read(messageFiltersProvider.notifier).setSearchQuery(
          query.isEmpty ? null : query,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ref.watch(messageFiltersProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'Search conversations, messages, or customers...',
          hintStyle: GoogleFonts.inter(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: filters.searchQuery != null
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _focusNode.unfocus();
                  },
                )
              : IconButton(
                  icon: Icon(
                    Icons.tune,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  onPressed: () => _showAdvancedSearch(context),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: theme.colorScheme.onSurface,
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          _focusNode.unfocus();
        },
      ),
    );
  }

  void _showAdvancedSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AdvancedSearchSheet(),
    );
  }
}

class AdvancedSearchSheet extends ConsumerStatefulWidget {
  const AdvancedSearchSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<AdvancedSearchSheet> createState() =>
      _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends ConsumerState<AdvancedSearchSheet> {
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerEmailController =
      TextEditingController();
  final TextEditingController _keywordsController = TextEditingController();

  DateTimeRange? _dateRange;
  String? _selectedSortBy = 'lastMessage';
  bool _sortDescending = true;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerEmailController.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Advanced Search',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Search
                    _buildSectionTitle('Customer Information'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _customerEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Customer Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),

                    // Message Content
                    _buildSectionTitle('Message Content'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _keywordsController,
                      decoration: const InputDecoration(
                        labelText: 'Keywords',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search in message content...',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Date Range
                    _buildSectionTitle('Date Range'),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectDateRange,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _dateRange != null
                                    ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                                    : 'Select date range',
                                style: GoogleFonts.inter(
                                  color: _dateRange != null
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (_dateRange != null)
                              IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _dateRange = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sort Options
                    _buildSectionTitle('Sort Options'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Sort by',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedSortBy,
                      items: const [
                        DropdownMenuItem(
                          value: 'lastMessage',
                          child: Text('Last Message'),
                        ),
                        DropdownMenuItem(
                          value: 'created',
                          child: Text('Date Created'),
                        ),
                        DropdownMenuItem(
                          value: 'customerName',
                          child: Text('Customer Name'),
                        ),
                        DropdownMenuItem(
                          value: 'platform',
                          child: Text('Platform'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSortBy = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _sortDescending,
                          onChanged: (value) {
                            setState(() {
                              _sortDescending = value ?? true;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Descending order',
                          style: GoogleFonts.inter(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _clearSearch();
                      Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _applyAdvancedSearch();
                      Navigator.pop(context);
                    },
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  void _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _applyAdvancedSearch() {
    // TODO: Implement advanced search logic
    final searchTerms = <String>[
      if (_customerNameController.text.isNotEmpty) _customerNameController.text,
      if (_customerEmailController.text.isNotEmpty)
        _customerEmailController.text,
      if (_keywordsController.text.isNotEmpty) _keywordsController.text,
    ].join(' ');

    if (searchTerms.isNotEmpty) {
      ref.read(messageFiltersProvider.notifier).setSearchQuery(searchTerms);
    }

    if (_dateRange != null) {
      ref.read(messageFiltersProvider.notifier).setStartDate(_dateRange!.start);
      ref.read(messageFiltersProvider.notifier).setEndDate(_dateRange!.end);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Advanced search applied'),
      ),
    );
  }

  void _clearSearch() {
    _customerNameController.clear();
    _customerEmailController.clear();
    _keywordsController.clear();
    setState(() {
      _dateRange = null;
      _selectedSortBy = 'lastMessage';
      _sortDescending = true;
    });
    ref.read(messageFiltersProvider.notifier).clearFilters();
  }
}

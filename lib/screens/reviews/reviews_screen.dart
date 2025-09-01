import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/review.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/review_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart' as loading;

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ReviewType? _selectedType;
  ReviewStatus? _selectedStatus;
  String? _selectedPlatformId;
  String? _productId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['productId'] != null) {
      _productId = args['productId'] as String;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Review> _filterReviews(List<Review> reviews) {
    return reviews.where((review) {
      final matchesSearch = review.customerName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          review.content.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == null || review.type == _selectedType;
      final matchesStatus =
          _selectedStatus == null || review.status == _selectedStatus;
      final matchesPlatform = _selectedPlatformId == null ||
          review.platformId == _selectedPlatformId;
      return matchesSearch && matchesType && matchesStatus && matchesPlatform;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews & Complaints'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search reviews...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypeChip('All', null),
                      _buildTypeChip('Reviews', ReviewType.review),
                      _buildTypeChip('Complaints', ReviewType.complaint),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('All', null),
                      _buildStatusChip('Pending', ReviewStatus.pending),
                      _buildStatusChip('Responded', ReviewStatus.responded),
                      _buildStatusChip('Resolved', ReviewStatus.resolved),
                      _buildStatusChip('Archived', ReviewStatus.archived),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Review>>(
              stream: context.read<ReviewService>().streamReviews(
                    platformId: _selectedPlatformId,
                    type: _selectedType,
                    status: _selectedStatus,
                    productId: _productId,
                  ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return error.ErrorView(
                    message: 'Failed to load reviews',
                    onRetry: () {
                      setState(() {});
                    },
                  );
                }

                if (!snapshot.hasData) {
                  return const loading.LoadingView();
                }

                final reviews = _filterReviews(snapshot.data!);

                if (reviews.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.rate_review,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Reviews Found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Reviews and complaints will appear here',
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return Card(
                      child: ListTile(
                        onTap: () {
                          NavigationService.navigateToReviewDetail(review.id);
                        },
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(review.status),
                          child: Icon(
                            _getStatusIcon(review.status),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(review.customerName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  review.type == ReviewType.review
                                      ? Icons.star
                                      : Icons.warning,
                                  size: 16,
                                  color: review.type == ReviewType.review
                                      ? Colors.amber
                                      : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  review.type == ReviewType.review
                                      ? '${review.rating} stars'
                                      : 'Complaint',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  review.platformName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Text(
                          review.status.toString().split('.').last,
                          style: TextStyle(
                            color: _getStatusColor(review.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, ReviewType? type) {
    final isSelected = type == _selectedType;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedType = selected ? type : null);
        },
      ),
    );
  }

  Widget _buildStatusChip(String label, ReviewStatus? status) {
    final isSelected = status == _selectedStatus;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedStatus = selected ? status : null);
        },
      ),
    );
  }

  Color _getStatusColor(ReviewStatus status) {
    switch (status) {
      case ReviewStatus.pending:
        return Colors.orange;
      case ReviewStatus.responded:
        return Colors.blue;
      case ReviewStatus.resolved:
        return Colors.green;
      case ReviewStatus.archived:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ReviewStatus status) {
    switch (status) {
      case ReviewStatus.pending:
        return Icons.pending;
      case ReviewStatus.responded:
        return Icons.reply;
      case ReviewStatus.resolved:
        return Icons.check;
      case ReviewStatus.archived:
        return Icons.archive;
    }
  }
}

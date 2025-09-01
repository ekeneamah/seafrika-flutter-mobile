import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/review.dart';
import 'package:vendor_app/services/review_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart' as loading;

class ReviewDetailScreen extends StatefulWidget {
  final String reviewId;

  const ReviewDetailScreen({
    super.key,
    required this.reviewId,
  });

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Review? _review;
  final _responseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _loadReview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reviewService = context.read<ReviewService>();
      final review = await reviewService.fetchReview(widget.reviewId);
      setState(() {
        _review = review;
        _isLoading = false;
        if (review.response != null) {
          _responseController.text = review.response!;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load review details';
        _isLoading = false;
      });
    }
  }

  Future<void> _respondToReview() async {
    if (_responseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a response')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final reviewService = context.read<ReviewService>();
      await reviewService.respondToReview(
        widget.reviewId,
        response: _responseController.text,
        newStatus: ReviewStatus.responded,
      );
      await _loadReview();
    } catch (e) {
      setState(() => _error = 'Failed to respond to review');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(ReviewStatus status) async {
    setState(() => _isLoading = true);

    try {
      final reviewService = context.read<ReviewService>();
      await reviewService.updateReviewStatus(widget.reviewId, status);
      await _loadReview();
    } catch (e) {
      setState(() => _error = 'Failed to update status');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addToCRM() async {
    setState(() => _isLoading = true);

    try {
      final reviewService = context.read<ReviewService>();
      await reviewService.addReviewerToCRM(widget.reviewId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer added to CRM')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to add customer to CRM');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Details'),
        actions: [
          if (_review != null && _review!.status == ReviewStatus.pending)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _addToCRM,
              tooltip: 'Add to CRM',
            ),
        ],
      ),
      body: _isLoading
          ? const loading.LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadReview,
                )
              : _review == null
                  ? const Center(child: Text('Review not found'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer Information',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow('Name', _review!.customerName),
                                _buildInfoRow('Email', _review!.customerEmail),
                                if (_review!.customerPhone != null)
                                  _buildInfoRow(
                                      'Phone', _review!.customerPhone!),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Review Details',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  'Type',
                                  _review!.type == ReviewType.review
                                      ? 'Review (${_review!.rating} stars)'
                                      : 'Complaint',
                                ),
                                _buildInfoRow(
                                    'Platform', _review!.platformName),
                                _buildInfoRow(
                                  'Date',
                                  _review!.createdAt.toString().split('.')[0],
                                ),
                                _buildInfoRow('Status',
                                    _review!.status.toString().split('.').last),
                                if (_review!.productName != null)
                                  _buildInfoRow(
                                      'Product', _review!.productName!),
                                const SizedBox(height: 16),
                                Text(
                                  'Content',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(_review!.content),
                              ],
                            ),
                          ),
                        ),
                        if (_review!.response != null) ...[
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Response',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(_review!.response!),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Responded on ${_review!.respondedAt.toString().split('.')[0]}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_review!.status == ReviewStatus.pending) ...[
                          TextField(
                            controller: _responseController,
                            decoration: const InputDecoration(
                              labelText: 'Response',
                              border: OutlineInputBorder(),
                              hintText: 'Enter your response...',
                            ),
                            maxLines: 4,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _updateStatus(ReviewStatus.archived),
                                  icon: const Icon(Icons.archive),
                                  label: const Text('Archive'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _respondToReview,
                                  icon: const Icon(Icons.reply),
                                  label: const Text('Respond'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (_review!.status ==
                            ReviewStatus.responded) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _updateStatus(ReviewStatus.archived),
                                  icon: const Icon(Icons.archive),
                                  label: const Text('Archive'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _updateStatus(ReviewStatus.resolved),
                                  icon: const Icon(Icons.check),
                                  label: const Text('Mark as Resolved'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

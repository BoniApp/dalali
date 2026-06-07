import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/review_model.dart';

import 'package:dalali/providers/app_state.dart';

class ReviewsScreen extends StatefulWidget {
  final PropertyModel property;

  const ReviewsScreen({super.key, required this.property});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _showForm = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final reviews = appState.reviews.where((r) => r.propertyId == widget.property.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: Column(
        children: [
          _SummaryHeader(property: widget.property, reviews: reviews),
          Expanded(
            child: reviews.isEmpty
                ? const _EmptyReviews()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: reviews.length,
                    itemBuilder: (_, i) => _ReviewCard(review: reviews[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _showForm = !_showForm),
        icon: Icon(_showForm ? Icons.close : Icons.rate_review),
        label: Text(_showForm ? 'Close' : 'Write Review'),
      ),
      bottomSheet: _showForm ? _ReviewForm(property: widget.property, onSubmit: () => setState(() => _showForm = false)) : null,
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final PropertyModel property;
  final List<ReviewModel> reviews;

  const _SummaryHeader({required this.property, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(Icons.star_border, size: 40, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No reviews yet', style: theme.textTheme.titleMedium),
                  Text('Be the first to review this property.', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final overall = reviews.map((r) => r.overallScore).reduce((a, b) => a + b) / reviews.length;
    final verifiedCount = reviews.where((r) => r.stayVerified).length;

    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                overall.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < overall.floor() ? Icons.star : Icons.star_border,
                      size: 18,
                      color: Colors.amber,
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '$verifiedCount verified stay${verifiedCount == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(review.reviewerName[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.reviewerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        DateFormat('MMM d, yyyy').format(review.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (review.stayVerified)
                  Chip(
                    avatar: const Icon(Icons.verified, size: 14, color: Colors.green),
                    label: const Text('Verified', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MiniScore(label: 'Property', score: review.propertyScore),
                const SizedBox(width: 16),
                _MiniScore(label: 'Landlord', score: review.landlordScore),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(review.comment!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  final String label;
  final double score;

  const _MiniScore({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(width: 4),
        Icon(Icons.star, size: 14, color: Colors.amber[700]),
        Text(score.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No reviews yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Be the first to share your experience.', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _ReviewForm extends StatefulWidget {
  final PropertyModel property;
  final VoidCallback onSubmit;

  const _ReviewForm({required this.property, required this.onSubmit});

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  double _cleanliness = 4;
  double _value = 4;
  double _safety = 4;
  double _communication = 4;
  double _fairness = 4;
  double _maintenance = 4;
  final _commentController = TextEditingController();
  bool _stayVerified = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return;

    final review = ReviewModel(
      id: 'r_${DateTime.now().millisecondsSinceEpoch}',
      propertyId: widget.property.id,
      propertyTitle: widget.property.title,
      reviewerId: user.id,
      reviewerName: user.fullName,
      stayVerified: _stayVerified,
      cleanliness: _cleanliness,
      valueForMoney: _value,
      safety: _safety,
      communication: _communication,
      fairness: _fairness,
      maintenance: _maintenance,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    appState.addReview(review);
    widget.onSubmit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review submitted successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Write a Review', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _SliderRow(label: 'Cleanliness', value: _cleanliness, onChanged: (v) => setState(() => _cleanliness = v)),
              _SliderRow(label: 'Value for Money', value: _value, onChanged: (v) => setState(() => _value = v)),
              _SliderRow(label: 'Safety', value: _safety, onChanged: (v) => setState(() => _safety = v)),
              _SliderRow(label: 'Communication', value: _communication, onChanged: (v) => setState(() => _communication = v)),
              _SliderRow(label: 'Fairness', value: _fairness, onChanged: (v) => setState(() => _fairness = v)),
              _SliderRow(label: 'Maintenance', value: _maintenance, onChanged: (v) => setState(() => _maintenance = v)),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _stayVerified,
                onChanged: (v) => setState(() => _stayVerified = v),
                title: const Text('I have stayed at this property'),
                subtitle: const Text('Verified stays carry more weight.'),
                contentPadding: EdgeInsets.zero,
              ),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  hintText: 'Share your experience...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send),
                label: const Text('Submit Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: 1,
          max: 5,
          divisions: 8,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

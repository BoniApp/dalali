import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/providers/app_state.dart';

class StartMoveScreen extends StatefulWidget {
  const StartMoveScreen({super.key});

  @override
  State<StartMoveScreen> createState() => _StartMoveScreenState();
}

class _StartMoveScreenState extends State<StartMoveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentHomeController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _preferredLocationController = TextEditingController();

  DateTime? _moveDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentHomeController.dispose();
    _locationController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _preferredLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickMoveDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _moveDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_moveDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a move date')),
      );
      return;
    }

    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final move = MoveListingModel(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      userName: user.fullName,
      currentPropertyTitle: _currentHomeController.text.trim(),
      currentLocation: _locationController.text.trim(),
      moveDate: _moveDate!,
      status: MoveStatus.planning,
      budgetMin: double.tryParse(_budgetMinController.text.trim()),
      budgetMax: double.tryParse(_budgetMaxController.text.trim()),
      preferredLocation: _preferredLocationController.text.trim().isEmpty
          ? null
          : _preferredLocationController.text.trim(),
      createdAt: DateTime.now(),
    );

    appState.startMove(move);

    setState(() => _isLoading = false);

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Move started! Your current home is now listed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Start Your Move')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '🚚 Tell us about your move',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'We will list your current home while you search for a new one.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _currentHomeController,
                decoration: const InputDecoration(
                  labelText: 'Current Home Title',
                  hintText: 'e.g. 2-Bedroom Apartment in Masaki',
                  prefixIcon: Icon(Icons.home),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Current Location',
                  hintText: 'e.g. Masaki, Dar es Salaam',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _pickMoveDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Planned Move Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _moveDate != null
                        ? DateFormat('EEEE, MMM d, yyyy').format(_moveDate!)
                        : 'Select date',
                    style: TextStyle(
                      color: _moveDate != null ? null : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min Budget (TZS)',
                        prefixIcon: Icon(Icons.money_off),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetMaxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Budget (TZS)',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _preferredLocationController,
                decoration: const InputDecoration(
                  labelText: 'Preferred New Location (optional)',
                  hintText: 'e.g. Mikocheni, Oyster Bay',
                  prefixIcon: Icon(Icons.map),
                ),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'What happens next?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Your current home will be listed as a "Move Listing"\n'
                      '• You can browse properties while others view your home\n'
                      '• Earn 100 reward points for listing during your move\n'
                      '• Mark complete when you find your new home',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_shipping),
                label: Text(_isLoading ? 'Starting...' : 'Start My Move'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

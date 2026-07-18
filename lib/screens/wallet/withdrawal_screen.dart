import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/wallet_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/wallet_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  PaymentProvider _selectedProvider = PaymentProvider.mpesa;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')),
        );
      }
      return;
    }

    final settings = await WalletService().getSystemSettingsOnce();
    final minWithdrawal = (settings['min_withdrawal'] as num?)?.toDouble() ?? 5000.0;
    if (amount < minWithdrawal) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Minimum withdrawal is ${Helpers.formatPrice(minWithdrawal)}')),
        );
      }
      return;
    }

    if (_phoneController.text.length < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid phone number')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final withdrawal = WithdrawalModel(
        id: 'w${DateTime.now().millisecondsSinceEpoch}',
        userId: user.id,
        amount: amount,
        phone: _phoneController.text,
        provider: _selectedProvider,
        status: WithdrawalStatus.pending,
        createdAt: DateTime.now(),
      );

      await WalletService().requestWithdrawal(withdrawal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal request submitted! Processing may take 24-48 hours.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<WalletModel?>(
              stream: WalletService().getWallet(user.id),
              builder: (context, snapshot) {
                final wallet = snapshot.data;
                final available = wallet?.availableBalance ?? 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: AppTheme.primary.withAlpha(13),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet, color: AppTheme.primaryDark, size: 32),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Available Balance', style: TextStyle(fontSize: 12, color: AppTheme.primaryDark)),
                                  Text(
                                    Helpers.formatPrice(available),
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Withdrawal Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Amount (TZS)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.money),
                          suffixIcon: TextButton(
                            onPressed: () => _amountController.text = available.toStringAsFixed(0),
                            child: const Text('MAX'),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Money Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          hintText: 'e.g. 0712345678',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      const Text('Provider', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: PaymentProvider.values.map((provider) {
                          final selected = _selectedProvider == provider;
                          return ChoiceChip(
                            label: Text(_providerLabel(provider)),
                            selected: selected,
                            onSelected: (_) => setState(() => _selectedProvider = provider),
                            selectedColor: AppTheme.primary.withAlpha(26),
                            labelStyle: TextStyle(
                              color: selected ? AppTheme.primaryDark : Colors.black,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        color: Colors.amber.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber.shade800),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Withdrawals are processed within 24-48 hours. A small transaction fee may apply.',
                                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Request Withdrawal', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _providerLabel(PaymentProvider p) {
    switch (p) {
      case PaymentProvider.mpesa:
        return 'M-Pesa';
      case PaymentProvider.airtelMoney:
        return 'Airtel Money';
      case PaymentProvider.tigoPesa:
        return 'Tigo Pesa';
      case PaymentProvider.haloPesa:
        return 'HaloPesa';
      case PaymentProvider.bankTransfer:
        return 'Bank';
    }
  }
}

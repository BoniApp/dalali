import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/wallet_model.dart';
import 'package:dalali/models/influencer/referral_conversion_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/wallet_service.dart';
import 'package:dalali/services/influencer/influencer_service.dart';
import 'package:dalali/screens/influencer/influencer_application_screen.dart';
import 'package:dalali/utils/helpers.dart';

class InfluencerDashboardScreen extends StatelessWidget {
  const InfluencerDashboardScreen({super.key});

  String _conversionTypeLabel(AppLocalizations l10n, ConversionType type) {
    switch (type) {
      case ConversionType.registration:
        return l10n.conversionRegistration;
      case ConversionType.agencyFeePayment:
        return l10n.conversionAgencyFee;
      case ConversionType.premiumPayment:
        return l10n.conversionPremium;
      case ConversionType.dealClosed:
        return l10n.conversionDealClosed;
    }
  }

  Color _statusColor(ConversionStatus status) {
    switch (status) {
      case ConversionStatus.approved:
        return Colors.green;
      case ConversionStatus.paid:
        return Colors.blue;
      case ConversionStatus.rejected:
        return Colors.red;
      case ConversionStatus.pending:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final profile = appState.influencerProfile;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.influencerDashboard),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text(l10n.notLoggedIn)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.influencerDashboard),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: profile == null
          ? _NotInfluencerYet(
              onApply: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InfluencerApplicationScreen()),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: AppTheme.primary.withAlpha(13),
                      child: ListTile(
                        leading: Icon(Icons.paid, color: AppTheme.primaryDark),
                        title: Text(
                          l10n.commissionHint,
                          style: TextStyle(fontSize: 13, color: AppTheme.primaryDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: [
                        _StatCard(
                          label: l10n.totalClicks,
                          value: '${profile.totalClicks}',
                          icon: Icons.touch_app,
                          color: Colors.blue,
                        ),
                        _StatCard(
                          label: l10n.registrations,
                          value: '${profile.totalRegistrations}',
                          icon: Icons.person_add,
                          color: Colors.purple,
                        ),
                        _StatCard(
                          label: l10n.conversions,
                          value: '${profile.totalConversions}',
                          icon: Icons.check_circle,
                          color: Colors.orange,
                        ),
                        _StatCard(
                          label: l10n.totalEarnings,
                          value: Helpers.formatPrice(profile.totalEarnings),
                          icon: Icons.account_balance_wallet,
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<WalletModel?>(
                      stream: WalletService().getWallet(user.id),
                      builder: (context, snapshot) {
                        final wallet = snapshot.data;
                        return Card(
                          color: AppTheme.primary,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.availableBalance,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        Helpers.formatPrice(wallet?.availableBalance ?? 0),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.pendingBalance,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        Helpers.formatPrice(wallet?.pendingBalance ?? 0),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.recentConversions,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<ReferralConversionModel>>(
                      stream: InfluencerService().getMyConversions(user.id),
                      builder: (context, snapshot) {
                        final conversions = snapshot.data ?? [];
                        if (conversions.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              l10n.noConversionsYet,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          );
                        }
                        return Column(
                          children: conversions.take(10).map((c) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(c.status).withAlpha(30),
                                child: Icon(Icons.trending_up, color: _statusColor(c.status)),
                              ),
                              title: Text(_conversionTypeLabel(l10n, c.conversionType)),
                              subtitle: Text(Helpers.formatDate(c.createdAt)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Helpers.formatPrice(c.commissionAmount),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    c.status.name,
                                    style: TextStyle(fontSize: 11, color: _statusColor(c.status)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _NotInfluencerYet extends StatelessWidget {
  final VoidCallback onApply;

  const _NotInfluencerYet({required this.onApply});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 72, color: AppTheme.primary.withAlpha(51)),
            const SizedBox(height: 16),
            Text(
              l10n.notInfluencerYet,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.send),
              label: Text(l10n.applyNow),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

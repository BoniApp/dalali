import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/influencer/campaign_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/influencer/campaign_service.dart';

class InfluencerCampaignsScreen extends StatelessWidget {
  const InfluencerCampaignsScreen({super.key});

  Future<void> _joinCampaign(BuildContext context, CampaignModel campaign) async {
    final l10n = AppLocalizations.of(context)!;
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    try {
      await CampaignService().joinCampaign(campaignId: campaign.id, userId: user.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.joinedCampaign)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.joinCampaignFailed), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.watch<AppState>().currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.campaigns),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text(l10n.notLoggedIn)),
      );
    }

    final service = CampaignService();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.campaigns),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<CampaignParticipantModel>>(
        stream: service.getMyParticipations(user.id),
        builder: (context, partSnapshot) {
          final participations = partSnapshot.data ?? [];
          final joinedIds = participations
              .where((p) => p.status == CampaignParticipantStatus.joined)
              .map((p) => p.campaignId)
              .toSet();

          return StreamBuilder<List<CampaignModel>>(
            stream: service.getActiveCampaigns(),
            builder: (context, campSnapshot) {
              final campaigns = campSnapshot.data ?? [];
              final myCampaigns =
                  campaigns.where((c) => joinedIds.contains(c.id)).toList();
              final availableCampaigns =
                  campaigns.where((c) => !joinedIds.contains(c.id)).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.myCampaigns,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (myCampaigns.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.noCampaignsJoined,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    else
                      ...myCampaigns.map((c) => _CampaignCard(
                            campaign: c,
                            trailing: Chip(
                              label: Text(l10n.joined, style: const TextStyle(fontSize: 11)),
                              backgroundColor: AppTheme.primary.withAlpha(13),
                              labelStyle: TextStyle(color: AppTheme.primaryDark),
                            ),
                          )),
                    const SizedBox(height: 24),
                    Text(
                      l10n.availableCampaigns,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (availableCampaigns.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.noCampaignsAvailable,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    else
                      ...availableCampaigns.map((c) => _CampaignCard(
                            campaign: c,
                            trailing: ElevatedButton(
                              onPressed: () => _joinCampaign(context, c),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(l10n.join),
                            ),
                          )),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  final Widget trailing;

  const _CampaignCard({required this.campaign, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade50,
          child: const Icon(Icons.campaign, color: Colors.orange),
        ),
        title: Text(campaign.name),
        subtitle: Text(
          campaign.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: trailing,
      ),
    );
  }
}

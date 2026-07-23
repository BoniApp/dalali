import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/influencer/influencer_service.dart';
import 'package:dalali/screens/shared/property_detail_screen.dart';
import 'package:dalali/utils/helpers.dart';

/// ═══════════════════════════════════════════════════════════════
/// SHAREABLE LISTINGS SECTION
/// ═══════════════════════════════════════════════════════════════
///
/// "Listings to Share" on the influencer dashboard: a carousel of the
/// live feed the influencer can push to their socials. Every share
/// message carries their referral code + link, so signups (and the
/// resulting agency-fee commissions) are attributed to them.
class ShareableListingsSection extends StatelessWidget {
  final String referralCode;

  const ShareableListingsSection({super.key, required this.referralCode});

  String _message(AppLocalizations l10n, PropertyModel p) {
    final url = InfluencerService().buildReferralUrl(referralCode, listingId: p.id);
    return l10n.listingShareMessage(
      p.title,
      p.location,
      Helpers.formatPrice(p.rentPrice),
      referralCode,
      url,
    );
  }

  Future<void> _shareWhatsApp(String message) async {
    try {
      await launchUrl(
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // No browser/app available — ignore.
    }
  }

  void _openShareSheet(BuildContext context, PropertyModel p) {
    final l10n = AppLocalizations.of(context)!;
    final message = _message(l10n, p);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: Text(l10n.shareViaWhatsApp),
              onTap: () {
                Navigator.pop(ctx);
                _shareWhatsApp(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.primary),
              title: Text(l10n.copyMessage),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.messageCopiedHint)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final properties = context.watch<AppState>().properties;
    if (properties.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.listingsToShare,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.listingsToShareHint,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 208,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: properties.length > 20 ? 20 : properties.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final p = properties[index];
              return SizedBox(
                width: 160,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: p)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(
                          p.images.first,
                          width: 160,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 160,
                            height: 96,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                Helpers.formatPrice(p.rentPrice),
                                style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(Icons.share, size: 18, color: AppTheme.primary),
                                  tooltip: l10n.shareTo,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _openShareSheet(context, p),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

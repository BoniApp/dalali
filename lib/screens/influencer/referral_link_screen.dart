import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/influencer/referral_link_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/influencer/influencer_service.dart';
import 'package:dalali/screens/influencer/influencer_application_screen.dart';

class ReferralLinkScreen extends StatelessWidget {
  const ReferralLinkScreen({super.key});

  void _copy(BuildContext context, String value) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.copied)),
    );
  }

  Future<void> _launchExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // No browser/app available — ignore.
    }
  }

  Future<void> _shareWhatsApp(String message) {
    return _launchExternal('https://wa.me/?text=${Uri.encodeComponent(message)}');
  }

  /// Facebook, TikTok, Instagram and YouTube have no URL-based way to
  /// prefill post text — copy the message first so the influencer can
  /// paste it into their post, bio or video description, then open
  /// the platform.
  Future<void> _copyAndOpen(
    BuildContext context,
    String message,
    String url,
    String platform,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.sharePasteHint(platform))),
    );
    await _launchExternal(url);
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
          title: Text(l10n.referral),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text(l10n.notLoggedIn)),
      );
    }

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.referral),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.notInfluencerYet,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InfluencerApplicationScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.applyNow),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final service = InfluencerService();
    final referralUrl = service.buildReferralUrl(profile.referralCode);
    final shareMessage = l10n.referralShareMessage(profile.referralCode, referralUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.referral),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: AppTheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      l10n.yourReferralCode,
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.referralCode,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      referralUrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _copy(context, referralUrl),
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l10n.copy),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.shareTo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _ShareTarget(
                  icon: Icons.chat,
                  color: const Color(0xFF25D366),
                  label: 'WhatsApp',
                  onTap: () => _shareWhatsApp(shareMessage),
                ),
                _ShareTarget(
                  icon: Icons.facebook,
                  color: const Color(0xFF1877F2),
                  label: 'Facebook',
                  onTap: () => _copyAndOpen(
                    context,
                    shareMessage,
                    'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(referralUrl)}',
                    'Facebook',
                  ),
                ),
                _ShareTarget(
                  icon: Icons.alternate_email,
                  color: Colors.black,
                  label: 'Threads',
                  onTap: () => _launchExternal(
                    'https://www.threads.net/intent/post?text=${Uri.encodeComponent(shareMessage)}',
                  ),
                ),
                _ShareTarget(
                  icon: Icons.music_note,
                  color: Colors.black,
                  label: 'TikTok',
                  onTap: () => _copyAndOpen(
                    context,
                    shareMessage,
                    'https://www.tiktok.com',
                    'TikTok',
                  ),
                ),
                _ShareTarget(
                  icon: Icons.camera_alt,
                  color: const Color(0xFFE1306C),
                  label: 'Instagram',
                  onTap: () => _copyAndOpen(
                    context,
                    shareMessage,
                    'https://www.instagram.com',
                    'Instagram',
                  ),
                ),
                _ShareTarget(
                  icon: Icons.play_circle_fill,
                  color: const Color(0xFFFF0000),
                  label: 'YouTube',
                  onTap: () => _copyAndOpen(
                    context,
                    shareMessage,
                    'https://www.youtube.com',
                    'YouTube',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.campaignLinks,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<ReferralLinkModel>>(
              stream: service.getMyLinks(user.id),
              builder: (context, snapshot) {
                final links = snapshot.data ?? [];
                if (links.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.noLinksYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }
                return Column(
                  children: links.map((link) {
                    final url = service.buildReferralUrl(link.code);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withAlpha(13),
                          child: const Icon(Icons.link, color: AppTheme.primary),
                        ),
                        title: Text(link.code),
                        subtitle: Text(url, style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, color: AppTheme.primary),
                          onPressed: () => _copy(context, url),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A branded social-platform share button: tinted circle icon + label.
class _ShareTarget extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ShareTarget({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[100],
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

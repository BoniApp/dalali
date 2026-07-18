import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/influencer/influencer_application_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/influencer/influencer_service.dart';
import 'package:dalali/screens/influencer/influencer_dashboard_screen.dart';

class InfluencerApplicationScreen extends StatefulWidget {
  const InfluencerApplicationScreen({super.key});

  @override
  State<InfluencerApplicationScreen> createState() =>
      _InfluencerApplicationScreenState();
}

class _InfluencerApplicationScreenState extends State<InfluencerApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _instagramController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _followersController = TextEditingController();
  final _audienceLocationController = TextEditingController();
  final _service = InfluencerService();

  bool _isLoading = false;
  String _selectedNiche = 'real_estate';

  static const _niches = [
    'real_estate',
    'lifestyle',
    'comedy',
    'education',
    'news',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone;
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _tiktokController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _followersController.dispose();
    _audienceLocationController.dispose();
    super.dispose();
  }

  String _nicheLabel(AppLocalizations l10n, String niche) {
    switch (niche) {
      case 'real_estate':
        return l10n.nicheRealEstate;
      case 'lifestyle':
        return l10n.nicheLifestyle;
      case 'comedy':
        return l10n.nicheComedy;
      case 'education':
        return l10n.nicheEducation;
      case 'news':
        return l10n.nicheNews;
      default:
        return l10n.nicheOther;
    }
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final user = context.read<AppState>().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await _service.submitApplication(InfluencerApplicationModel(
        id: '',
        userId: user.id,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        tiktokUrl: _optional(_tiktokController.text),
        instagramUrl: _optional(_instagramController.text),
        youtubeUrl: _optional(_youtubeController.text),
        followersCount: int.tryParse(_followersController.text.trim()) ?? 0,
        contentNiche: _selectedNiche,
        audienceLocation: _optional(_audienceLocationController.text),
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.applicationSubmitted)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = context.watch<AppState>().currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.influencerProgram),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text(l10n.notLoggedIn)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.influencerProgram),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<InfluencerApplicationModel?>(
        stream: _service.watchMyApplication(user.id),
        builder: (context, snapshot) {
          final application = snapshot.data;

          if (application == null) {
            return _buildForm(l10n);
          }

          switch (application.status) {
            case InfluencerApplicationStatus.pending:
              return _StatusCard(
                icon: Icons.hourglass_top,
                color: Colors.orange,
                title: l10n.applicationUnderReview,
                message: l10n.applicationUnderReviewMessage,
              );
            case InfluencerApplicationStatus.rejected:
              return _StatusCard(
                icon: Icons.cancel,
                color: Colors.red,
                title: l10n.applicationRejected,
                message:
                    '${application.rejectionReason ?? ''}\n${l10n.contactSupport}',
              );
            case InfluencerApplicationStatus.approved:
              return _StatusCard(
                icon: Icons.check_circle,
                color: Colors.green,
                title: l10n.applicationApproved,
                message: l10n.applicationApprovedMessage,
                actionLabel: l10n.goToDashboard,
                onAction: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const InfluencerDashboardScreen()),
                ),
              );
          }
        },
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${l10n.fullName} *',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.isEmpty ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: '${l10n.phone} *',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.isEmpty ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: '${l10n.email} *',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.fieldRequired;
                  if (!v.contains('@')) return l10n.pleaseEnterValidEmail;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tiktokController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.tiktokUrl,
                  prefixIcon: const Icon(Icons.music_note),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _instagramController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.instagramUrl,
                  prefixIcon: const Icon(Icons.photo_camera),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _youtubeController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.youtubeUrl,
                  prefixIcon: const Icon(Icons.play_circle),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _followersController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.followersCount,
                  prefixIcon: const Icon(Icons.people),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                    return l10n.enterValidNumber;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedNiche,
                decoration: InputDecoration(
                  labelText: l10n.contentNiche,
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _niches
                    .map((n) => DropdownMenuItem(value: n, child: Text(_nicheLabel(l10n, n))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedNiche = v ?? _selectedNiche),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _audienceLocationController,
                decoration: InputDecoration(
                  labelText: l10n.audienceLocation,
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.submit, style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

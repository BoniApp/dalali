import 'package:flutter/material.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/screens/auth/login_screen.dart';
import 'package:dalali/screens/auth/register_screen.dart';
import 'package:dalali/screens/admin/login_admin_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  int _logoTapCount = 0;
  DateTime? _firstTapTime;

  void _onLogoTap(BuildContext context) {
    final now = DateTime.now();
    if (_firstTapTime == null || now.difference(_firstTapTime!) > const Duration(seconds: 3)) {
      _logoTapCount = 1;
      _firstTapTime = now;
    } else {
      _logoTapCount++;
    }

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      _firstTapTime = null;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginAdminScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _onLogoTap(context),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.home_work, size: 40, color: Colors.teal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.welcomeToDalali,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.appSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    l10n.howWouldYouLikeToUse,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.search,
                    title: l10n.houseSeeker,
                    subtitle: l10n.findYourHome,
                    color: Colors.blue,
                    onTap: () => _goToSignIn(context),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    icon: Icons.add_home,
                    title: l10n.landlord,
                    subtitle: l10n.listAndManage,
                    color: Colors.green,
                    onTap: () => _goToSignIn(context),
                  ),
                  const SizedBox(height: 12),
                  _RoleCard(
                    icon: Icons.support_agent,
                    title: l10n.agent,
                    subtitle: l10n.manageClients,
                    color: Colors.purple,
                    onTap: () => _goToSignIn(context),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    l10n.alreadyHaveAccount,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Text(l10n.signInWithEmail),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text('Create Account'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goToSignIn(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

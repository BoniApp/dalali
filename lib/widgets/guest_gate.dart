import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/providers/user_state.dart';
import 'package:dalali/screens/auth/login_screen.dart';
import 'package:dalali/screens/auth/register_screen.dart';

/// Guest-first conversion gate: browsing (listings, property detail,
/// the safety map) is open to anyone, but any interactive/personal
/// action — favoriting, contacting a landlord, applying, reviewing,
/// reporting, starting a move — requires an account. Wrap the
/// action with [GuestGate.requireAuth]; it returns true (proceed
/// immediately) for a signed-in user, or shows a sign-up prompt and
/// returns false for a guest.
///
/// This is a UX nudge only, not a security boundary — every AppState
/// mutation already no-ops without a signed-in user, and RLS is the
/// real authorization layer.
class GuestGate {
  static bool requireAuth(
    BuildContext context, {
    String message = 'Create a free account to continue.',
  }) {
    final user = context.read<UserState>().currentUser;
    if (user != null) return true;
    _showSignUpSheet(context, message);
    return false;
  }

  static void _showSignUpSheet(BuildContext context, String message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(Icons.lock_outline, size: 40, color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Sign up to continue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Create Account'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

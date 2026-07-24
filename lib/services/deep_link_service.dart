import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/dpo_payment_service.dart';
import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/screens/shared/property_detail_screen.dart';
import 'package:dalali/screens/wallet/payment_failed_screen.dart';
import 'package:dalali/screens/wallet/payment_pending_screen.dart';
import 'package:dalali/screens/wallet/payment_success_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// DEEP LINK SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Handles referral deep links: `https://dalaliapp.com/ref/<CODE>`
/// with an optional `?listing=<property-id>` (the links shared from
/// the influencer "Listings to Share" carousel).
///
///   • The referral CODE is stashed in [pendingReferralCode] — the
///     register screen prefills its referral field from it.
///   • The listing id opens the listing directly: immediately when
///     the app is already running and logged in (via [navigatorKey]),
///     otherwise stashed in [pendingListingId] and consumed by
///     MainNavigation once the user lands in the app.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  static const String refHost = 'dalaliapp.com';

  /// Navigator key for MaterialApp — lets warm-start links push the
  /// listing without waiting for a MainNavigation rebuild.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? pendingReferralCode;
  String? pendingListingId;

  /// Stashed dalali://payment-* deep link (host + token), consumed on
  /// warm start immediately or by MainNavigation after login.
  ({String host, String? token})? pendingPaymentLink;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  /// Pure parser — kept separate from the plugin so it is unit-testable.
  /// Returns the referral code and listing id carried by [uri].
  static ({String? code, String? listingId}) parseReferralLink(Uri uri) {
    if (uri.scheme != 'https' || uri.host != refHost) {
      return (code: null, listingId: null);
    }
    final segments = uri.pathSegments;
    String? code;
    if (segments.length == 2 && segments.first == 'ref' && segments[1].isNotEmpty) {
      code = segments[1].trim().toUpperCase();
    }
    final listing = uri.queryParameters['listing'];
    return (
      code: code,
      listingId: listing != null && listing.isNotEmpty ? listing : null,
    );
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (e) {
      debugPrint('DeepLinkService initial link error: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) => debugPrint('DeepLinkService stream error: $e'),
    );
  }

  void dispose() => _sub?.cancel();

  void _handle(Uri uri) {
    // dalali://payment-success|payment-pending|payment-failed?token=…
    // (redirect target of the dpo-callback edge function)
    if (uri.scheme == 'dalali') {
      if (uri.host.startsWith('payment-')) {
        final link = (host: uri.host, token: uri.queryParameters['token']);
        if (navigatorKey.currentState != null && SupabaseService.currentUser != null) {
          openPaymentLink(link);
        } else {
          pendingPaymentLink = link;
        }
      }
      return;
    }

    final data = parseReferralLink(uri);
    if (data.code == null && data.listingId == null) return;
    if (data.code != null) pendingReferralCode = data.code;
    if (data.listingId != null) {
      // Warm start with a logged-in session → open the listing now;
      // otherwise MainNavigation consumes pendingListingId after login.
      if (navigatorKey.currentState != null && SupabaseService.currentUser != null) {
        _openListing(data.listingId!);
      } else {
        pendingListingId = data.listingId;
      }
    }
  }

  /// Open a payment deep link (success/pending/failed) at the right screen.
  Future<void> openPaymentLink(({String host, String? token}) link) async {
    final nav = navigatorKey.currentState;
    final token = link.token;
    if (nav == null || token == null) return;
    try {
      final payment = await DpoPaymentService().getPaymentByToken(token);
      if (payment == null) return;
      final property = await DataService().getPropertyById(payment.propertyId);
      final title = property?.title ?? '';
      final user = SupabaseService.currentUser;
      // tenantName is a receipt label — the users row isn't always
      // readable client-side, so prefer auth metadata.
      final tenantName = (user?.userMetadata?['full_name'] as String?) ?? '';
      final nav2 = navigatorKey.currentState;
      if (nav2 == null) return;
      if (link.host == 'payment-success') {
        nav2.push(MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(payment: payment, propertyTitle: title, tenantName: tenantName),
        ));
      } else if (link.host == 'payment-pending') {
        nav2.push(MaterialPageRoute(
          builder: (_) => PaymentPendingScreen(payment: payment, propertyTitle: title),
        ));
      } else {
        nav2.push(MaterialPageRoute(
          builder: (_) => PaymentFailedScreen(payment: payment),
        ));
      }
    } catch (e) {
      debugPrint('DeepLinkService open payment link error: $e');
    }
  }

  /// Fetch + push the listing. Also used by MainNavigation for the
  /// stashed cold-start case.
  Future<void> openListingById(String listingId) => _openListing(listingId);

  Future<void> _openListing(String listingId) async {
    try {
      final property = await DataService().getPropertyById(listingId);
      final nav = navigatorKey.currentState;
      if (property == null || nav == null) return;
      nav.push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: property)));
    } catch (e) {
      debugPrint('DeepLinkService open listing error: $e');
    }
  }
}

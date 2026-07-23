import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/screens/shared/property_detail_screen.dart';

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

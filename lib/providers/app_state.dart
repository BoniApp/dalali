import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/favorite_model.dart';
import 'package:dalali/models/appointment_model.dart';
import 'package:dalali/models/inquiry_model.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/models/review_model.dart';
import 'package:dalali/models/reward_model.dart';
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/models/tenancy_application_model.dart';
import 'package:dalali/models/tenancy_model.dart';
import 'package:dalali/models/move_checklist_model.dart';
import 'package:dalali/models/maintenance_request_model.dart';
import 'package:dalali/models/rent_schedule_model.dart';
import 'package:dalali/models/notification_model.dart';
import 'package:dalali/models/property_registry_model.dart';
import 'package:dalali/models/property_claim_model.dart';
import 'package:dalali/models/deal_model.dart';
import 'package:dalali/models/agency_fee_model.dart';
import 'package:dalali/models/earnings_model.dart';
import 'package:dalali/models/influencer/influencer_model.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/auth_service.dart';
import 'package:dalali/services/notification_service.dart';
import 'package:dalali/services/safety_engine.dart';
import 'package:dalali/services/earnings_service.dart';
import 'package:dalali/services/influencer/influencer_service.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  UserModel? currentUser;
  InfluencerModel? influencerProfile;
  List<PropertyModel> _properties = [];
  List<PropertyModel> _myProperties = [];
  List<FavoriteModel> _favorites = [];
  List<AppointmentModel> _appointments = [];
  List<InquiryModel> _inquiries = [];
  List<MoveListingModel> _moveListings = [];
  List<ReviewModel> _reviews = [];
  List<RewardModel> _rewards = [];
  List<NeighbourhoodReportModel> _neighbourhoodReports = [];
  List<TenancyApplicationModel> _tenancyApplications = [];
  List<TenancyModel> _tenancies = [];
  final List<MoveChecklistModel> _moveChecklists = [];
  List<MaintenanceRequestModel> _maintenanceRequests = [];
  List<RentScheduleModel> _rentSchedules = [];
  List<NotificationModel> _notifications = [];

  // ═══ New Architecture Fields ═══════════════════════════════
  final List<PropertyRegistryModel> _propertyRegistry = [];
  List<PropertyClaimModel> _myClaims = [];
  List<DealModel> _myDeals = [];
  List<AgencyFeeModel> _myAgencyFees = [];
  List<EarningsEntryModel> _myEarnings = [];

  final AuthService _authService = AuthService();
  final DataService _data = DataService();

  // Database stream subscriptions (cancelled on logout)
  final List<StreamSubscription> _subscriptions = [];

  // App lifecycle (drives whether new notifications post a device alert
  // or just update the in-app bell) and badge-sync bookkeeping.
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _notificationsPrimed = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribeFromDatabase();
    super.dispose();
  }

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    _authService.authStateChanges.listen((AuthState state) async {
      final user = state.session?.user;
      if (user != null) {
        // Load user profile from database
        final userDoc = await _data.getUserById(user.id);
        if (userDoc != null) {
          currentUser = userDoc;
        } else {
          currentUser = UserModel(
            id: user.id,
            fullName: user.userMetadata?['full_name'] ?? 'User',
            email: user.email ?? '',
            phone: user.phone ?? '',
            role: UserRole.seeker,
            createdAt: DateTime.now(),
          );
        }
        // Load influencer profile (if any) alongside the user profile
        try {
          influencerProfile =
              await InfluencerService().getInfluencerProfile(currentUser!.id);
        } catch (e) {
          debugPrint('getInfluencerProfile error: $e');
          influencerProfile = null;
        }
        _subscribeToDatabase();
        notifyListeners();
      }
    });
  }

  List<PropertyModel> get properties => _properties;
  List<FavoriteModel> get favorites => _favorites;
  List<AppointmentModel> get appointments => _appointments;
  List<InquiryModel> get inquiries => _inquiries;
  List<MoveListingModel> get moveListings => _moveListings;
  List<ReviewModel> get reviews => _reviews;
  List<RewardModel> get rewards => _rewards;
  List<NeighbourhoodReportModel> get neighbourhoodReports => _neighbourhoodReports;
  List<TenancyApplicationModel> get tenancyApplications => _tenancyApplications;
  List<TenancyModel> get tenancies => _tenancies;
  List<MoveChecklistModel> get moveChecklists => _moveChecklists;
  List<MaintenanceRequestModel> get maintenanceRequests => _maintenanceRequests;
  List<RentScheduleModel> get rentSchedules => _rentSchedules;
  List<NotificationModel> get notifications => _notifications;

  // ═══ New Architecture Getters ══════════════════════════════
  List<PropertyRegistryModel> get propertyRegistry => _propertyRegistry;
  List<PropertyClaimModel> get myClaims => _myClaims;
  List<DealModel> get myDeals => _myDeals;
  List<AgencyFeeModel> get myAgencyFees => _myAgencyFees;
  List<EarningsEntryModel> get myEarnings => _myEarnings;

  EarningsSummaryModel get earningsSummary =>
      EarningsService().computeSummary(_myEarnings);

  int get unreadNotificationCount {
    return _notifications.where((n) => !n.isRead).length;
  }

  // ─── Tenancy Lifecycle Getters ──────────────────────────────

  List<TenancyApplicationModel> get myTenancyApplications {
    if (currentUser == null) return [];
    return _tenancyApplications.where((a) => a.tenantId == currentUser!.id).toList();
  }

  List<TenancyApplicationModel> get pendingApplicationsForLandlord {
    if (currentUser == null) return [];
    return _tenancyApplications.where((a) =>
      a.landlordId == currentUser!.id && a.status == ApplicationStatus.pending).toList();
  }

  List<TenancyModel> get myTenancies {
    if (currentUser == null) return [];
    return _tenancies.where((t) => t.tenantId == currentUser!.id).toList();
  }

  List<TenancyModel> get landlordTenancies {
    if (currentUser == null) return [];
    return _tenancies.where((t) => t.landlordId == currentUser!.id).toList();
  }

  List<MaintenanceRequestModel> get myMaintenanceRequests {
    if (currentUser == null) return [];
    return _maintenanceRequests.where((r) => r.tenantId == currentUser!.id).toList();
  }

  List<MaintenanceRequestModel> get landlordMaintenanceRequests {
    if (currentUser == null) return [];
    return _maintenanceRequests.where((r) => r.landlordId == currentUser!.id).toList();
  }

  List<RentScheduleModel> get myRentSchedules {
    if (currentUser == null) return [];
    return _rentSchedules.where((r) => r.tenantId == currentUser!.id).toList();
  }

  MoveChecklistModel? getMyChecklist(String tenancyId) {
    if (currentUser == null) return null;
    try {
      return _moveChecklists.firstWhere((c) =>
        c.userId == currentUser!.id && c.tenancyId == tenancyId);
    } catch (_) {
      return null;
    }
  }

  List<PropertyModel> get featuredProperties =>
      _properties.where((p) => p.listingType == ListingType.featured && p.status == PropertyStatus.available).toList();

  List<PropertyModel> get landlordProperties {
    return _myProperties;
  }

  List<PropertyModel> get favoriteProperties {
    if (currentUser == null) return [];
    final favIds = _favorites
        .where((f) => f.userId == currentUser!.id)
        .map((f) => f.propertyId)
        .toSet();
    return _properties.where((p) => favIds.contains(p.id)).toList();
  }

  List<AppointmentModel> get userAppointments {
    if (currentUser == null) return [];
    if (currentUser!.role == UserRole.landlord || currentUser!.role == UserRole.agent) {
      return _appointments.where((a) => a.landlordId == currentUser!.id).toList();
    }
    return _appointments.where((a) => a.seekerId == currentUser!.id).toList();
  }

  List<InquiryModel> get landlordInquiries {
    if (currentUser == null) return [];
    return _inquiries.where((i) => i.landlordId == currentUser!.id).toList();
  }

  List<MoveListingModel> get activeMoveListings =>
      _moveListings.where((m) => m.status == MoveStatus.planning || m.status == MoveStatus.active).toList();

  List<MoveListingModel> get myMoveListings {
    if (currentUser == null) return [];
    return _moveListings.where((m) => m.userId == currentUser!.id).toList();
  }

  List<ReviewModel> get reviewsForCurrentLandlord {
    if (currentUser == null) return [];
    final myPropertyIds = _properties.where((p) => p.landlordId == currentUser!.id).map((p) => p.id).toSet();
    return _reviews.where((r) => myPropertyIds.contains(r.propertyId)).toList();
  }

  List<NeighbourhoodReportModel> get activeNeighbourhoodReports =>
      _neighbourhoodReports.where((r) => !r.resolved).toList();

  List<RewardModel> get myRewards {
    if (currentUser == null) return [];
    return _rewards.where((r) => r.userId == currentUser!.id).toList();
  }

  int get myTotalPoints {
    if (currentUser == null) return 0;
    return _rewards
        .where((r) => r.userId == currentUser!.id && r.claimed)
        .fold(0, (sum, r) => sum + r.points);
  }

  /// Persists a new profile picture URL and refreshes the local user.
  Future<void> updateProfileImage(String imageUrl) async {
    final user = currentUser;
    if (user == null) return;
    await _data.updateUserProfileImage(user.id, imageUrl);
    currentUser = user.copyWith(profileImage: imageUrl);
    notifyListeners();
  }

  /// Re-fetches the current user row — e.g. after the server
  /// updates verification_status during KYC completion.
  Future<void> refreshCurrentUser() async {
    final user = currentUser;
    if (user == null) return;
    final fresh = await _data.getUserById(user.id);
    if (fresh != null) {
      currentUser = fresh;
      notifyListeners();
    }
  }

  /// Re-fetch all realtime subscriptions (pull-to-refresh).
  /// Re-subscribing re-queries every table; completes once the
  /// properties feed has delivered fresh data (5s timeout fallback
  /// so the refresh spinner never hangs).
  Future<void> refreshData() async {
    if (currentUser == null) return;
    final delivered = Completer<void>();
    final probe = _data.getProperties(limit: 100).listen((_) {
      if (!delivered.isCompleted) delivered.complete();
    }, onError: (_) {
      if (!delivered.isCompleted) delivered.complete();
    });
    _subscribeToDatabase();
    await delivered.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    await probe.cancel();
  }

  bool isFavorite(String propertyId) {
    if (currentUser == null) return false;
    return _favorites.any((f) => f.userId == currentUser!.id && f.propertyId == propertyId);
  }

  void toggleFavorite(String propertyId) {
    if (currentUser == null) return;
    final existing = _favorites.indexWhere(
      (f) => f.userId == currentUser!.id && f.propertyId == propertyId,
    );
    if (existing >= 0) {
      _favorites.removeAt(existing);
      _data.removeFavorite(currentUser!.id, propertyId).catchError((e) {
        debugPrint('removeFavorite error: $e');
      });
    } else {
      _favorites.add(FavoriteModel(
        id: 'f${DateTime.now().millisecondsSinceEpoch}',
        userId: currentUser!.id,
        propertyId: propertyId,
        createdAt: DateTime.now(),
      ));
      _data.addFavorite(currentUser!.id, propertyId).catchError((e) {
        debugPrint('addFavorite error: $e');
      });
    }
    notifyListeners();
  }

  void logout() {
    _authService.signOut();
    _unsubscribeFromDatabase();
    currentUser = null;
    _notifications = [];
    _notificationsPrimed = false;
    NotificationService.updateAppBadge(0);
    NotificationService.cancelNewNotificationsAlert();
    notifyListeners();
  }

  // ─── Database Stream Subscriptions ──────────────────────────

  void _subscribeToDatabase() {
    if (currentUser == null) return;
    _unsubscribeFromDatabase();
    _notificationsPrimed = false;
    final isLandlord = currentUser!.role == UserRole.landlord || currentUser!.role == UserRole.agent;

    // Properties (public feed: approved + available only)
    _subscriptions.add(_data.getProperties(limit: 100).listen((list) {
      _properties = list;
      _recomputeSafetyScores();
      notifyListeners();
    }));

    // Landlord's own properties (all statuses, approval states)
    if (isLandlord) {
      _subscriptions.add(_data.getMyProperties(currentUser!.id, limit: 100).listen((list) {
        _myProperties = list;
        notifyListeners();
      }));
    }

    // Favorites
    _subscriptions.add(_data.getFavoritePropertyIds(currentUser!.id).listen((ids) {
      _favorites = ids.map((id) => FavoriteModel(
        id: 'f_$id',
        userId: currentUser!.id,
        propertyId: id,
        createdAt: DateTime.now(),
      )).toList();
      notifyListeners();
    }));

    // Appointments
    _subscriptions.add(_data.getAppointments(currentUser!.id, isLandlord: isLandlord).listen((list) {
      _appointments = list;
      notifyListeners();
    }));

    // Inquiries (landlord sees enquiries for their properties; seeker sees their own)
    if (isLandlord) {
      _subscriptions.add(_data.getInquiriesForLandlord(currentUser!.id).listen((list) {
        _inquiries = list;
        notifyListeners();
      }));
    } else {
      _subscriptions.add(_data.getInquiriesForSeeker(currentUser!.id).listen((list) {
        _inquiries = list;
        notifyListeners();
      }));
    }

    // Reviews
    _subscriptions.add(_data.getReviews(limit: 100).listen((list) {
      _reviews = list.cast<ReviewModel>();
      notifyListeners();
    }));

    // Move listings
    _subscriptions.add(_data.getMoveListingsByUser(currentUser!.id).listen((list) {
      _moveListings = list.cast<MoveListingModel>();
      notifyListeners();
    }));

    // Rewards
    _subscriptions.add(_data.getRewardsForUser(currentUser!.id).listen((list) {
      _rewards = list.cast<RewardModel>();
      notifyListeners();
    }));

    // Neighbourhood reports
    _subscriptions.add(_data.getNeighbourhoodReports(limit: 200).listen((list) {
      _neighbourhoodReports = list.cast<NeighbourhoodReportModel>();
      _recomputeSafetyScores();
      notifyListeners();
    }));

    // Tenancy Applications
    if (isLandlord) {
      _subscriptions.add(_data.getApplicationsForLandlord(currentUser!.id).listen((list) {
        _tenancyApplications = list.cast<TenancyApplicationModel>();
        notifyListeners();
      }));
    } else {
      _subscriptions.add(_data.getApplicationsForTenant(currentUser!.id).listen((list) {
        _tenancyApplications = list.cast<TenancyApplicationModel>();
        notifyListeners();
      }));
    }

    // Tenancies
    if (isLandlord) {
      _subscriptions.add(_data.getTenanciesForLandlord(currentUser!.id).listen((list) {
        _tenancies = list.cast<TenancyModel>();
        notifyListeners();
      }));
    } else {
      _subscriptions.add(_data.getTenanciesForTenant(currentUser!.id).listen((list) {
        _tenancies = list.cast<TenancyModel>();
        notifyListeners();
      }));
    }

    // Maintenance Requests
    if (isLandlord) {
      _subscriptions.add(_data.getMaintenanceForLandlord(currentUser!.id).listen((list) {
        _maintenanceRequests = list.cast<MaintenanceRequestModel>();
        notifyListeners();
      }));
    } else {
      _subscriptions.add(_data.getMaintenanceForTenant(currentUser!.id).listen((list) {
        _maintenanceRequests = list.cast<MaintenanceRequestModel>();
        notifyListeners();
      }));
    }

    // Rent Schedules
    if (isLandlord) {
      _subscriptions.add(_data.getRentSchedulesForLandlord(currentUser!.id).listen((list) {
        _rentSchedules = list;
        notifyListeners();
      }));
    } else {
      _subscriptions.add(_data.getRentSchedulesForTenant(currentUser!.id).listen((list) {
        _rentSchedules = list;
        notifyListeners();
      }));
    }

    // Move Checklists (tenant-owned; landlords simply get none)
    _subscriptions.add(_data.getMoveChecklistsForUser(currentUser!.id).listen((list) {
      _moveChecklists
        ..clear()
        ..addAll(list);
      notifyListeners();
    }));

    // Notifications
    _subscriptions.add(_data.getNotificationsForUser(currentUser!.id).listen((list) {
      final previousIds = _notifications.map((n) => n.id).toSet();
      final primed = _notificationsPrimed;
      _notifications = list;
      _notificationsPrimed = true;
      _syncNotificationBadge(previousIds: primed ? previousIds : null);
      notifyListeners();
    }));

    // ═══ New Architecture Subscriptions ═══════════════════════

    // Deals (for listing creators)
    _subscriptions.add(_data.getDealsForUser(currentUser!.id).listen((list) {
      _myDeals = list.cast<DealModel>();
      notifyListeners();
    }));

    // Agency Fees
    _subscriptions.add(_data.getAgencyFeesForUser(currentUser!.id).listen((list) {
      _myAgencyFees = list.cast<AgencyFeeModel>();
      notifyListeners();
    }));

    // Earnings
    _subscriptions.add(_data.getEarningsForUser(currentUser!.id).listen((list) {
      _myEarnings = list.cast<EarningsEntryModel>();
      notifyListeners();
    }));

    // Property Claims
    _subscriptions.add(_data.getClaimsForUser(currentUser!.id).listen((list) {
      _myClaims = list.cast<PropertyClaimModel>();
      notifyListeners();
    }));

    // Influencer profile (influencer role or existing profile only)
    if (currentUser!.role == UserRole.influencer || influencerProfile != null) {
      _subscriptions.add(
          InfluencerService().watchInfluencerProfile(currentUser!.id).listen((profile) {
        influencerProfile = profile;
        notifyListeners();
      }));
    }
  }

  void _unsubscribeFromDatabase() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _myProperties = [];
    _myDeals = [];
    _myAgencyFees = [];
    _myEarnings = [];
    _myClaims = [];
    influencerProfile = null;
  }

  /// Keeps the launcher-icon badge/dot aligned with unread notifications.
  /// iOS gets the numeric badge via NotificationService.updateAppBadge;
  /// Android shows a launcher dot while the summary alert (id
  /// NotificationService.newNotificationsId) is posted, cancelled when
  /// everything is read. A device alert is only posted for genuinely new
  /// rows while the app is backgrounded — the in-app bell covers the
  /// foreground case. [previousIds] is null on the first stream emission
  /// (initial sync), which never posts an alert.
  void _syncNotificationBadge({Set<String>? previousIds}) {
    final unread = unreadNotificationCount;
    NotificationService.updateAppBadge(unread);
    if (unread == 0) {
      NotificationService.cancelNewNotificationsAlert();
      return;
    }
    if (previousIds == null || _lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final fresh = _notifications
        .where((n) => !n.isRead && !previousIds.contains(n.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (fresh.isEmpty) return;
    NotificationService.showLocalNotification(
      id: NotificationService.newNotificationsId,
      title: fresh.first.title,
      body: fresh.length > 1
          ? '${fresh.first.body} (+${fresh.length - 1} more)'
          : fresh.first.body,
      badgeNumber: unread,
    );
  }

  // ─── Move Engine (Demo Mode) ────────────────────────────────

  void startMove(MoveListingModel move) {
    _moveListings.add(move);
    if (currentUser != null) {
      currentUser = currentUser!.copyWith(
        moveMode: MoveMode.planning,
        activeMoveListingId: move.id,
      );
    }
    notifyListeners();
  }

  void activateMove(String moveId) {
    final idx = _moveListings.indexWhere((m) => m.id == moveId);
    if (idx >= 0) {
      _moveListings[idx] = _moveListings[idx].copyWith(status: MoveStatus.active);
      if (currentUser != null) {
        currentUser = currentUser!.copyWith(moveMode: MoveMode.active);
      }
      notifyListeners();
    }
  }

  void completeMove(String moveId, String newPropertyId) {
    final idx = _moveListings.indexWhere((m) => m.id == moveId);
    if (idx >= 0) {
      _moveListings[idx] = _moveListings[idx].copyWith(
        status: MoveStatus.completed,
        newPropertyId: newPropertyId,
      );
      if (currentUser != null) {
        currentUser = currentUser!.copyWith(
          moveMode: MoveMode.none,
          activeMoveListingId: null,
        );
      }
      notifyListeners();
    }
  }

  void cancelMove(String moveId) {
    final idx = _moveListings.indexWhere((m) => m.id == moveId);
    if (idx >= 0) {
      _moveListings[idx] = _moveListings[idx].copyWith(status: MoveStatus.cancelled);
      if (currentUser != null) {
        currentUser = currentUser!.copyWith(
          moveMode: MoveMode.none,
          activeMoveListingId: null,
        );
      }
      notifyListeners();
    }
  }

  // ─── Reviews ────────────────────────────────────────────────

  void addReview(ReviewModel review) {
    _reviews.add(review);
    _data.addReview(review).catchError((e) {
      debugPrint('addReview error: $e');
    });
    // Update property review count + average rating (simplified)
    final pIdx = _properties.indexWhere((p) => p.id == review.propertyId);
    if (pIdx >= 0) {
      final old = _properties[pIdx];
      final newCount = old.reviewCount + 1;
      final newRating = ((old.rating * old.reviewCount) + review.overallScore) / newCount;
      _properties[pIdx] = old.copyWith(
        reviewCount: newCount,
        rating: newRating,
      );
      _data.updateProperty(_properties[pIdx]).catchError((e) {
        debugPrint('updateProperty error: $e');
      });
    }
    notifyListeners();
  }

  // ─── Neighbourhood Reports ──────────────────────────────────

  void addNeighbourhoodReport(NeighbourhoodReportModel report) {
    _neighbourhoodReports.add(report);
    _data.addNeighbourhoodReport(report).catchError((e) {
      debugPrint('addNeighbourhoodReport error: $e');
    });
    // Recompute safety scores for nearby properties
    _recomputeSafetyScores();
    notifyListeners();
  }

  void resolveNeighbourhoodReport(String reportId) {
    final idx = _neighbourhoodReports.indexWhere((r) => r.id == reportId);
    if (idx >= 0) {
      _neighbourhoodReports[idx] = _neighbourhoodReports[idx].copyWith(
        resolved: true,
        resolvedAt: DateTime.now(),
      );
      _recomputeSafetyScores();
      notifyListeners();
    }
  }

  void _recomputeSafetyScores() {
    // Simple client-side recompute for demo mode
    final engine = SafetyEngine();
    for (var i = 0; i < _properties.length; i++) {
      final p = _properties[i];
      final nearby = engine.filterNearby(
        latitude: p.latitude,
        longitude: p.longitude,
        allReports: _neighbourhoodReports,
      );
      final score = engine.computeSafetyScore(property: p, nearbyReports: nearby);
      final count = engine.countActiveIncidents(property: p, nearbyReports: nearby);
      _properties[i] = p.copyWith(safetyScore: score, incidentCount: count);
    }
  }

  // ─── Rewards ────────────────────────────────────────────────

  // ─── Tenancy Lifecycle Mutations ────────────────────────────
  //
  // These methods write the status field only. All side effects —
  // landlord/tenant notifications, tenancy creation on approval,
  // property reservation/occupancy/re-listing — are handled by
  // migration 019 server-side triggers; the realtime streams
  // reconcile local state.

  void applyForTenancy(TenancyApplicationModel application) {
    _tenancyApplications.add(application);
    _data.addTenancyApplication(application).catchError((e) {
      debugPrint('addTenancyApplication error: $e');
    });
    notifyListeners();
  }

  void approveApplication(String applicationId) {
    final idx = _tenancyApplications.indexWhere((a) => a.id == applicationId);
    if (idx >= 0) {
      final app = _tenancyApplications[idx];
      _tenancyApplications[idx] = app.copyWith(
        status: ApplicationStatus.approved,
        resolvedAt: DateTime.now(),
      );
      _data.updateApplicationStatus(applicationId, ApplicationStatus.approved).catchError((e) {
        debugPrint('updateApplicationStatus error: $e');
      });
      notifyListeners();
    }
  }

  void rejectApplication(String applicationId, {String? reason}) {
    final idx = _tenancyApplications.indexWhere((a) => a.id == applicationId);
    if (idx >= 0) {
      final app = _tenancyApplications[idx];
      _tenancyApplications[idx] = app.copyWith(
        status: ApplicationStatus.rejected,
        resolvedAt: DateTime.now(),
        notes: reason,
      );
      _data.updateApplicationStatus(applicationId, ApplicationStatus.rejected, notes: reason).catchError((e) {
        debugPrint('updateApplicationStatus error: $e');
      });
      notifyListeners();
    }
  }

  void activateTenancy(String tenancyId) {
    final idx = _tenancies.indexWhere((t) => t.id == tenancyId);
    if (idx >= 0) {
      final t = _tenancies[idx];
      _tenancies[idx] = t.copyWith(
        status: TenancyStatus.active,
        activatedAt: DateTime.now(),
      );
      _data.updateTenancyStatus(tenancyId, TenancyStatus.active).catchError((e) {
        debugPrint('updateTenancyStatus error: $e');
      });
      notifyListeners();
    }
  }

  void completeTenancy(String tenancyId) {
    final idx = _tenancies.indexWhere((t) => t.id == tenancyId);
    if (idx >= 0) {
      final t = _tenancies[idx];
      _tenancies[idx] = t.copyWith(
        status: TenancyStatus.completed,
        completedAt: DateTime.now(),
      );
      _data.updateTenancyStatus(tenancyId, TenancyStatus.completed).catchError((e) {
        debugPrint('updateTenancyStatus error: $e');
      });
      notifyListeners();
    }
  }

  /// Relist a property that left the market (status 'unlisted' after a
  /// tenancy ended — see migration 021). Explicit landlord action; the
  /// server never auto-relists.
  void relistProperty(String propertyId) {
    final idx = _myProperties.indexWhere((p) => p.id == propertyId);
    if (idx >= 0) {
      _myProperties[idx] = _myProperties[idx].copyWith(status: PropertyStatus.available);
    }
    _data.updatePropertyStatus(propertyId, PropertyStatus.available).catchError((e) {
      debugPrint('relistProperty error: $e');
    });
    notifyListeners();
  }

  void addMaintenanceRequest(MaintenanceRequestModel request) {
    _maintenanceRequests.add(request);
    _data.addMaintenanceRequest(request).catchError((e) {
      debugPrint('addMaintenanceRequest error: $e');
    });
    // Notify landlord
    NotificationService.notifyUser(
      userId: request.landlordId,
      type: NotificationType.maintenanceUpdate,
      title: 'New Maintenance Request',
      body: '${request.tenantName} reported: ${request.description}',
      targetId: request.id,
      targetCollection: 'maintenance_requests',
    ).catchError((e) => debugPrint('notifyUser error: $e'));
    notifyListeners();
  }

  void updateMaintenanceStatus(String requestId, MaintenanceStatus status, {String? resolutionNotes}) {
    final idx = _maintenanceRequests.indexWhere((r) => r.id == requestId);
    if (idx >= 0) {
      final request = _maintenanceRequests[idx];
      _maintenanceRequests[idx] = request.copyWith(
        status: status,
        resolvedAt: status == MaintenanceStatus.resolved ? DateTime.now() : null,
        resolutionNotes: resolutionNotes,
      );
      _data.updateMaintenanceStatus(requestId, status, resolutionNotes: resolutionNotes).catchError((e) {
        debugPrint('updateMaintenanceStatus error: $e');
      });
      if (status == MaintenanceStatus.resolved) {
        NotificationService.notifyUser(
          userId: request.tenantId,
          type: NotificationType.maintenanceUpdate,
          title: 'Maintenance Resolved',
          body: 'Your request for ${request.propertyTitle} has been resolved.',
          targetId: request.id,
          targetCollection: 'maintenance_requests',
        ).catchError((e) => debugPrint('notifyUser error: $e'));
      }
      notifyListeners();
    }
  }

  void markRentPaid(String scheduleId) {
    final idx = _rentSchedules.indexWhere((r) => r.id == scheduleId);
    if (idx >= 0) {
      _rentSchedules[idx] = RentScheduleModel(
        id: _rentSchedules[idx].id,
        tenancyId: _rentSchedules[idx].tenancyId,
        tenantId: _rentSchedules[idx].tenantId,
        propertyTitle: _rentSchedules[idx].propertyTitle,
        dueDate: _rentSchedules[idx].dueDate,
        amount: _rentSchedules[idx].amount,
        status: PaymentStatus.paid,
        paidAt: DateTime.now(),
      );
      _data.markRentPaid(scheduleId).catchError((e) {
        debugPrint('markRentPaid error: $e');
      });
      notifyListeners();
    }
  }

  void toggleChecklistItem(String checklistId, String itemId) {
    final cIdx = _moveChecklists.indexWhere((c) => c.id == checklistId);
    if (cIdx >= 0) {
      final checklist = _moveChecklists[cIdx];
      final items = List<ChecklistItem>.from(checklist.items);
      final iIdx = items.indexWhere((i) => i.id == itemId);
      if (iIdx >= 0) {
        items[iIdx] = items[iIdx].copyWith(
          completed: !items[iIdx].completed,
          completedAt: !items[iIdx].completed ? DateTime.now() : null,
        );
        _moveChecklists[cIdx] = checklist.copyWith(
          items: items,
          updatedAt: DateTime.now(),
        );
        _data.updateMoveChecklist(_moveChecklists[cIdx]).catchError((e) {
          debugPrint('updateMoveChecklist error: $e');
        });
        notifyListeners();
      }
    }
  }

  void addReward(RewardModel reward) {
    _rewards.add(reward);
    if (currentUser != null && reward.userId == currentUser!.id) {
      currentUser = currentUser!.copyWith(
        totalRewardPoints: currentUser!.totalRewardPoints + reward.points,
      );
    }
    notifyListeners();
  }

  void claimReward(String rewardId) {
    final idx = _rewards.indexWhere((r) => r.id == rewardId);
    if (idx >= 0 && !_rewards[idx].claimed) {
      _rewards[idx] = _rewards[idx].copyWith(claimed: true, claimedAt: DateTime.now());
      notifyListeners();
    }
  }

  // ─── Legacy property/appointment/inquiry ────────────────────

  Future<void> addProperty(PropertyModel property) async {
    await _data.addProperty(property);
    _properties.add(property);
    notifyListeners();
  }

  Future<void> updateProperty(PropertyModel property) async {
    final index = _properties.indexWhere((p) => p.id == property.id);
    if (index >= 0) {
      await _data.updateProperty(property);
      _properties[index] = property;
      notifyListeners();
    }
  }

  void addAppointment(AppointmentModel appointment) {
    _appointments.add(appointment);
    _data.addAppointment(appointment).catchError((e) {
      debugPrint('addAppointment error: $e');
    });
    // Notify landlord
    NotificationService.notifyUser(
      userId: appointment.landlordId,
      type: NotificationType.appointment,
      title: 'New Viewing Request',
      body: '${appointment.seekerName} wants to view ${appointment.propertyTitle}',
      targetId: appointment.id,
      targetCollection: 'appointments',
    ).catchError((e) => debugPrint('notifyUser error: $e'));
    notifyListeners();
  }

  void updateAppointmentStatus(String id, AppointmentStatus status) {
    final index = _appointments.indexWhere((a) => a.id == id);
    if (index >= 0) {
      final old = _appointments[index];
      _appointments[index] = AppointmentModel(
        id: old.id,
        propertyId: old.propertyId,
        propertyTitle: old.propertyTitle,
        seekerId: old.seekerId,
        seekerName: old.seekerName,
        seekerPhone: old.seekerPhone,
        landlordId: old.landlordId,
        scheduledDate: old.scheduledDate,
        notes: old.notes,
        status: status,
        createdAt: old.createdAt,
      );
      _data.updateAppointmentStatus(id, status).catchError((e) {
        debugPrint('updateAppointmentStatus error: $e');
      });
      notifyListeners();
    }
  }

  void addInquiry(InquiryModel inquiry) {
    _inquiries.add(inquiry);

    // Increment property inquiry count locally
    final pIdx = _properties.indexWhere((p) => p.id == inquiry.propertyId);
    if (pIdx >= 0) {
      _properties[pIdx] = _properties[pIdx].copyWith(
        inquiryCount: _properties[pIdx].inquiryCount + 1,
      );
    }

    _data.addInquiry(inquiry).catchError((e) {
      debugPrint('addInquiry error: $e');
    });
    // Also sync inquiry count to DB
    if (pIdx >= 0) {
      _data.incrementPropertyInquiryCount(inquiry.propertyId, _properties[pIdx].inquiryCount - 1).catchError((e) {
        debugPrint('incrementPropertyInquiryCount error: $e');
      });
    }
    // Notify landlord
    NotificationService.notifyUser(
      userId: inquiry.landlordId,
      type: NotificationType.inquiry,
      title: 'New Inquiry',
      body: '${inquiry.seekerName}: ${inquiry.message}',
      targetId: inquiry.propertyId,
      targetCollection: 'properties',
    ).catchError((e) => debugPrint('notifyUser error: $e'));
    notifyListeners();
  }

  void markNotificationRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _data.markNotificationRead(id).catchError((e) {
        debugPrint('markNotificationRead error: $e');
      });
      _syncNotificationBadge();
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    if (currentUser == null) return;
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _data.markAllNotificationsRead(currentUser!.id).catchError((e) {
      debugPrint('markAllNotificationsRead error: $e');
    });
    _syncNotificationBadge();
    notifyListeners();
  }

  void markInquiryRead(String id) {
    final index = _inquiries.indexWhere((i) => i.id == id);
    if (index >= 0) {
      final old = _inquiries[index];
      _inquiries[index] = InquiryModel(
        id: old.id,
        propertyId: old.propertyId,
        propertyTitle: old.propertyTitle,
        seekerId: old.seekerId,
        seekerName: old.seekerName,
        seekerPhone: old.seekerPhone,
        landlordId: old.landlordId,
        message: old.message,
        createdAt: old.createdAt,
        isRead: true,
      );
      _data.markInquiryRead(id).catchError((e) {
        debugPrint('markInquiryRead error: $e');
      });
      notifyListeners();
    }
  }
}

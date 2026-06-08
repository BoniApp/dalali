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
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/auth_service.dart';
import 'package:dalali/services/safety_engine.dart';

enum AuthMode { supabase }

class AppState extends ChangeNotifier {
  AuthMode _authMode = AuthMode.supabase;
  UserModel? currentUser;
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
  List<MoveChecklistModel> _moveChecklists = [];
  List<MaintenanceRequestModel> _maintenanceRequests = [];
  List<RentScheduleModel> _rentSchedules = [];

  final AuthService _authService = AuthService();
  final DataService _data = DataService();

  // Database stream subscriptions (cancelled on logout)
  final List<StreamSubscription> _subscriptions = [];

  AuthMode get authMode => _authMode;

  AppState() {
    _authService.authStateChanges.listen((AuthState state) async {
      final user = state.session?.user;
      if (user != null) {
        _authMode = AuthMode.supabase;
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
      if (_isFirebase) {
        _data.removeFavorite(currentUser!.id, propertyId).catchError((e) {
          print('removeFavorite error: $e');
        });
      }
    } else {
      _favorites.add(FavoriteModel(
        id: 'f${DateTime.now().millisecondsSinceEpoch}',
        userId: currentUser!.id,
        propertyId: propertyId,
        createdAt: DateTime.now(),
      ));
      if (_isFirebase) {
        _data.addFavorite(currentUser!.id, propertyId).catchError((e) {
          print('addFavorite error: $e');
        });
      }
    }
    notifyListeners();
  }

  void logout() {
    _authService.signOut();
    _unsubscribeFromDatabase();
    currentUser = null;
    notifyListeners();
  }

  // ─── Database Stream Subscriptions ──────────────────────────

  void _subscribeToDatabase() {
    if (currentUser == null) return;
    _unsubscribeFromDatabase();
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
    _subscriptions.add(_data.getRentSchedulesForTenant(currentUser!.id).listen((list) {
      _rentSchedules = list.cast<RentScheduleModel>();
      notifyListeners();
    }));
  }

  void _unsubscribeFromDatabase() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _myProperties = [];
  }

  bool get _isFirebase => _authMode == AuthMode.supabase;

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
    if (_isFirebase) {
      _data.addReview(review).catchError((e) {
        print('addReview error: $e');
      });
    }
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
      if (_isFirebase) {
        _data.updateProperty(_properties[pIdx]).catchError((e) {
          print('updateProperty error: $e');
        });
      }
    }
    notifyListeners();
  }

  // ─── Neighbourhood Reports ──────────────────────────────────

  void addNeighbourhoodReport(NeighbourhoodReportModel report) {
    _neighbourhoodReports.add(report);
    if (_isFirebase) {
      _data.addNeighbourhoodReport(report).catchError((e) {
        print('addNeighbourhoodReport error: $e');
      });
    }
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

  void applyForTenancy(TenancyApplicationModel application) {
    _tenancyApplications.add(application);
    if (_isFirebase) {
      _data.addTenancyApplication(application).catchError((e) {
        print('addTenancyApplication error: $e');
      });
    }
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
      if (_isFirebase) {
        _data.updateApplicationStatus(applicationId, ApplicationStatus.approved).catchError((e) {
          print('updateApplicationStatus error: $e');
        });
      }
      // Create tenancy record
      final property = _properties.firstWhere((p) => p.id == app.propertyId);
      final tenancy = TenancyModel(
        id: 't${DateTime.now().millisecondsSinceEpoch}',
        tenantId: app.tenantId,
        tenantName: app.tenantName,
        landlordId: app.landlordId,
        landlordName: app.landlordName,
        propertyId: app.propertyId,
        propertyTitle: app.propertyTitle,
        propertyLocation: property.location,
        moveInDate: DateTime.now().add(const Duration(days: 14)),
        expectedMoveOutDate: DateTime.now().add(const Duration(days: 374)),
        rentAmount: property.rentPrice,
        depositAmount: property.rentPrice * 2,
        status: TenancyStatus.upcoming,
        createdAt: DateTime.now(),
      );
      _tenancies.add(tenancy);
      if (_isFirebase) {
        _data.addTenancy(tenancy).catchError((e) {
          print('addTenancy error: $e');
        });
      }
      // Mark property reserved
      final pIdx = _properties.indexWhere((p) => p.id == app.propertyId);
      if (pIdx >= 0) {
        _properties[pIdx] = property.copyWith(status: PropertyStatus.pending);
        if (_isFirebase) {
          _data.updateProperty(_properties[pIdx]).catchError((e) {
            print('updateProperty error: $e');
          });
        }
      }
      notifyListeners();
    }
  }

  void rejectApplication(String applicationId, {String? reason}) {
    final idx = _tenancyApplications.indexWhere((a) => a.id == applicationId);
    if (idx >= 0) {
      _tenancyApplications[idx] = _tenancyApplications[idx].copyWith(
        status: ApplicationStatus.rejected,
        resolvedAt: DateTime.now(),
        notes: reason,
      );
      if (_isFirebase) {
        _data.updateApplicationStatus(applicationId, ApplicationStatus.rejected).catchError((e) {
          print('updateApplicationStatus error: $e');
        });
      }
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
      if (_isFirebase) {
        _data.updateTenancyStatus(tenancyId, TenancyStatus.active).catchError((e) {
          print('updateTenancyStatus error: $e');
        });
      }
      // Mark property occupied
      final pIdx = _properties.indexWhere((p) => p.id == t.propertyId);
      if (pIdx >= 0) {
        _properties[pIdx] = _properties[pIdx].copyWith(status: PropertyStatus.occupied);
        if (_isFirebase) {
          _data.updateProperty(_properties[pIdx]).catchError((e) {
            print('updateProperty error: $e');
          });
        }
      }
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
      if (_isFirebase) {
        _data.updateTenancyStatus(tenancyId, TenancyStatus.completed).catchError((e) {
          print('updateTenancyStatus error: $e');
        });
      }
      // Mark property available again
      final pIdx = _properties.indexWhere((p) => p.id == t.propertyId);
      if (pIdx >= 0) {
        _properties[pIdx] = _properties[pIdx].copyWith(status: PropertyStatus.available);
        if (_isFirebase) {
          _data.updateProperty(_properties[pIdx]).catchError((e) {
            print('updateProperty error: $e');
          });
        }
      }
      notifyListeners();
    }
  }

  void addMaintenanceRequest(MaintenanceRequestModel request) {
    _maintenanceRequests.add(request);
    if (_isFirebase) {
      _data.addMaintenanceRequest(request).catchError((e) {
        print('addMaintenanceRequest error: $e');
      });
    }
    notifyListeners();
  }

  void updateMaintenanceStatus(String requestId, MaintenanceStatus status, {String? resolutionNotes}) {
    final idx = _maintenanceRequests.indexWhere((r) => r.id == requestId);
    if (idx >= 0) {
      _maintenanceRequests[idx] = _maintenanceRequests[idx].copyWith(
        status: status,
        resolvedAt: status == MaintenanceStatus.resolved ? DateTime.now() : null,
        resolutionNotes: resolutionNotes,
      );
      if (_isFirebase) {
        _data.updateMaintenanceStatus(requestId, status, resolutionNotes: resolutionNotes).catchError((e) {
          print('updateMaintenanceStatus error: $e');
        });
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
      if (_isFirebase) {
        _data.markRentPaid(scheduleId).catchError((e) {
          print('markRentPaid error: $e');
        });
      }
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
    if (_isFirebase) {
      await _data.addProperty(property);
    }
    _properties.add(property);
    notifyListeners();
  }

  Future<void> updateProperty(PropertyModel property) async {
    final index = _properties.indexWhere((p) => p.id == property.id);
    if (index >= 0) {
      if (_isFirebase) {
        await _data.updateProperty(property);
      }
      _properties[index] = property;
      notifyListeners();
    }
  }

  void addAppointment(AppointmentModel appointment) {
    _appointments.add(appointment);
    if (_isFirebase) {
      _data.addAppointment(appointment).catchError((e) {
        print('addAppointment error: $e');
      });
    }
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
      if (_isFirebase) {
        _data.updateAppointmentStatus(id, status).catchError((e) {
          print('updateAppointmentStatus error: $e');
        });
      }
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

    if (_isFirebase) {
      _data.addInquiry(inquiry).catchError((e) {
        debugPrint('addInquiry error: $e');
      });
      // Also sync inquiry count to DB
      if (pIdx >= 0) {
        _data.incrementPropertyInquiryCount(inquiry.propertyId, _properties[pIdx].inquiryCount - 1).catchError((e) {
          debugPrint('incrementPropertyInquiryCount error: $e');
        });
      }
    }
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
      if (_isFirebase) {
        _data.markInquiryRead(id).catchError((e) {
          print('markInquiryRead error: $e');
        });
      }
      notifyListeners();
    }
  }
}

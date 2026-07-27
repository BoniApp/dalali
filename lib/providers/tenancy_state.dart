import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/tenancy_application_model.dart';
import 'package:dalali/models/tenancy_model.dart';
import 'package:dalali/models/move_checklist_model.dart';
import 'package:dalali/models/maintenance_request_model.dart';
import 'package:dalali/models/rent_schedule_model.dart';
import 'package:dalali/models/inspection_model.dart';
import 'package:dalali/models/deposit_transaction_model.dart';
import 'package:dalali/services/data_service.dart';

/// Tenancy lifecycle: applications, tenancies, maintenance requests,
/// rent schedules and move checklists. All side effects (notifications,
/// tenancy creation on approval, property status changes) are
/// server-trigger-owned (migration 019) — these methods only write the
/// status field; the realtime streams reconcile local state.
class TenancyState extends ChangeNotifier {
  List<TenancyApplicationModel> _tenancyApplications = [];
  List<TenancyModel> _tenancies = [];
  final List<MoveChecklistModel> _moveChecklists = [];
  List<MaintenanceRequestModel> _maintenanceRequests = [];
  List<RentScheduleModel> _rentSchedules = [];
  List<InspectionModel> _inspections = [];
  List<DepositTransactionModel> _depositTransactions = [];

  final DataService _data = DataService();
  final List<StreamSubscription> _subscriptions = [];
  String? _lastUserId;
  UserModel? _currentUser;

  List<TenancyApplicationModel> get tenancyApplications => _tenancyApplications;
  List<TenancyModel> get tenancies => _tenancies;
  List<MoveChecklistModel> get moveChecklists => _moveChecklists;
  List<MaintenanceRequestModel> get maintenanceRequests => _maintenanceRequests;
  List<RentScheduleModel> get rentSchedules => _rentSchedules;
  List<InspectionModel> get inspections => _inspections;
  List<DepositTransactionModel> get depositTransactions => _depositTransactions;

  List<TenancyApplicationModel> myTenancyApplicationsFor(String? userId) {
    if (userId == null) return [];
    return _tenancyApplications.where((a) => a.tenantId == userId).toList();
  }

  List<TenancyApplicationModel> pendingApplicationsForLandlordFor(String? userId) {
    if (userId == null) return [];
    return _tenancyApplications
        .where((a) => a.landlordId == userId && a.status == ApplicationStatus.pending)
        .toList();
  }

  List<TenancyModel> myTenanciesFor(String? userId) {
    if (userId == null) return [];
    return _tenancies.where((t) => t.tenantId == userId).toList();
  }

  List<TenancyModel> landlordTenanciesFor(String? userId) {
    if (userId == null) return [];
    return _tenancies.where((t) => t.landlordId == userId).toList();
  }

  List<MaintenanceRequestModel> myMaintenanceRequestsFor(String? userId) {
    if (userId == null) return [];
    return _maintenanceRequests.where((r) => r.tenantId == userId).toList();
  }

  List<MaintenanceRequestModel> landlordMaintenanceRequestsFor(String? userId) {
    if (userId == null) return [];
    return _maintenanceRequests.where((r) => r.landlordId == userId).toList();
  }

  List<RentScheduleModel> myRentSchedulesFor(String? userId) {
    if (userId == null) return [];
    return _rentSchedules.where((r) => r.tenantId == userId).toList();
  }

  List<InspectionModel> landlordInspectionsFor(String? userId) {
    if (userId == null) return [];
    return _inspections.where((i) => i.landlordId == userId).toList();
  }

  List<DepositTransactionModel> myDepositTransactionsFor(String? userId) {
    if (userId == null) return [];
    return _depositTransactions.where((d) => d.tenantId == userId).toList();
  }

  List<DepositTransactionModel> landlordDepositTransactionsFor(String? userId) {
    if (userId == null) return [];
    return _depositTransactions.where((d) => d.landlordId == userId).toList();
  }

  MoveChecklistModel? getMyChecklist(String? userId, String tenancyId) {
    if (userId == null) return null;
    try {
      return _moveChecklists.firstWhere((c) => c.userId == userId && c.tenancyId == tenancyId);
    } catch (_) {
      return null;
    }
  }

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
      _tenancyApplications[idx] = app.copyWith(status: ApplicationStatus.approved, resolvedAt: DateTime.now());
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
      _tenancies[idx] = t.copyWith(status: TenancyStatus.active, activatedAt: DateTime.now());
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
      _tenancies[idx] = t.copyWith(status: TenancyStatus.completed, completedAt: DateTime.now());
      _data.updateTenancyStatus(tenancyId, TenancyStatus.completed).catchError((e) {
        debugPrint('updateTenancyStatus error: $e');
      });
      notifyListeners();
    }
  }

  /// Give move-out notice (tenant or landlord). Server-side (RPC,
  /// migration 029) stamps the notice fields, flips the property to
  /// noticePeriod, and notifies the counterpart — this just fires
  /// the call and lets the realtime stream reconcile local state.
  Future<void> giveNotice(
    String tenancyId, {
    required String givenBy,
    required DateTime plannedMoveOutDate,
    String? reason,
  }) {
    return _data.giveTenancyNotice(
      tenancyId,
      givenBy: givenBy,
      plannedMoveOutDate: plannedMoveOutDate,
      reason: reason,
    );
  }

  Future<void> requestRenewal(String tenancyId, {required String requestedBy}) {
    return _data.requestTenancyRenewal(tenancyId, requestedBy: requestedBy);
  }

  /// Landlord confirms renewal terms; returns the new tenancy id.
  Future<String> confirmRenewal(
    String tenancyId, {
    double? newRentAmount,
    double? newDepositAmount,
    int leaseDays = 365,
  }) {
    return _data.confirmTenancyRenewal(
      tenancyId,
      newRentAmount: newRentAmount,
      newDepositAmount: newDepositAmount,
      leaseDays: leaseDays,
    );
  }

  Future<void> scheduleInspection({
    required String propertyId,
    required String tenancyId,
    required String landlordId,
    DateTime? scheduledDate,
  }) {
    return _data.scheduleInspection(
      propertyId: propertyId,
      tenancyId: tenancyId,
      landlordId: landlordId,
      scheduledDate: scheduledDate,
    );
  }

  Future<void> completeInspection(
    String inspectionId, {
    required String conditionAfter,
    double damageCost = 0,
    String? notes,
  }) {
    return _data.completeInspection(
      inspectionId,
      conditionAfter: conditionAfter,
      damageCost: damageCost,
      notes: notes,
    );
  }

  Future<void> openDepositTransaction({
    required String tenancyId,
    required String tenantId,
    required String landlordId,
    required double amount,
  }) {
    return _data.openDepositTransaction(
      tenancyId: tenancyId,
      tenantId: tenantId,
      landlordId: landlordId,
      amount: amount,
    );
  }

  Future<void> settleDeposit(String depositId, {required double amount, required double deductions, String? notes}) {
    return _data.settleDeposit(depositId, amount: amount, deductions: deductions, notes: notes);
  }

  Future<void> addTurnoverMaintenanceRequest({
    required String landlordId,
    required String landlordName,
    required String propertyId,
    required String propertyTitle,
    String? tenancyId,
    required String description,
  }) {
    return _data.addTurnoverMaintenanceRequest(
      landlordId: landlordId,
      landlordName: landlordName,
      propertyId: propertyId,
      propertyTitle: propertyTitle,
      tenancyId: tenancyId,
      description: description,
    );
  }

  void addMaintenanceRequest(MaintenanceRequestModel request) {
    _maintenanceRequests.add(request);
    _data.addMaintenanceRequest(request).catchError((e) {
      debugPrint('addMaintenanceRequest error: $e');
    });
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
      _data.updateMaintenanceStatus(requestId, status, resolutionNotes: resolutionNotes).catchError((e) {
        debugPrint('updateMaintenanceStatus error: $e');
      });
      notifyListeners();
    }
  }

  void markRentPaid(String scheduleId) {
    final idx = _rentSchedules.indexWhere((r) => r.id == scheduleId);
    if (idx >= 0) {
      final r = _rentSchedules[idx];
      _rentSchedules[idx] = RentScheduleModel(
        id: r.id,
        tenancyId: r.tenancyId,
        tenantId: r.tenantId,
        propertyTitle: r.propertyTitle,
        dueDate: r.dueDate,
        amount: r.amount,
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
        _moveChecklists[cIdx] = checklist.copyWith(items: items, updatedAt: DateTime.now());
        _data.updateMoveChecklist(_moveChecklists[cIdx]).catchError((e) {
          debugPrint('updateMoveChecklist error: $e');
        });
        notifyListeners();
      }
    }
  }

  void _unsubscribe() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _subscribe(UserModel user) {
    final isLandlord = user.role == UserRole.landlord || user.role == UserRole.agent;

    if (isLandlord) {
      _subscriptions.add(_data.getApplicationsForLandlord(user.id).listen((list) {
        _tenancyApplications = list.cast<TenancyApplicationModel>();
        notifyListeners();
      }));
      _subscriptions.add(_data.getTenanciesForLandlord(user.id).listen((list) {
        _tenancies = list.cast<TenancyModel>();
        notifyListeners();
      }));
      _subscriptions.add(_data.getMaintenanceForLandlord(user.id).listen((list) {
        _maintenanceRequests = list.cast<MaintenanceRequestModel>();
        notifyListeners();
      }));
      _subscriptions.add(_data.getRentSchedulesForLandlord(user.id).listen((list) {
        _rentSchedules = list;
        notifyListeners();
      }));
      _subscriptions.add(_data.getInspectionsForLandlord(user.id).listen((list) {
        _inspections = list;
        notifyListeners();
      }));
      _subscriptions.add(_data.getDepositTransactionsForLandlord(user.id).listen((list) {
        _depositTransactions = list;
        notifyListeners();
      }));
    } else {
      _subscriptions.add(_data.getApplicationsForTenant(user.id).listen((list) {
        _tenancyApplications = list.cast<TenancyApplicationModel>();
        notifyListeners();
      }));
      _subscriptions.add(_data.getTenanciesForTenant(user.id).listen((list) {
        _tenancies = list.cast<TenancyModel>();
        notifyListeners();
      }));
      _subscriptions.add(_data.getMaintenanceForTenant(user.id).listen((list) {
        _maintenanceRequests = list.cast<MaintenanceRequestModel>();
        notifyListeners();
      }));
      _subscriptions.add(_data.getRentSchedulesForTenant(user.id).listen((list) {
        _rentSchedules = list;
        notifyListeners();
      }));
      _subscriptions.add(_data.getDepositTransactionsForTenant(user.id).listen((list) {
        _depositTransactions = list;
        notifyListeners();
      }));
    }

    _subscriptions.add(_data.getMoveChecklistsForUser(user.id).listen((list) {
      _moveChecklists
        ..clear()
        ..addAll(list);
      notifyListeners();
    }));
  }

  void onUserChanged(UserModel? user) {
    if (user?.id == _lastUserId) return;
    _lastUserId = user?.id;
    _currentUser = user;
    _unsubscribe();
    _tenancyApplications = [];
    _tenancies = [];
    _maintenanceRequests = [];
    _rentSchedules = [];
    _inspections = [];
    _depositTransactions = [];
    _moveChecklists.clear();
    if (user == null) {
      notifyListeners();
      return;
    }
    _subscribe(user);
  }

  /// Re-fetch by re-subscribing (pull-to-refresh). Completes once fresh
  /// data has been delivered (5s timeout fallback so the spinner never
  /// hangs); a no-op when no user is signed in.
  Future<void> refreshData() async {
    final user = _currentUser;
    if (user == null) return;
    final delivered = Completer<void>();
    final isLandlord = user.role == UserRole.landlord || user.role == UserRole.agent;
    final probe = (isLandlord
            ? _data.getApplicationsForLandlord(user.id)
            : _data.getApplicationsForTenant(user.id))
        .listen((_) {
      if (!delivered.isCompleted) delivered.complete();
    }, onError: (_) {
      if (!delivered.isCompleted) delivered.complete();
    }, onDone: () {
      if (!delivered.isCompleted) delivered.complete();
    });
    _unsubscribe();
    _subscribe(user);
    await delivered.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    await probe.cancel();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}

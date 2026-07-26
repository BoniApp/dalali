import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/tenancy_application_model.dart';
import 'package:dalali/models/tenancy_model.dart';
import 'package:dalali/models/move_checklist_model.dart';
import 'package:dalali/models/maintenance_request_model.dart';
import 'package:dalali/models/rent_schedule_model.dart';
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

  final DataService _data = DataService();
  final List<StreamSubscription> _subscriptions = [];
  String? _lastUserId;

  List<TenancyApplicationModel> get tenancyApplications => _tenancyApplications;
  List<TenancyModel> get tenancies => _tenancies;
  List<MoveChecklistModel> get moveChecklists => _moveChecklists;
  List<MaintenanceRequestModel> get maintenanceRequests => _maintenanceRequests;
  List<RentScheduleModel> get rentSchedules => _rentSchedules;

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

  void onUserChanged(UserModel? user) {
    if (user?.id == _lastUserId) return;
    _lastUserId = user?.id;
    _unsubscribe();
    _tenancyApplications = [];
    _tenancies = [];
    _maintenanceRequests = [];
    _rentSchedules = [];
    _moveChecklists.clear();
    if (user == null) {
      notifyListeners();
      return;
    }

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
    }

    _subscriptions.add(_data.getMoveChecklistsForUser(user.id).listen((list) {
      _moveChecklists
        ..clear()
        ..addAll(list);
      notifyListeners();
    }));
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/appointment_model.dart';
import 'package:dalali/models/inquiry_model.dart';
import 'package:dalali/models/notification_model.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/notification_service.dart';
import 'package:dalali/providers/property_state.dart';

/// Viewing appointments and inquiries. Pass the [PropertyState]
/// instance in via [attachPropertyState] (wired in main.dart) so
/// sending an inquiry can mirror the property's inquiry count.
class AppointmentState extends ChangeNotifier {
  List<AppointmentModel> _appointments = [];
  List<InquiryModel> _inquiries = [];

  final DataService _data = DataService();
  final List<StreamSubscription> _subscriptions = [];
  String? _lastUserId;
  UserModel? _currentUser;
  PropertyState? _propertyState;

  void attachPropertyState(PropertyState propertyState) {
    _propertyState = propertyState;
  }

  List<AppointmentModel> get appointments => _appointments;
  List<InquiryModel> get inquiries => _inquiries;

  List<AppointmentModel> userAppointmentsFor(UserModel? user) {
    if (user == null) return [];
    if (user.role == UserRole.landlord || user.role == UserRole.agent) {
      return _appointments.where((a) => a.landlordId == user.id).toList();
    }
    return _appointments.where((a) => a.seekerId == user.id).toList();
  }

  List<InquiryModel> landlordInquiriesFor(String? userId) {
    if (userId == null) return [];
    return _inquiries.where((i) => i.landlordId == userId).toList();
  }

  void addAppointment(AppointmentModel appointment) {
    _appointments.add(appointment);
    _data.addAppointment(appointment).catchError((e) {
      debugPrint('addAppointment error: $e');
    });
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
    _propertyState?.incrementInquiryCount(inquiry.propertyId);

    _data.addInquiry(inquiry).catchError((e) {
      debugPrint('addInquiry error: $e');
    });
    final property = _propertyState?.properties.where((p) => p.id == inquiry.propertyId).toList();
    if (property != null && property.isNotEmpty) {
      _data.incrementPropertyInquiryCount(inquiry.propertyId, property.first.inquiryCount - 1).catchError((e) {
        debugPrint('incrementPropertyInquiryCount error: $e');
      });
    }
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

  void _unsubscribe() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _subscribe(UserModel user) {
    final isLandlord = user.role == UserRole.landlord || user.role == UserRole.agent;
    _subscriptions.add(_data.getAppointments(user.id, isLandlord: isLandlord).listen((list) {
      _appointments = list;
      notifyListeners();
    }));
    if (isLandlord) {
      _subscriptions.add(_data.getInquiriesForLandlord(user.id).listen((list) {
        _inquiries = list;
        notifyListeners();
      }));
    } else {
      _subscriptions.add(_data.getInquiriesForSeeker(user.id).listen((list) {
        _inquiries = list;
        notifyListeners();
      }));
    }
  }

  void onUserChanged(UserModel? user) {
    if (user?.id == _lastUserId) return;
    _lastUserId = user?.id;
    _currentUser = user;
    _unsubscribe();
    if (user == null) {
      _appointments = [];
      _inquiries = [];
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
    final probe = _data.getAppointments(user.id, isLandlord: isLandlord).listen((_) {
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

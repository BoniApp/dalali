import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/appointment_model.dart';

class Helpers {
  static String formatPrice(double price) {
    final formatter = NumberFormat.currency(
      locale: 'sw_TZ',
      symbol: 'TZS ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  static String formatDateOnly(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String propertyTypeLabel(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return 'Apartment';
      case PropertyType.house:
        return 'House';
      case PropertyType.villa:
        return 'Villa';
      case PropertyType.bedsitter:
        return 'Bedsitter';
      case PropertyType.office:
        return 'Office';
      case PropertyType.shop:
        return 'Shop';
    }
  }

  static String appointmentStatusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  static Color appointmentStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.confirmed:
        return Colors.green;
      case AppointmentStatus.completed:
        return Colors.blue;
      case AppointmentStatus.cancelled:
        return Colors.red;
    }
  }

  static IconData propertyTypeIcon(PropertyType type) {
    switch (type) {
      case PropertyType.apartment:
        return Icons.apartment;
      case PropertyType.house:
        return Icons.home;
      case PropertyType.villa:
        return Icons.villa;
      case PropertyType.bedsitter:
        return Icons.bed;
      case PropertyType.office:
        return Icons.business;
      case PropertyType.shop:
        return Icons.store;
    }
  }

  static String paymentTermLabel(PaymentTerm term) {
    switch (term) {
      case PaymentTerm.monthly:
        return 'Monthly';
      case PaymentTerm.threeMonths:
        return '3 Months';
      case PaymentTerm.sixMonths:
        return '6 Months';
      case PaymentTerm.twelveMonths:
        return '12 Months';
      case PaymentTerm.negotiable:
        return 'Negotiable';
    }
  }

  static PaymentTerm? paymentTermFromString(String? value) {
    if (value == null) return null;
    return PaymentTerm.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentTerm.monthly,
    );
  }

  static List<PaymentTerm> paymentTermsFromJson(List<dynamic>? json) {
    if (json == null || json.isEmpty) return [PaymentTerm.monthly];
    return json
        .whereType<String>()
        .map((s) => paymentTermFromString(s))
        .whereType<PaymentTerm>()
        .toList();
  }
}

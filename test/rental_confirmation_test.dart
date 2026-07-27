import 'package:flutter_test/flutter_test.dart';

import 'package:dalali/models/rental_confirmation_model.dart';

void main() {
  group('RentalConfirmationModel', () {
    final json = {
      'id': 'rc1',
      'property_id': 'p1',
      'property_title': '2BR in Kinondoni',
      'seeker_id': 's1',
      'seeker_name': 'Asha Juma',
      'seeker_phone': '+255700000001',
      'marked_by': 'l1',
      'marked_by_name': 'Landlord Joe',
      'marked_by_role': 'landlord',
      'status': 'pending',
      'created_at': '2026-07-20T10:00:00.000Z',
      'resolved_at': null,
    };

    test('fromJson parses all fields', () {
      final m = RentalConfirmationModel.fromJson(json);
      expect(m.id, 'rc1');
      expect(m.propertyId, 'p1');
      expect(m.propertyTitle, '2BR in Kinondoni');
      expect(m.seekerId, 's1');
      expect(m.seekerName, 'Asha Juma');
      expect(m.seekerPhone, '+255700000001');
      expect(m.markedBy, 'l1');
      expect(m.markedByName, 'Landlord Joe');
      expect(m.markedByRole, 'landlord');
      expect(m.status, RentalConfirmationStatus.pending);
      expect(m.createdAt, DateTime.parse('2026-07-20T10:00:00.000Z'));
      expect(m.resolvedAt, isNull);
    });

    test('fromJson parses resolved rows and every status value', () {
      for (final status in RentalConfirmationStatus.values) {
        final m = RentalConfirmationModel.fromJson({
          ...json,
          'status': status.name,
          'resolved_at': '2026-07-21T08:30:00.000Z',
        });
        expect(m.status, status);
        expect(m.resolvedAt, DateTime.parse('2026-07-21T08:30:00.000Z'));
      }
    });

    test('fromJson tolerates missing fields and unknown status', () {
      final m = RentalConfirmationModel.fromJson({
        'id': 'rc2',
        'property_id': 'p1',
        'seeker_id': 's1',
        'marked_by': 'l1',
        'status': 'somethingNew',
      });
      expect(m.propertyTitle, '');
      expect(m.seekerName, '');
      expect(m.markedByRole, '');
      expect(m.status, RentalConfirmationStatus.pending);
      expect(m.resolvedAt, isNull);
    });
  });

  group('RentableSeeker', () {
    test('fromJson parses RPC rows', () {
      final s = RentableSeeker.fromJson({
        'user_id': 'u1',
        'full_name': 'Asha Juma',
        'phone': '+255700000001',
        'source': 'applied+paid',
      });
      expect(s.userId, 'u1');
      expect(s.fullName, 'Asha Juma');
      expect(s.paid, isTrue);
      expect(s.applied, isTrue);
    });

    test('source flags distinguish paid-only and applied-only seekers', () {
      final paid = RentableSeeker.fromJson({'user_id': 'u1', 'source': 'paid'});
      expect(paid.paid, isTrue);
      expect(paid.applied, isFalse);

      final applied = RentableSeeker.fromJson({'user_id': 'u2', 'source': 'applied'});
      expect(applied.paid, isFalse);
      expect(applied.applied, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:dalali/models/influencer/influencer_model.dart';
import 'package:dalali/models/influencer/influencer_application_model.dart';
import 'package:dalali/models/influencer/referral_link_model.dart';
import 'package:dalali/models/influencer/referral_conversion_model.dart';
import 'package:dalali/models/influencer/campaign_model.dart';
import 'package:dalali/services/influencer/influencer_service.dart';

void main() {
  group('InfluencerModel', () {
    final json = {
      'user_id': 'u1',
      'referral_code': 'JUMA2024',
      'status': 'active',
      'tiktok_url': 'https://tiktok.com/@juma',
      'instagram_url': null,
      'youtube_url': 'https://youtube.com/@juma',
      'followers_count': 15000,
      'content_niche': 'real_estate',
      'audience_location': 'Dar es Salaam',
      'total_clicks': 120,
      'total_registrations': 45,
      'total_conversions': 12,
      'total_earnings': 24000.0,
      'created_at': '2026-01-15T10:00:00.000Z',
      'activated_at': '2026-01-20T10:00:00.000Z',
    };

    test('fromJson parses all fields', () {
      final m = InfluencerModel.fromJson(json);
      expect(m.userId, 'u1');
      expect(m.referralCode, 'JUMA2024');
      expect(m.status, InfluencerStatus.active);
      expect(m.isActive, isTrue);
      expect(m.tiktokUrl, 'https://tiktok.com/@juma');
      expect(m.instagramUrl, isNull);
      expect(m.followersCount, 15000);
      expect(m.totalClicks, 120);
      expect(m.totalRegistrations, 45);
      expect(m.totalConversions, 12);
      expect(m.totalEarnings, 24000.0);
      expect(m.activatedAt, isNotNull);
    });

    test('toJson round-trip preserves fields', () {
      final m = InfluencerModel.fromJson(json);
      final m2 = InfluencerModel.fromJson(m.toJson());
      expect(m2.userId, m.userId);
      expect(m2.referralCode, m.referralCode);
      expect(m2.status, m.status);
      expect(m2.followersCount, m.followersCount);
      expect(m2.totalEarnings, m.totalEarnings);
      expect(m2.contentNiche, m.contentNiche);
    });

    test('unknown status falls back to pending', () {
      final m = InfluencerModel.fromJson({...json, 'status': 'banned'});
      expect(m.status, InfluencerStatus.pending);
    });

    test('copyWith only changes profile fields, keeps counters', () {
      final m = InfluencerModel.fromJson(json);
      final updated = m.copyWith(followersCount: 20000, contentNiche: 'comedy');
      expect(updated.followersCount, 20000);
      expect(updated.contentNiche, 'comedy');
      expect(updated.totalClicks, m.totalClicks);
      expect(updated.totalEarnings, m.totalEarnings);
      expect(updated.referralCode, m.referralCode);
    });
  });

  group('InfluencerApplicationModel', () {
    final json = {
      'id': 'app1',
      'user_id': 'u1',
      'full_name': 'Juma Mwangi',
      'phone': '+255712345678',
      'email': 'juma@example.com',
      'tiktok_url': 'https://tiktok.com/@juma',
      'instagram_url': null,
      'youtube_url': null,
      'followers_count': 5000,
      'content_niche': 'lifestyle',
      'audience_location': 'Arusha',
      'status': 'rejected',
      'reviewed_by': 'admin1',
      'reviewed_at': '2026-02-01T08:00:00.000Z',
      'rejection_reason': 'Not enough followers',
      'created_at': '2026-01-15T10:00:00.000Z',
    };

    test('fromJson parses all fields', () {
      final m = InfluencerApplicationModel.fromJson(json);
      expect(m.id, 'app1');
      expect(m.fullName, 'Juma Mwangi');
      expect(m.status, InfluencerApplicationStatus.rejected);
      expect(m.rejectionReason, 'Not enough followers');
      expect(m.reviewedAt, isNotNull);
    });

    test('toJson omits id (DB-generated) and keeps snake_case keys', () {
      final m = InfluencerApplicationModel.fromJson(json);
      final out = m.toJson();
      expect(out.containsKey('id'), isFalse);
      expect(out['user_id'], 'u1');
      expect(out['full_name'], 'Juma Mwangi');
      expect(out['status'], 'rejected');
    });

    test('unknown status falls back to pending', () {
      final m = InfluencerApplicationModel.fromJson({...json, 'status': 'weird'});
      expect(m.status, InfluencerApplicationStatus.pending);
    });
  });

  group('ReferralLinkModel', () {
    test('fromJson/toJson round-trip', () {
      final m = ReferralLinkModel.fromJson({
        'id': 'l1',
        'influencer_id': 'u1',
        'campaign_id': 'c1',
        'code': 'ABC123',
        'is_active': false,
        'created_at': '2026-01-15T10:00:00.000Z',
      });
      expect(m.id, 'l1');
      expect(m.campaignId, 'c1');
      expect(m.isActive, isFalse);

      final m2 = ReferralLinkModel.fromJson({...m.toJson(), 'id': m.id});
      expect(m2.code, 'ABC123');
      expect(m2.influencerId, 'u1');
      expect(m2.isActive, isFalse);
    });
  });

  group('ReferralConversionModel', () {
    final json = {
      'id': 'conv1',
      'influencer_id': 'u1',
      'link_id': 'l1',
      'referred_user_id': 'u2',
      'transaction_id': 'tx1',
      'earnings_entry_id': 'e1',
      'conversion_type': 'agency_fee_payment',
      'commission_amount': 2000.0,
      'status': 'paid',
      'created_at': '2026-01-15T10:00:00.000Z',
    };

    test('fromJson maps snake_case DB enum values explicitly', () {
      expect(
        ReferralConversionModel.fromJson({...json, 'conversion_type': 'registration'}).conversionType,
        ConversionType.registration,
      );
      expect(
        ReferralConversionModel.fromJson({...json, 'conversion_type': 'agency_fee_payment'}).conversionType,
        ConversionType.agencyFeePayment,
      );
      expect(
        ReferralConversionModel.fromJson({...json, 'conversion_type': 'premium_payment'}).conversionType,
        ConversionType.premiumPayment,
      );
      expect(
        ReferralConversionModel.fromJson({...json, 'conversion_type': 'deal_closed'}).conversionType,
        ConversionType.dealClosed,
      );
    });

    test('toJson writes snake_case conversion_type', () {
      final m = ReferralConversionModel.fromJson(json);
      expect(m.toJson()['conversion_type'], 'agency_fee_payment');
      expect(m.toJson()['status'], 'paid');
    });

    test('toJson/fromJson round-trip', () {
      final m = ReferralConversionModel.fromJson(json);
      final m2 = ReferralConversionModel.fromJson({...m.toJson(), 'id': m.id});
      expect(m2.conversionType, m.conversionType);
      expect(m2.commissionAmount, m.commissionAmount);
      expect(m2.status, m.status);
      expect(m2.referredUserId, m.referredUserId);
    });

    test('unknown conversion_type falls back to registration', () {
      final m = ReferralConversionModel.fromJson({...json, 'conversion_type': 'other'});
      expect(m.conversionType, ConversionType.registration);
    });

    test('unknown status falls back to pending', () {
      final m = ReferralConversionModel.fromJson({...json, 'status': 'unknown'});
      expect(m.status, ConversionStatus.pending);
    });
  });

  group('CampaignModel', () {
    final json = {
      'id': 'c1',
      'name': 'Ramadan Push',
      'description': 'Dar campaign',
      'budget': 500000.0,
      'start_date': '2026-02-18',
      'end_date': '2026-03-20',
      'target_audience': 'Dar es Salaam seekers',
      'commission_rules': {'agency_fee_pct': 0.10},
      'status': 'active',
      'created_by': 'admin1',
      'created_at': '2026-01-15T10:00:00.000Z',
    };

    test('fromJson parses all fields', () {
      final m = CampaignModel.fromJson(json);
      expect(m.name, 'Ramadan Push');
      expect(m.status, CampaignStatus.active);
      expect(m.budget, 500000.0);
      expect(m.commissionRules?['agency_fee_pct'], 0.10);
      expect(m.startDate, isNotNull);
    });

    test('toJson/fromJson round-trip', () {
      final m = CampaignModel.fromJson(json);
      final m2 = CampaignModel.fromJson({...m.toJson(), 'id': m.id});
      expect(m2.name, m.name);
      expect(m2.status, m.status);
      expect(m2.budget, m.budget);
    });

    test('unknown status falls back to draft', () {
      final m = CampaignModel.fromJson({...json, 'status': 'archived'});
      expect(m.status, CampaignStatus.draft);
    });
  });

  group('CampaignParticipantModel', () {
    test('fromJson/toJson round-trip', () {
      final m = CampaignParticipantModel.fromJson({
        'campaign_id': 'c1',
        'influencer_id': 'u1',
        'status': 'joined',
        'joined_at': '2026-01-15T10:00:00.000Z',
      });
      expect(m.campaignId, 'c1');
      expect(m.status, CampaignParticipantStatus.joined);

      final m2 = CampaignParticipantModel.fromJson(m.toJson());
      expect(m2.influencerId, 'u1');
      expect(m2.status, m.status);
    });

    test('unknown status falls back to joined', () {
      final m = CampaignParticipantModel.fromJson({
        'campaign_id': 'c1',
        'influencer_id': 'u1',
        'status': 'banned',
        'joined_at': '2026-01-15T10:00:00.000Z',
      });
      expect(m.status, CampaignParticipantStatus.joined);
    });
  });

  group('InfluencerService.buildReferralUrl', () {
    test('builds dalaliapp.com ref URL', () {
      expect(
        InfluencerService().buildReferralUrl('JUMA2024'),
        'https://dalaliapp.com/ref/JUMA2024',
      );
    });
  });
}

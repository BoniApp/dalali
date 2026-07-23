import 'package:flutter_test/flutter_test.dart';
import 'package:dalali/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.parseReferralLink', () {
    test('parses a bare referral code link', () {
      final data = DeepLinkService.parseReferralLink(
        Uri.parse('https://dalaliapp.com/ref/K7X2M'),
      );
      expect(data.code, 'K7X2M');
      expect(data.listingId, isNull);
    });

    test('parses code + listing param', () {
      final data = DeepLinkService.parseReferralLink(
        Uri.parse('https://dalaliapp.com/ref/k7x2m?listing=abc-123'),
      );
      expect(data.code, 'K7X2M'); // normalized to upper case
      expect(data.listingId, 'abc-123');
    });

    test('ignores non-referral hosts', () {
      final data = DeepLinkService.parseReferralLink(
        Uri.parse('https://example.com/ref/K7X2M?listing=abc'),
      );
      expect(data.code, isNull);
      expect(data.listingId, isNull);
    });

    test('ignores non-https schemes', () {
      final data = DeepLinkService.parseReferralLink(
        Uri.parse('http://dalaliapp.com/ref/K7X2M'),
      );
      expect(data.code, isNull);
    });

    test('ignores non-ref paths and empty listing params', () {
      expect(
        DeepLinkService.parseReferralLink(Uri.parse('https://dalaliapp.com/about')).code,
        isNull,
      );
      final data = DeepLinkService.parseReferralLink(
        Uri.parse('https://dalaliapp.com/ref/K7X2M?listing='),
      );
      expect(data.code, 'K7X2M');
      expect(data.listingId, isNull);
    });
  });
}

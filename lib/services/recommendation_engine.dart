import 'dart:math' show Random;
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';

/// Lightweight on-device recommendation engine.
///
/// Scores properties based on:
/// - User preferred locations
/// - Past favorites (price range, property type, features)
/// - Listing quality (rating, featured, boosted)
/// - Engagement signals (viewCount, inquiryCount)
class RecommendationEngine {
  final Random _random = Random();

  /// Returns properties sorted by relevance score for the given user.
  List<PropertyModel> recommendForUser({
    required UserModel? user,
    required List<PropertyModel> allProperties,
    required List<String> favoritePropertyIds,
    int maxResults = 10,
  }) {
    final scored = allProperties.map((p) {
      final score = _scoreProperty(
        property: p,
        user: user,
        favoriteIds: favoritePropertyIds,
      );
      return (property: p, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).map((s) => s.property).toList();
  }

  double _scoreProperty({
    required PropertyModel property,
    required UserModel? user,
    required List<String> favoriteIds,
  }) {
    double score = 0.0;

    // 1. Base quality score (0-100)
    score += property.rating * 10;           // up to +50
    score += property.reviewCount * 0.5;     // up to +12.5
    if (property.listingType == ListingType.featured) score += 15;
    if (property.isBoosted) score += 20;
    if (property.isLandlordVerified) score += 10;

    // 2. Engagement (0-30)
    score += (property.viewCount / 50).clamp(0, 15);
    score += (property.inquiryCount / 5).clamp(0, 15);

    // 3. Personalization (0-50)
    if (user != null) {
      // Preferred locations match
      for (final loc in user.preferredLocations) {
        if (property.location.toLowerCase().contains(loc.toLowerCase())) {
          score += 12;
        }
      }

      // Saved search keyword overlap in title/description
      for (final search in user.savedSearches) {
        final kw = search.toLowerCase().trim();
        if (property.title.toLowerCase().contains(kw) ||
            property.description.toLowerCase().contains(kw)) {
          score += 8;
        }
      }
    }

    // 4. If already favorited, bump slightly so favorites aren't buried
    if (favoriteIds.contains(property.id)) {
      score += 5;
    }

    // 5. Small random tie-breaker so identical scores don't look robotic
    score += _random.nextDouble() * 2;

    return score;
  }

  /// "Because you viewed X" style similar properties
  List<PropertyModel> similarTo({
    required PropertyModel source,
    required List<PropertyModel> allProperties,
    int maxResults = 5,
  }) {
    final scored = allProperties
        .where((p) => p.id != source.id)
        .map((p) {
      double score = 0;

      // Same property type
      if (p.propertyType == source.propertyType) score += 20;

      // Same location area
      if (p.location.toLowerCase().contains(
          source.location.split(',').first.toLowerCase())) {
        score += 15;
      }

      // Similar price (within 30%)
      final priceDiff = (p.rentPrice - source.rentPrice).abs() / source.rentPrice;
      if (priceDiff < 0.3) {
        score += 15;
      } else if (priceDiff < 0.6) {
        score += 8;
      }

      // Same bedrooms
      if (p.bedrooms == source.bedrooms) score += 10;

      // Same amenities
      if (p.isFurnished == source.isFurnished) score += 5;
      if (p.hasParking == source.hasParking) score += 5;
      if (p.hasSecurity == source.hasSecurity) score += 5;

      // Quality
      score += p.rating * 2;

      return (property: p, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).map((s) => s.property).toList();
  }
}

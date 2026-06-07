import 'dart:math' show Random;
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';

/// HTN Matching Engine — suggests properties based on:
/// - User budget range
/// - Move date proximity
/// - Preferred location
/// - Utilities preference
/// - Past favorites / search behavior
class MatchingEngine {
  final Random _random = Random();

  /// Score and rank properties for a user during their move.
  List<PropertyModel> matchForMove({
    required MoveListingModel move,
    required UserModel? user,
    required List<PropertyModel> allProperties,
    required List<String> favoritePropertyIds,
    int maxResults = 10,
  }) {
    final scored = allProperties.map((p) {
      final score = _scoreForMove(
        property: p,
        move: move,
        user: user,
        favoriteIds: favoritePropertyIds,
      );
      return (property: p, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).map((s) => s.property).toList();
  }

  double _scoreForMove({
    required PropertyModel property,
    required MoveListingModel move,
    required UserModel? user,
    required List<String> favoriteIds,
  }) {
    double score = 0.0;

    // 1. Budget match (0-40 pts)
    if (move.budgetMin != null && move.budgetMax != null) {
      if (property.rentPrice >= move.budgetMin! && property.rentPrice <= move.budgetMax!) {
        score += 40;
      } else {
        final diff = (property.rentPrice - move.budgetMax!).abs();
        score += (40 - (diff / move.budgetMax! * 40)).clamp(0, 40);
      }
    } else {
      score += 20; // no budget preference = neutral
    }

    // 2. Location preference (0-25 pts)
    if (move.preferredLocation != null && move.preferredLocation!.isNotEmpty) {
      if (property.location.toLowerCase().contains(move.preferredLocation!.toLowerCase())) {
        score += 25;
      } else if (user != null) {
        for (final loc in user.preferredLocations) {
          if (property.location.toLowerCase().contains(loc.toLowerCase())) {
            score += 15;
          }
        }
      }
    } else {
      score += 12;
    }

    // 3. Move date proximity — prefer listings that have been available longer
    // (more likely to still be available near move date)
    final daysListed = DateTime.now().difference(property.createdAt).inDays;
    score += (daysListed / 30).clamp(0, 10);

    // 4. Property quality (0-20 pts)
    score += property.rating * 4;
    if (property.isLandlordVerified) score += 5;
    if (property.listingType == ListingType.featured) score += 5;

    // 5. Utility preference bonuses
    if (property.utilities.water == UtilityResponsibility.landlord) score += 3;
    if (property.utilities.electricity == UtilityResponsibility.landlord) score += 3;
    if (property.utilities.security == SecurityType.included) score += 3;

    // 6. Engagement (0-10 pts)
    score += (property.viewCount / 100).clamp(0, 5);
    score += (property.inquiryCount / 10).clamp(0, 5);

    // 7. Favorited before = small boost
    if (favoriteIds.contains(property.id)) {
      score += 5;
    }

    // 8. Random tie-breaker
    score += _random.nextDouble() * 2;

    return score;
  }

  /// Find move listings near a given location (for "People moving near you").
  List<MoveListingModel> findMovesNearLocation({
    required String locationQuery,
    required List<MoveListingModel> allMoves,
    int maxResults = 10,
  }) {
    final query = locationQuery.toLowerCase();
    final scored = allMoves
        .where((m) => m.status != MoveStatus.completed && m.status != MoveStatus.cancelled)
        .map((m) {
      double score = 0;
      if (m.currentLocation.toLowerCase().contains(query)) score += 30;
      if (m.preferredLocation != null && m.preferredLocation!.toLowerCase().contains(query)) {
        score += 20;
      }
      // Fresher moves rank higher
      final daysOld = DateTime.now().difference(m.createdAt).inDays;
      score += (30 - daysOld).clamp(0, 30);
      return (move: m, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).map((s) => s.move).toList();
  }
}

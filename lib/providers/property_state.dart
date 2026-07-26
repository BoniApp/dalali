import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/favorite_model.dart';
import 'package:dalali/models/review_model.dart';
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/safety_engine.dart';

/// Properties, favorites, neighbourhood safety reports and reviews.
/// Properties + neighbourhood reports are public RLS-safe reads, so
/// they're subscribed for guests too (see [onUserChanged]); favorites
/// and reviews require a signed-in user.
class PropertyState extends ChangeNotifier {
  List<PropertyModel> _properties = [];
  List<PropertyModel> _myProperties = [];
  List<FavoriteModel> _favorites = [];
  List<NeighbourhoodReportModel> _neighbourhoodReports = [];
  List<ReviewModel> _reviews = [];

  final DataService _data = DataService();
  final List<StreamSubscription> _publicSubscriptions = [];
  final List<StreamSubscription> _userSubscriptions = [];
  String? _lastKey;

  List<PropertyModel> get properties => _properties;
  List<PropertyModel> get landlordProperties => _myProperties;
  List<FavoriteModel> get favorites => _favorites;
  List<NeighbourhoodReportModel> get neighbourhoodReports => _neighbourhoodReports;
  List<ReviewModel> get reviews => _reviews;

  List<PropertyModel> get featuredProperties => _properties
      .where((p) => p.listingType == ListingType.featured && p.status == PropertyStatus.available)
      .toList();

  List<NeighbourhoodReportModel> get activeNeighbourhoodReports =>
      _neighbourhoodReports.where((r) => !r.resolved).toList();

  List<PropertyModel> favoritePropertiesFor(String? userId) {
    if (userId == null) return [];
    final favIds = _favorites.where((f) => f.userId == userId).map((f) => f.propertyId).toSet();
    return _properties.where((p) => favIds.contains(p.id)).toList();
  }

  List<ReviewModel> reviewsForLandlord(String? userId) {
    if (userId == null) return [];
    final myPropertyIds = _properties.where((p) => p.landlordId == userId).map((p) => p.id).toSet();
    return _reviews.where((r) => myPropertyIds.contains(r.propertyId)).toList();
  }

  bool isFavorite(String? userId, String propertyId) {
    if (userId == null) return false;
    return _favorites.any((f) => f.userId == userId && f.propertyId == propertyId);
  }

  void toggleFavorite(String userId, String propertyId) {
    final existing = _favorites.indexWhere((f) => f.userId == userId && f.propertyId == propertyId);
    if (existing >= 0) {
      _favorites.removeAt(existing);
      _data.removeFavorite(userId, propertyId).catchError((e) {
        debugPrint('removeFavorite error: $e');
      });
    } else {
      _favorites.add(FavoriteModel(
        id: 'f${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        propertyId: propertyId,
        createdAt: DateTime.now(),
      ));
      _data.addFavorite(userId, propertyId).catchError((e) {
        debugPrint('addFavorite error: $e');
      });
    }
    notifyListeners();
  }

  Future<void> addProperty(PropertyModel property) async {
    await _data.addProperty(property);
    _properties.add(property);
    notifyListeners();
  }

  Future<void> updateProperty(PropertyModel property) async {
    final index = _properties.indexWhere((p) => p.id == property.id);
    if (index >= 0) {
      await _data.updateProperty(property);
      _properties[index] = property;
      notifyListeners();
    }
  }

  /// Relist a property that left the market (status 'unlisted' after a
  /// tenancy ended). Explicit landlord action; the server never
  /// auto-relists.
  void relistProperty(String propertyId) {
    final idx = _myProperties.indexWhere((p) => p.id == propertyId);
    if (idx >= 0) {
      _myProperties[idx] = _myProperties[idx].copyWith(status: PropertyStatus.available);
    }
    _data.updatePropertyStatus(propertyId, PropertyStatus.available).catchError((e) {
      debugPrint('relistProperty error: $e');
    });
    notifyListeners();
  }

  /// Increment the given property's inquiry count locally (mirrors the
  /// DB update AppointmentState performs when an inquiry is sent).
  void incrementInquiryCount(String propertyId) {
    final pIdx = _properties.indexWhere((p) => p.id == propertyId);
    if (pIdx >= 0) {
      _properties[pIdx] = _properties[pIdx].copyWith(inquiryCount: _properties[pIdx].inquiryCount + 1);
      notifyListeners();
    }
  }

  void addReview(ReviewModel review) {
    _reviews.add(review);
    _data.addReview(review).catchError((e) {
      debugPrint('addReview error: $e');
    });
    final pIdx = _properties.indexWhere((p) => p.id == review.propertyId);
    if (pIdx >= 0) {
      final old = _properties[pIdx];
      final newCount = old.reviewCount + 1;
      final newRating = ((old.rating * old.reviewCount) + review.overallScore) / newCount;
      _properties[pIdx] = old.copyWith(reviewCount: newCount, rating: newRating);
      _data.updateProperty(_properties[pIdx]).catchError((e) {
        debugPrint('updateProperty error: $e');
      });
    }
    notifyListeners();
  }

  void addNeighbourhoodReport(NeighbourhoodReportModel report) {
    _neighbourhoodReports.add(report);
    _data.addNeighbourhoodReport(report).catchError((e) {
      debugPrint('addNeighbourhoodReport error: $e');
    });
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

  void _subscribePublicFeeds() {
    _publicSubscriptions.add(_data.getProperties(limit: 100).listen((list) {
      _properties = list;
      _recomputeSafetyScores();
      notifyListeners();
    }));
    _publicSubscriptions.add(_data.getNeighbourhoodReports(limit: 200).listen((list) {
      _neighbourhoodReports = list.cast<NeighbourhoodReportModel>();
      _recomputeSafetyScores();
      notifyListeners();
    }));
  }

  void _unsubscribePublicFeeds() {
    for (final sub in _publicSubscriptions) {
      sub.cancel();
    }
    _publicSubscriptions.clear();
  }

  void _unsubscribeUserFeeds() {
    for (final sub in _userSubscriptions) {
      sub.cancel();
    }
    _userSubscriptions.clear();
    _myProperties = [];
  }

  /// Called by MultiProvider's ChangeNotifierProxyProvider whenever
  /// UserState changes; only actually resubscribes when the signed-in
  /// user or guest-mode flag changed, not on every UserState mutation
  /// (profile image updates, etc.).
  void onUserChanged(UserModel? user, bool isGuestMode) {
    final key = user?.id ?? (isGuestMode ? '_guest' : null);
    if (key == _lastKey) return;
    _lastKey = key;
    _unsubscribeUserFeeds();
    _unsubscribePublicFeeds();

    if (key == null) return;

    _subscribePublicFeeds();
    if (user == null) return;

    final isLandlord = user.role == UserRole.landlord || user.role == UserRole.agent;
    if (isLandlord) {
      _userSubscriptions.add(_data.getMyProperties(user.id, limit: 100).listen((list) {
        _myProperties = list;
        notifyListeners();
      }));
    }
    _userSubscriptions.add(_data.getFavoritePropertyIds(user.id).listen((ids) {
      _favorites = ids
          .map((id) => FavoriteModel(id: 'f_$id', userId: user.id, propertyId: id, createdAt: DateTime.now()))
          .toList();
      notifyListeners();
    }));
    _userSubscriptions.add(_data.getReviews(limit: 100).listen((list) {
      _reviews = list.cast<ReviewModel>();
      notifyListeners();
    }));
  }

  /// Re-fetch the public feed (pull-to-refresh). Completes once fresh
  /// data has been delivered (5s timeout fallback so the spinner never
  /// hangs).
  Future<void> refreshData() async {
    final delivered = Completer<void>();
    final probe = _data.getProperties(limit: 100).listen((_) {
      if (!delivered.isCompleted) delivered.complete();
    }, onError: (_) {
      if (!delivered.isCompleted) delivered.complete();
    });
    _unsubscribePublicFeeds();
    _subscribePublicFeeds();
    await delivered.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    await probe.cancel();
  }

  @override
  void dispose() {
    _unsubscribePublicFeeds();
    _unsubscribeUserFeeds();
    super.dispose();
  }
}

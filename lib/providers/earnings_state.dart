import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/property_registry_model.dart';
import 'package:dalali/models/property_claim_model.dart';
import 'package:dalali/models/deal_model.dart';
import 'package:dalali/models/agency_fee_model.dart';
import 'package:dalali/models/earnings_model.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/earnings_service.dart';

/// Property registry, claims, deals, agency fees and earnings — the
/// "new architecture" money/ownership tables.
class EarningsState extends ChangeNotifier {
  final List<PropertyRegistryModel> _propertyRegistry = [];
  List<PropertyClaimModel> _myClaims = [];
  List<DealModel> _myDeals = [];
  List<AgencyFeeModel> _myAgencyFees = [];
  List<EarningsEntryModel> _myEarnings = [];

  final DataService _data = DataService();
  final List<StreamSubscription> _subscriptions = [];
  String? _lastUserId;

  List<PropertyRegistryModel> get propertyRegistry => _propertyRegistry;
  List<PropertyClaimModel> get myClaims => _myClaims;
  List<DealModel> get myDeals => _myDeals;
  List<AgencyFeeModel> get myAgencyFees => _myAgencyFees;
  List<EarningsEntryModel> get myEarnings => _myEarnings;

  EarningsSummaryModel get earningsSummary => EarningsService().computeSummary(_myEarnings);

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
    _myDeals = [];
    _myAgencyFees = [];
    _myEarnings = [];
    _myClaims = [];
    if (user == null) {
      notifyListeners();
      return;
    }
    _subscriptions.add(_data.getDealsForUser(user.id).listen((list) {
      _myDeals = list.cast<DealModel>();
      notifyListeners();
    }));
    _subscriptions.add(_data.getAgencyFeesForUser(user.id).listen((list) {
      _myAgencyFees = list.cast<AgencyFeeModel>();
      notifyListeners();
    }));
    _subscriptions.add(_data.getEarningsForUser(user.id).listen((list) {
      _myEarnings = list.cast<EarningsEntryModel>();
      notifyListeners();
    }));
    _subscriptions.add(_data.getClaimsForUser(user.id).listen((list) {
      _myClaims = list.cast<PropertyClaimModel>();
      notifyListeners();
    }));
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}

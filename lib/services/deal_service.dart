import 'package:dalali/models/deal_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/services/data_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// DEAL SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Manages the deal lifecycle from match to agency fee payout.
///
class DealService {
  final DataService _data = DataService();

  Future<DealModel> createDeal({
    required String propertyId,
    required String listingCreatorId,
    required String landlordPhone,
    String? seekerId,
  }) async {
    final deal = DealModel(
      dealId: 'deal_${DateTime.now().millisecondsSinceEpoch}',
      propertyId: propertyId,
      listingCreatorId: listingCreatorId,
      seekerId: seekerId,
      landlordPhone: landlordPhone,
      status: DealStatus.matched,
      createdAt: DateTime.now(),
    );
    await _data.addDeal(deal);
    return deal;
  }

  Future<void> scheduleViewing(String dealId, DateTime viewingDate) async {
    final deals = await _data.getDealsForProperty(dealId).first;
    final deal = deals.firstWhere((d) => d.dealId == dealId);
    await _data.updateDeal(deal.copyWith(
      status: DealStatus.viewingScheduled,
      viewingDate: viewingDate,
    ));
  }

  Future<void> markViewingCompleted(String dealId) async {
    final deals = await _data.getDealsForProperty(dealId).first;
    final deal = deals.firstWhere((d) => d.dealId == dealId);
    await _data.updateDeal(deal.copyWith(
      status: DealStatus.viewingCompleted,
    ));
  }

  Future<void> startNegotiating(String dealId) async {
    final deals = await _data.getDealsForProperty(dealId).first;
    final deal = deals.firstWhere((d) => d.dealId == dealId);
    await _data.updateDeal(deal.copyWith(
      status: DealStatus.negotiating,
    ));
  }

  /// Tenant confirms: "I have successfully secured this property."
  Future<void> confirmTenant(String dealId) async {
    final deals = await _data.getDealsForProperty(dealId).first;
    final deal = deals.firstWhere((d) => d.dealId == dealId);

    final updated = deal.copyWith(
      tenantConfirmed: true,
      tenantConfirmedAt: DateTime.now(),
    );

    await _data.updateDeal(updated);

    // If both confirmed, auto-advance
    if (updated.landlordConfirmed) {
      await _confirmTenancy(dealId);
    }
  }

  /// Landlord confirms: "This tenant has moved into my property."
  Future<void> confirmLandlord(String dealId) async {
    final deals = await _data.getDealsForProperty(dealId).first;
    final deal = deals.firstWhere((d) => d.dealId == dealId);

    final updated = deal.copyWith(
      landlordConfirmed: true,
      landlordConfirmedAt: DateTime.now(),
    );

    await _data.updateDeal(updated);

    // If both confirmed, auto-advance
    if (updated.tenantConfirmed) {
      await _confirmTenancy(dealId);
    }
  }

  Future<void> _confirmTenancy(String dealId) async {
    final deals = await _data.getDealsForProperty(dealId).first;
    final deal = deals.firstWhere((d) => d.dealId == dealId);

    await _data.updateDeal(deal.copyWith(
      status: DealStatus.tenancyConfirmed,
      confirmedAt: DateTime.now(),
    ));

    final property = await _data.getPropertyById(deal.propertyId);
    if (property != null) {
      await _data.updateProperty(property.copyWith(
        status: PropertyStatus.occupied,
        listingStatus: ListingStatus.tenancyConfirmed,
        tenancyConfirmed: true,
      ));
    }
  }

  Future<void> markAgencyFeePaid(String dealId) async {
    final deals = await _data.getDealsForProperty(dealId).first;
    final deal = deals.firstWhere((d) => d.dealId == dealId);
    await _data.updateDeal(deal.copyWith(
      status: DealStatus.agencyFeePaid,
    ));
  }

  Future<void> closeDeal(String dealId) async {
    final deals = await _data.getDealsForProperty(dealId).first;
    final deal = deals.firstWhere((d) => d.dealId == dealId);
    await _data.updateDeal(deal.copyWith(
      status: DealStatus.closed,
    ));
  }
}

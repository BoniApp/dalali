import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/appointment_model.dart';
import 'package:dalali/models/inquiry_model.dart';
import 'package:dalali/models/favorite_model.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/models/review_model.dart';
import 'package:dalali/models/reward_model.dart';
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/models/user_preferences_model.dart';
import 'package:dalali/models/tenancy_application_model.dart';
import 'package:dalali/models/tenancy_model.dart';
import 'package:dalali/models/move_checklist_model.dart';
import 'package:dalali/models/maintenance_request_model.dart';
import 'package:dalali/models/rent_schedule_model.dart';

class MockDataService {
  static final List<UserModel> users = [
    UserModel(
      id: 'u1',
      fullName: 'John Mwakalinga',
      email: 'john@example.com',
      phone: '+255712345678',
      role: UserRole.landlord,
      verificationStatus: VerificationStatus.verified,
      isPhoneVerified: true,
      createdAt: DateTime(2024, 1, 15),
      nationalId: '1234567890123',
      isVerifiedLandlord: true,
      lastActive: DateTime(2024, 6, 1),
      preferredLocations: ['Masaki', 'Mikocheni'],
      preferences: const UserPreferencesModel(themeMode: AppThemeMode.light, languageCode: 'en'),
    ),
    UserModel(
      id: 'u2',
      fullName: 'Asha Mohamed',
      email: 'asha@example.com',
      phone: '+255723456789',
      role: UserRole.seeker,
      isPhoneVerified: true,
      createdAt: DateTime(2024, 2, 10),
      savedSearches: ['2-bedroom apartment', 'furnished'],
      preferredLocations: ['Masaki', 'Oyster Bay'],
      preferences: const UserPreferencesModel(themeMode: AppThemeMode.system, languageCode: 'en'),
    ),
    UserModel(
      id: 'u3',
      fullName: 'Peter Kafumu',
      email: 'peter@example.com',
      phone: '+255734567890',
      role: UserRole.agent,
      verificationStatus: VerificationStatus.verified,
      isPhoneVerified: true,
      createdAt: DateTime(2024, 1, 20),
      nationalId: '9876543210987',
      agentLicense: 'AGT-2024-001',
      subscriptionTier: 1,
      isVerifiedLandlord: true,
      lastActive: DateTime(2024, 6, 5),
    ),
    UserModel(
      id: 'u4',
      fullName: 'Grace Mushi',
      email: 'grace@example.com',
      phone: '+255745678901',
      role: UserRole.landlord,
      verificationStatus: VerificationStatus.pending,
      isPhoneVerified: true,
      createdAt: DateTime(2024, 3, 5),
      preferredLocations: ['Ubungo', 'Mwanza'],
      preferences: const UserPreferencesModel(themeMode: AppThemeMode.system, languageCode: 'sw'),
    ),
  ];

  static final List<PropertyModel> properties = [
    PropertyModel(
      id: 'p1',
      title: 'Modern 3-Bedroom Apartment in Masaki',
      description:
          'Spacious apartment with modern finishes, 24/7 security, backup generator, and ample parking. Close to shops and restaurants.',
      location: 'Masaki, Dar es Salaam',
      latitude: -6.7480,
      longitude: 39.2710,
      rentPrice: 2500000,
      bedrooms: 3,
      bathrooms: 2,
      propertyType: PropertyType.apartment,
      isFurnished: true,
      hasWater: true,
      hasParking: true,
      hasSecurity: true,
      images: [
        'https://upload.wikimedia.org/wikipedia/commons/4/40/Buildings_in_Mikocheni%2C_Kinondoni_MC.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/4/44/Building_in_Kawe_ward%2C_Kinondoni_MC.jpg',
      ],
      status: PropertyStatus.available,
      listingType: ListingType.featured,
      landlordId: 'u1',
      landlordName: 'John Mwakalinga',
      landlordPhone: '+255712345678',
      isLandlordVerified: true,
      createdAt: DateTime(2024, 5, 10),
      updatedAt: DateTime(2024, 5, 11),
      viewCount: 156,
      inquiryCount: 12,
      rating: 4.5,
      reviewCount: 8,
      tags: ['near-road', 'city-center', 'modern'],
      rentAmount: 2500000,
      paymentOptions: [PaymentTerm.monthly, PaymentTerm.threeMonths, PaymentTerm.sixMonths],
      minimumAcceptedTerm: PaymentTerm.threeMonths,
      depositRequired: true,
      depositAmount: 2500000,
      utilities: const PropertyUtilities(
        water: UtilityResponsibility.shared,
        electricity: UtilityResponsibility.tenant,
        internet: InternetType.tenant,
        wasteCollection: UtilityResponsibility.landlord,
        security: SecurityType.included,
      ),
    ),
    PropertyModel(
      id: 'p2',
      title: 'Affordable Bedsitter in Ubungo',
      description:
          'Clean and secure bedsitter near Ubungo bus terminal. Water and electricity included.',
      location: 'Ubungo, Dar es Salaam',
      latitude: -6.7924,
      longitude: 39.2083,
      rentPrice: 250000,
      bedrooms: 1,
      bathrooms: 1,
      propertyType: PropertyType.bedsitter,
      isFurnished: false,
      hasWater: true,
      hasParking: false,
      hasSecurity: true,
      images: [
        'https://upload.wikimedia.org/wikipedia/commons/f/f4/Building_in_Chang%27ombe_ward%2C_Temeke_MC%2C_Dar_es_Salaam.jpg',
      ],
      status: PropertyStatus.available,
      landlordId: 'u4',
      landlordName: 'Grace Mushi',
      landlordPhone: '+255745678901',
      createdAt: DateTime(2024, 5, 15),
      updatedAt: DateTime(2024, 5, 16),
      viewCount: 89,
      inquiryCount: 5,
      tags: ['budget', 'student-friendly'],
      rentAmount: 250000,
      paymentOptions: [PaymentTerm.monthly],
      minimumAcceptedTerm: PaymentTerm.monthly,
      depositRequired: true,
      depositAmount: 250000,
      utilities: const PropertyUtilities(
        water: UtilityResponsibility.landlord,
        electricity: UtilityResponsibility.landlord,
        internet: InternetType.notAvailable,
        wasteCollection: UtilityResponsibility.landlord,
        security: SecurityType.included,
      ),
    ),
    PropertyModel(
      id: 'p3',
      title: 'Family House with Garden in Mikocheni',
      description:
          'Beautiful standalone house with large garden, parking for 3 cars, servant quarter, and close to international schools.',
      location: 'Mikocheni, Dar es Salaam',
      latitude: -6.7630,
      longitude: 39.2500,
      rentPrice: 4500000,
      bedrooms: 4,
      bathrooms: 3,
      propertyType: PropertyType.house,
      isFurnished: false,
      hasWater: true,
      hasParking: true,
      hasSecurity: true,
      sharedCompound: false,
      hasBorehole: true,
      images: [
        'https://upload.wikimedia.org/wikipedia/commons/9/9a/Building_in_Kiwalani%2C_Ilala_MC%2C_Dar_es_Salaam.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/5/59/Building_in_Makuburi%2C_Ilala_MC%2C_Dar_es_Salaam.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/8/8e/Building_in_Gongolamboto%2C_Ilala_MC.jpg',
      ],
      status: PropertyStatus.available,
      listingType: ListingType.featured,
      landlordId: 'u3',
      landlordName: 'Peter Kafumu (Agent)',
      landlordPhone: '+255734567890',
      isLandlordVerified: true,
      createdAt: DateTime(2024, 5, 1),
      updatedAt: DateTime(2024, 5, 2),
      viewCount: 234,
      inquiryCount: 18,
      rating: 4.8,
      reviewCount: 12,
      tags: ['family', 'garden', 'schools-nearby'],
      rentAmount: 4500000,
      paymentOptions: [PaymentTerm.threeMonths, PaymentTerm.sixMonths, PaymentTerm.twelveMonths],
      minimumAcceptedTerm: PaymentTerm.sixMonths,
      depositRequired: true,
      depositAmount: 4500000,
      utilities: const PropertyUtilities(
        water: UtilityResponsibility.shared,
        electricity: UtilityResponsibility.shared,
        internet: InternetType.included,
        wasteCollection: UtilityResponsibility.shared,
        security: SecurityType.included,
      ),
    ),
    PropertyModel(
      id: 'p4',
      title: 'Office Space in City Centre',
      description:
          'Professional office space suitable for startups and SMEs. Conference room included.',
      location: 'City Centre, Dodoma',
      latitude: -6.1731,
      longitude: 35.7419,
      rentPrice: 1800000,
      bedrooms: 0,
      bathrooms: 2,
      propertyType: PropertyType.office,
      isFurnished: true,
      hasWater: true,
      hasParking: true,
      hasSecurity: true,
      images: [
        'https://upload.wikimedia.org/wikipedia/commons/1/17/British_council_Dar_es_salaam.jpg',
      ],
      status: PropertyStatus.available,
      landlordId: 'u1',
      landlordName: 'John Mwakalinga',
      landlordPhone: '+255712345678',
      isLandlordVerified: true,
      createdAt: DateTime(2024, 5, 20),
      updatedAt: DateTime(2024, 5, 21),
      viewCount: 67,
      inquiryCount: 3,
      tags: ['business', 'conference-room'],
      rentAmount: 1800000,
      paymentOptions: [PaymentTerm.monthly, PaymentTerm.threeMonths, PaymentTerm.negotiable],
      minimumAcceptedTerm: PaymentTerm.monthly,
      depositRequired: true,
      depositAmount: 1800000,
      utilities: const PropertyUtilities(
        water: UtilityResponsibility.landlord,
        electricity: UtilityResponsibility.landlord,
        internet: InternetType.included,
        wasteCollection: UtilityResponsibility.landlord,
        security: SecurityType.included,
      ),
    ),
    PropertyModel(
      id: 'p5',
      title: '2-Bedroom Flat in Mwanza',
      description:
          'Lovely flat near Lake Victoria with beautiful views. Good security and water availability.',
      location: 'Nyamagana, Mwanza',
      latitude: -2.5167,
      longitude: 32.9000,
      rentPrice: 800000,
      bedrooms: 2,
      bathrooms: 1,
      propertyType: PropertyType.apartment,
      isFurnished: false,
      hasWater: true,
      hasParking: false,
      hasSecurity: true,
      images: [
        'https://upload.wikimedia.org/wikipedia/commons/b/bb/Building_in_Buguruni%2C_Ilala_MC%2C_Dar_es_Salaam.jpg',
      ],
      status: PropertyStatus.available,
      listingType: ListingType.basic,
      landlordId: 'u4',
      landlordName: 'Grace Mushi',
      landlordPhone: '+255745678901',
      createdAt: DateTime(2024, 5, 25),
      updatedAt: DateTime(2024, 5, 26),
      viewCount: 45,
      inquiryCount: 2,
      tags: ['lake-view', 'scenic'],
      rentAmount: 800000,
      paymentOptions: [PaymentTerm.monthly, PaymentTerm.threeMonths],
      minimumAcceptedTerm: PaymentTerm.monthly,
      depositRequired: true,
      depositAmount: 800000,
      utilities: const PropertyUtilities(
        water: UtilityResponsibility.shared,
        electricity: UtilityResponsibility.tenant,
        internet: InternetType.notAvailable,
        wasteCollection: UtilityResponsibility.shared,
        security: SecurityType.included,
      ),
    ),
    PropertyModel(
      id: 'p6',
      title: 'Luxury Villa in Oyster Bay',
      description:
          'Stunning luxury villa with swimming pool, 5 bedrooms, smart home features, and ocean views.',
      location: 'Oyster Bay, Dar es Salaam',
      latitude: -6.7400,
      longitude: 39.2800,
      rentPrice: 8500000,
      bedrooms: 5,
      bathrooms: 4,
      propertyType: PropertyType.villa,
      isFurnished: true,
      hasWater: true,
      hasParking: true,
      hasSecurity: true,
      images: [
        'https://upload.wikimedia.org/wikipedia/commons/f/f4/Colonial-Era_Facade_-_Dar_es_Salaam_-_Tanzania_-_01.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/a/ad/Colonial-Era_Facade_-_Dar_es_Salaam_-_Tanzania_-_02.jpg',
      ],
      status: PropertyStatus.available,
      listingType: ListingType.featured,
      landlordId: 'u1',
      landlordName: 'John Mwakalinga',
      landlordPhone: '+255712345678',
      isLandlordVerified: true,
      createdAt: DateTime(2024, 4, 28),
      updatedAt: DateTime(2024, 4, 29),
      viewCount: 412,
      inquiryCount: 25,
      rating: 4.9,
      reviewCount: 20,
      isBoosted: true,
      boostExpiresAt: DateTime(2024, 12, 31),
      tags: ['luxury', 'pool', 'ocean-view', 'smart-home'],
      rentAmount: 8500000,
      paymentOptions: [PaymentTerm.sixMonths, PaymentTerm.twelveMonths],
      minimumAcceptedTerm: PaymentTerm.sixMonths,
      depositRequired: true,
      depositAmount: 8500000,
      utilities: const PropertyUtilities(
        water: UtilityResponsibility.landlord,
        electricity: UtilityResponsibility.landlord,
        internet: InternetType.included,
        wasteCollection: UtilityResponsibility.landlord,
        security: SecurityType.included,
      ),
    ),
  ];

  static final List<AppointmentModel> appointments = [
    AppointmentModel(
      id: 'a1',
      propertyId: 'p1',
      propertyTitle: 'Modern 3-Bedroom Apartment in Masaki',
      seekerId: 'u2',
      seekerName: 'Asha Mohamed',
      seekerPhone: '+255723456789',
      landlordId: 'u1',
      scheduledDate: DateTime(2024, 6, 10, 14, 0),
      notes: 'I would like to see the kitchen and parking area.',
      status: AppointmentStatus.pending,
      createdAt: DateTime(2024, 6, 5),
    ),
  ];

  static final List<InquiryModel> inquiries = [
    InquiryModel(
      id: 'i1',
      propertyId: 'p1',
      propertyTitle: 'Modern 3-Bedroom Apartment in Masaki',
      seekerId: 'u2',
      seekerName: 'Asha Mohamed',
      seekerPhone: '+255723456789',
      landlordId: 'u1',
      message: 'Is the price negotiable? I can pay 2.2M.',
      createdAt: DateTime(2024, 6, 4),
    ),
    InquiryModel(
      id: 'i2',
      propertyId: 'p3',
      propertyTitle: 'Family House with Garden in Mikocheni',
      seekerId: 'u2',
      seekerName: 'Asha Mohamed',
      seekerPhone: '+255723456789',
      landlordId: 'u3',
      message: 'Do you allow pets?',
      createdAt: DateTime(2024, 6, 3),
    ),
  ];

  static final List<FavoriteModel> favorites = [];

  // ═══ HTN: Move Listings ════════════════════════════════════
  static final List<MoveListingModel> moveListings = [
    MoveListingModel(
      id: 'm1',
      userId: 'u2',
      userName: 'Asha Mohamed',
      currentPropertyTitle: '1-Bedroom in Kariakoo',
      currentLocation: 'Kariakoo, Dar es Salaam',
      moveDate: DateTime(2024, 7, 15),
      status: MoveStatus.planning,
      budgetMin: 1500000,
      budgetMax: 3000000,
      preferredLocation: 'Masaki',
      createdAt: DateTime(2024, 6, 1),
    ),
    MoveListingModel(
      id: 'm2',
      userId: 'u4',
      userName: 'Grace Mushi',
      currentPropertyTitle: '2-Bedroom in Ubungo',
      currentLocation: 'Ubungo, Dar es Salaam',
      moveDate: DateTime(2024, 8, 1),
      status: MoveStatus.active,
      budgetMin: 500000,
      budgetMax: 1200000,
      preferredLocation: 'Mwanza',
      createdAt: DateTime(2024, 5, 20),
    ),
  ];

  // ═══ HTN: Reviews ══════════════════════════════════════════
  static final List<ReviewModel> reviews = [
    ReviewModel(
      id: 'r1',
      propertyId: 'p1',
      propertyTitle: 'Modern 3-Bedroom Apartment in Masaki',
      reviewerId: 'u2',
      reviewerName: 'Asha Mohamed',
      stayVerified: true,
      cleanliness: 4.5,
      valueForMoney: 4.0,
      safety: 5.0,
      communication: 4.5,
      fairness: 4.0,
      maintenance: 4.5,
      comment: 'Great place, landlord was responsive. Water pressure could be better.',
      createdAt: DateTime(2024, 5, 20),
    ),
    ReviewModel(
      id: 'r2',
      propertyId: 'p3',
      propertyTitle: 'Family House with Garden in Mikocheni',
      reviewerId: 'u2',
      reviewerName: 'Asha Mohamed',
      stayVerified: true,
      cleanliness: 5.0,
      valueForMoney: 4.5,
      safety: 5.0,
      communication: 5.0,
      fairness: 5.0,
      maintenance: 4.5,
      comment: 'Perfect for families. Garden is beautiful and the agent was very professional.',
      createdAt: DateTime(2024, 5, 18),
    ),
  ];

  // ═══ HTN: Rewards ══════════════════════════════════════════
  static final List<RewardModel> rewards = [
    RewardModel(
      id: 'rw1',
      userId: 'u2',
      type: RewardType.listingBonus,
      points: 100,
      description: 'Listed your home during a move',
      createdAt: DateTime(2024, 6, 1),
      claimed: true,
      claimedAt: DateTime(2024, 6, 2),
    ),
    RewardModel(
      id: 'rw2',
      userId: 'u2',
      type: RewardType.reviewSubmitted,
      points: 50,
      description: 'Submitted a verified review',
      createdAt: DateTime(2024, 5, 21),
    ),
  ];

  static List<PropertyModel> getPropertiesByLandlord(String landlordId) {
    return properties.where((p) => p.landlordId == landlordId).toList();
  }

  static List<PropertyModel> getFeaturedProperties() {
    return properties.where((p) => p.listingType == ListingType.featured).toList();
  }

  // ═══ HTN: Neighbourhood Reports ════════════════════════════
  static final List<NeighbourhoodReportModel> neighbourhoodReports = [
    NeighbourhoodReportModel(
      id: 'nr1',
      reporterId: 'u2',
      reporterName: 'Asha Mohamed',
      reporterVerified: true,
      reporterTrustScore: 85,
      type: IncidentType.noise,
      severity: IncidentSeverity.medium,
      location: 'Masaki, Dar es Salaam',
      latitude: -6.7485,
      longitude: 39.2715,
      description: 'Loud construction noise after 10pm for the past week.',
      reportedAt: DateTime(2024, 6, 1),
    ),
    NeighbourhoodReportModel(
      id: 'nr2',
      reporterId: 'u4',
      reporterName: 'Grace Mushi',
      reporterVerified: false,
      reporterTrustScore: 50,
      type: IncidentType.theft,
      severity: IncidentSeverity.high,
      location: 'Ubungo, Dar es Salaam',
      latitude: -6.7930,
      longitude: 39.2090,
      description: 'Phone stolen near bus terminal. Be cautious.',
      reportedAt: DateTime(2024, 6, 3),
    ),
    NeighbourhoodReportModel(
      id: 'nr3',
      reporterId: 'u2',
      reporterName: 'Asha Mohamed',
      reporterVerified: true,
      reporterTrustScore: 85,
      type: IncidentType.scam,
      severity: IncidentSeverity.medium,
      location: 'Kariakoo, Dar es Salaam',
      latitude: -6.8200,
      longitude: 39.2700,
      description: 'Fake rental deposit scam operating in the area.',
      reportedAt: DateTime(2024, 5, 20),
    ),
    NeighbourhoodReportModel(
      id: 'nr4',
      reporterId: 'u1',
      reporterName: 'John Mwakalinga',
      reporterVerified: true,
      reporterTrustScore: 90,
      type: IncidentType.hazard,
      severity: IncidentSeverity.low,
      location: 'Mikocheni, Dar es Salaam',
      latitude: -6.7635,
      longitude: 39.2505,
      description: 'Potholes on main road causing minor accidents.',
      reportedAt: DateTime(2024, 6, 5),
    ),
  ];

  static List<PropertyModel> getFilteredProperties({
    String? location,
    double? minPrice,
    double? maxPrice,
    int? bedrooms,
    bool? furnished,
    bool? water,
    bool? parking,
    PropertyType? type,
    List<PaymentTerm>? paymentTerms,
  }) {
    return properties.where((p) {
      if (p.status != PropertyStatus.available) return false;
      if (location != null && location.isNotEmpty) {
        if (!p.location.toLowerCase().contains(location.toLowerCase())) return false;
      }
      if (minPrice != null && p.rentPrice < minPrice) return false;
      if (maxPrice != null && p.rentPrice > maxPrice) return false;
      if (bedrooms != null && p.bedrooms != bedrooms) return false;
      if (furnished != null && p.isFurnished != furnished) return false;
      if (water != null && p.hasWater != water) return false;
      if (parking != null && p.hasParking != parking) return false;
      if (type != null && p.propertyType != type) return false;
      if (paymentTerms != null && paymentTerms.isNotEmpty) {
        final hasMatch = p.paymentOptions.any((option) => paymentTerms.contains(option));
        if (!hasMatch) return false;
      }
      return true;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  //  TENANCY LIFECYCLE
  // ═══════════════════════════════════════════════════════════

  static final List<TenancyApplicationModel> tenancyApplications = [
    TenancyApplicationModel(
      id: 'ta1',
      propertyId: 'p1',
      propertyTitle: 'Modern 3-Bedroom Apartment in Masaki',
      tenantId: 'u2',
      tenantName: 'Asha Mohamed',
      tenantPhone: '+255723456789',
      landlordId: 'u1',
      landlordName: 'John Mwakalinga',
      status: ApplicationStatus.pending,
      createdAt: DateTime(2024, 6, 8),
      notes: 'I would like to move in by July 1st.',
    ),
    TenancyApplicationModel(
      id: 'ta2',
      propertyId: 'p5',
      propertyTitle: '2-Bedroom Flat in Mwanza',
      tenantId: 'u2',
      tenantName: 'Asha Mohamed',
      tenantPhone: '+255723456789',
      landlordId: 'u4',
      landlordName: 'Grace Mushi',
      status: ApplicationStatus.approved,
      createdAt: DateTime(2024, 5, 20),
      resolvedAt: DateTime(2024, 5, 22),
    ),
  ];

  static final List<TenancyModel> tenancies = [
    TenancyModel(
      id: 't1',
      tenantId: 'u2',
      tenantName: 'Asha Mohamed',
      landlordId: 'u4',
      landlordName: 'Grace Mushi',
      propertyId: 'p5',
      propertyTitle: '2-Bedroom Flat in Mwanza',
      propertyLocation: 'Nyamagana, Mwanza',
      moveInDate: DateTime(2024, 7, 1),
      expectedMoveOutDate: DateTime(2025, 6, 30),
      rentAmount: 800000,
      depositAmount: 1600000,
      status: TenancyStatus.upcoming,
      createdAt: DateTime(2024, 5, 22),
    ),
    TenancyModel(
      id: 't2',
      tenantId: 'u2',
      tenantName: 'Asha Mohamed',
      landlordId: 'u1',
      landlordName: 'John Mwakalinga',
      propertyId: 'p1',
      propertyTitle: 'Modern 3-Bedroom Apartment in Masaki',
      propertyLocation: 'Masaki, Dar es Salaam',
      moveInDate: DateTime(2024, 3, 1),
      expectedMoveOutDate: DateTime(2025, 2, 28),
      rentAmount: 2500000,
      depositAmount: 5000000,
      status: TenancyStatus.active,
      createdAt: DateTime(2024, 2, 15),
      activatedAt: DateTime(2024, 3, 1),
    ),
  ];

  static final List<MoveChecklistModel> moveChecklists = [
    MoveChecklistModel(
      id: 'mc1',
      userId: 'u2',
      tenancyId: 't1',
      items: const [
        ChecklistItem(id: '1', title: 'Pay Deposit', completed: true, completedAt: null),
        ChecklistItem(id: '2', title: 'Sign Agreement', completed: true, completedAt: null),
        ChecklistItem(id: '3', title: 'Confirm Move Date', completed: true, completedAt: null),
        ChecklistItem(id: '4', title: 'Arrange Transport', completed: false),
        ChecklistItem(id: '5', title: 'Confirm Utilities', completed: false),
        ChecklistItem(id: '6', title: 'Pack Belongings', completed: false),
        ChecklistItem(id: '7', title: 'Notify Old Landlord', completed: true, completedAt: null),
        ChecklistItem(id: '8', title: 'Update Address', completed: false),
      ],
      createdAt: DateTime(2024, 5, 25),
      updatedAt: DateTime(2024, 6, 5),
    ),
  ];

  static final List<MaintenanceRequestModel> maintenanceRequests = [
    MaintenanceRequestModel(
      id: 'mr1',
      tenantId: 'u2',
      tenantName: 'Asha Mohamed',
      landlordId: 'u1',
      propertyId: 'p1',
      propertyTitle: 'Modern 3-Bedroom Apartment in Masaki',
      category: MaintenanceCategory.plumbing,
      description: 'Kitchen sink is leaking slowly under the cabinet.',
      status: MaintenanceStatus.inProgress,
      createdAt: DateTime(2024, 6, 1),
    ),
    MaintenanceRequestModel(
      id: 'mr2',
      tenantId: 'u2',
      tenantName: 'Asha Mohamed',
      landlordId: 'u1',
      propertyId: 'p1',
      propertyTitle: 'Modern 3-Bedroom Apartment in Masaki',
      category: MaintenanceCategory.electrical,
      description: 'One socket in the master bedroom has no power.',
      status: MaintenanceStatus.open,
      createdAt: DateTime(2024, 6, 5),
    ),
  ];

  static final List<RentScheduleModel> rentSchedules = [
    RentScheduleModel(
      id: 'rs1',
      tenancyId: 't2',
      tenantId: 'u2',
      propertyTitle: 'Modern 3-Bedroom Apartment in Masaki',
      dueDate: DateTime(2024, 7, 1),
      amount: 2500000,
      status: PaymentStatus.paid,
      paidAt: DateTime(2024, 6, 28),
    ),
    RentScheduleModel(
      id: 'rs2',
      tenancyId: 't2',
      tenantId: 'u2',
      propertyTitle: 'Modern 3-Bedroom Apartment in Masaki',
      dueDate: DateTime(2024, 8, 1),
      amount: 2500000,
      status: PaymentStatus.pending,
    ),
  ];
}

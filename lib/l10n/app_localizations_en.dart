import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Dalali';

  @override
  String get welcome => 'Welcome';

  @override
  String get welcomeToDalali => 'Welcome to Dalali';

  @override
  String get appSubtitle => 'Tanzania\'s trusted property platform';

  @override
  String get howWouldYouLikeToUse => 'How would you like to use Dalali?';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get signIn => 'Sign In';

  @override
  String get signInWithEmail => 'Sign In with Email';

  @override
  String get signUp => 'Sign Up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get logout => 'Logout';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get enterYourEmail => 'Enter your email';

  @override
  String get send => 'Send';

  @override
  String get passwordResetSent => 'Password reset email sent!';

  @override
  String get home => 'Home';

  @override
  String get saved => 'Saved';

  @override
  String get visits => 'Visits';

  @override
  String get messages => 'Messages';

  @override
  String get profile => 'Profile';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get addProperty => 'Add Property';

  @override
  String get inquiries => 'Inquiries';

  @override
  String get add => 'Add';

  @override
  String get houseSeeker => 'House Seeker';

  @override
  String get landlord => 'Landlord';

  @override
  String get agent => 'Agent';

  @override
  String get findYourHome => 'Find your perfect home';

  @override
  String get listAndManage => 'List and manage your properties';

  @override
  String get manageClients => 'Manage clients and earn commissions';

  @override
  String get featuredProperties => 'Featured Properties';

  @override
  String get allProperties => 'All Properties';

  @override
  String get searchResults => 'Search Results';

  @override
  String get searchHint => 'Search by location or name...';

  @override
  String get noPropertiesFound => 'No properties found';

  @override
  String get propertyDetails => 'Property Details';

  @override
  String get amenities => 'Amenities';

  @override
  String get description => 'Description';

  @override
  String get location => 'Location';

  @override
  String get reviews => 'Reviews';

  @override
  String get writeReview => 'Write Review';

  @override
  String get noReviewsYet => 'No reviews yet';

  @override
  String get scheduleViewing => 'Schedule Viewing';

  @override
  String get reportListing => 'Report Fake Listing';

  @override
  String get neighbourhoodSafety => 'Neighbourhood Safety';

  @override
  String get reportIncident => 'Report Incident';

  @override
  String get safetyScore => 'Safety Score';

  @override
  String get activeIncidents => 'active incidents nearby';

  @override
  String get startYourMove => 'Start Your Move';

  @override
  String get movingSoon => 'Moving soon?';

  @override
  String get listYourHome => 'List your current home & find your next one.';

  @override
  String get myMove => 'My Move';

  @override
  String get moveStatus => 'Move Status';

  @override
  String get moveDetails => 'Move Details';

  @override
  String get activate => 'Activate';

  @override
  String get complete => 'Complete';

  @override
  String get cancelMove => 'Cancel Move';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get themeSystem => 'System Theme';

  @override
  String get themeLight => 'Light Theme';

  @override
  String get themeDark => 'Dark Theme';

  @override
  String get english => 'English';

  @override
  String get kiswahili => 'Kiswahili';

  @override
  String get preferencesSaved => 'Preferences saved';

  @override
  String get furnished => 'Furnished';

  @override
  String get water => 'Water';

  @override
  String get parking => 'Parking';

  @override
  String get security => 'Security';

  @override
  String bedrooms(int count) {
    return '$count Bedrooms';
  }

  @override
  String bathrooms(int count) {
    return '$count Bathrooms';
  }

  @override
  String pricePerMonth(String price) {
    return '$price / month';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get submit => 'Submit';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get rewardPoints => 'Reward Points';

  @override
  String pointsEarned(int points) {
    return '$points points earned';
  }

  @override
  String get pending => 'pending';

  @override
  String pendingCount(int count) {
    return '$count pending';
  }

  @override
  String get notLoggedIn => 'You are not logged in';

  @override
  String get verifiedAccount => 'Verified Account';

  @override
  String get verificationPending => 'Verification Pending';

  @override
  String get unverifiedAccount => 'Unverified Account';

  @override
  String get settingsSubtitle => 'Theme, language & more';

  @override
  String get phone => 'Phone';

  @override
  String get role => 'Role';

  @override
  String get nationalId => 'National ID';

  @override
  String get agentLicense => 'Agent License';

  @override
  String get planning => 'Planning';

  @override
  String get active => 'Active';

  @override
  String get verifyMyAccount => 'Verify My Account';

  @override
  String get accountVerification => 'Account Verification';

  @override
  String get verifyAccountDescription => 'To verify your account, you need to provide:';

  @override
  String get nidaRequired => 'National ID (NIDA)';

  @override
  String get phoneVerificationRequired => 'Phone number verification';

  @override
  String get verifiedUsersBenefit => 'Verified users get a badge and more trust from clients.';

  @override
  String get later => 'Later';

  @override
  String get startVerification => 'Start Verification';

  @override
  String get verificationSubmitted => 'Verification request submitted!';

  @override
  String get opportunities => 'Opportunities';

  @override
  String get earnings => 'Earnings';

  @override
  String get totalEarned => 'Total Earned';

  @override
  String get pendingEarnings => 'Pending Earnings';

  @override
  String get withdrawableBalance => 'Withdrawable Balance';

  @override
  String get successfulListings => 'Successful Listings';

  @override
  String get agencyFeeHistory => 'Agency Fee History';

  @override
  String get noEarningsYet => 'No earnings yet. List a property to start earning!';

  @override
  String get opportunityFeed => 'Opportunity Feed';

  @override
  String get highDemandAreas => 'High Demand Areas';

  @override
  String get recentlyListed => 'Recently Listed';

  @override
  String get fastMoving => 'Fast Moving';

  @override
  String get nearbyVacancies => 'Nearby Vacancies';

  @override
  String get dealTracking => 'Deal Tracking';

  @override
  String get dealStatus => 'Deal Status';

  @override
  String get viewingScheduled => 'Viewing Scheduled';

  @override
  String get viewingCompleted => 'Viewing Completed';

  @override
  String get negotiating => 'Negotiating';

  @override
  String get tenancyConfirmed => 'Tenancy Confirmed';

  @override
  String get agencyFeePending => 'Agency Fee Pending';

  @override
  String get agencyFeePaid => 'Agency Fee Paid';

  @override
  String get confirmTenancy => 'Confirm Tenancy';

  @override
  String get tenantConfirmation => 'I have successfully secured this property.';

  @override
  String get landlordConfirmation => 'This tenant has moved into my property.';

  @override
  String get claimProperty => 'Claim Property';

  @override
  String get propertyAlreadyExists => 'This property already exists in Dalali.';

  @override
  String get requestOwnershipClaim => 'Request Ownership Claim';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get cancelListing => 'Cancel Listing';

  @override
  String get duplicateDetected => 'Duplicate Detected';

  @override
  String get claimSubmitted => 'Claim submitted for review.';

  @override
  String get trustBadgeVerifiedLandlord => 'Verified Landlord';

  @override
  String get trustBadgeVerifiedAgent => 'Verified Agent';

  @override
  String get trustBadgeVerifiedProperty => 'Verified Property';

  @override
  String get trustBadgeVerifiedCreator => 'Verified Listing Creator';
}

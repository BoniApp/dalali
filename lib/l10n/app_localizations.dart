import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw')
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'Dalali'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @welcomeToDalali.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Dalali'**
  String get welcomeToDalali;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tanzania\'s trusted property platform'**
  String get appSubtitle;

  /// No description provided for @howWouldYouLikeToUse.
  ///
  /// In en, this message translates to:
  /// **'How would you like to use Dalali?'**
  String get howWouldYouLikeToUse;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signInWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Sign In with Email'**
  String get signInWithEmail;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get pleaseEnterEmail;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get pleaseEnterPassword;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @enterYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterYourEmail;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent!'**
  String get passwordResetSent;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visits;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet. Open a property and tap the chat icon to message the landlord or agent.'**
  String get noConversationsYet;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get noMessagesYet;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get typeMessage;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @addProperty.
  ///
  /// In en, this message translates to:
  /// **'Add Property'**
  String get addProperty;

  /// No description provided for @inquiries.
  ///
  /// In en, this message translates to:
  /// **'Inquiries'**
  String get inquiries;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @houseSeeker.
  ///
  /// In en, this message translates to:
  /// **'House Seeker'**
  String get houseSeeker;

  /// No description provided for @landlord.
  ///
  /// In en, this message translates to:
  /// **'Landlord'**
  String get landlord;

  /// No description provided for @agent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agent;

  /// No description provided for @findYourHome.
  ///
  /// In en, this message translates to:
  /// **'Find your perfect home'**
  String get findYourHome;

  /// No description provided for @listAndManage.
  ///
  /// In en, this message translates to:
  /// **'List and manage your properties'**
  String get listAndManage;

  /// No description provided for @manageClients.
  ///
  /// In en, this message translates to:
  /// **'Manage clients and earn commissions'**
  String get manageClients;

  /// No description provided for @featuredProperties.
  ///
  /// In en, this message translates to:
  /// **'Featured Properties'**
  String get featuredProperties;

  /// No description provided for @allProperties.
  ///
  /// In en, this message translates to:
  /// **'All Properties'**
  String get allProperties;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResults;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by location or name...'**
  String get searchHint;

  /// No description provided for @noPropertiesFound.
  ///
  /// In en, this message translates to:
  /// **'No properties found'**
  String get noPropertiesFound;

  /// No description provided for @propertyDetails.
  ///
  /// In en, this message translates to:
  /// **'Property Details'**
  String get propertyDetails;

  /// No description provided for @amenities.
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get amenities;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write Review'**
  String get writeReview;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @scheduleViewing.
  ///
  /// In en, this message translates to:
  /// **'Schedule Viewing'**
  String get scheduleViewing;

  /// No description provided for @reportListing.
  ///
  /// In en, this message translates to:
  /// **'Report Fake Listing'**
  String get reportListing;

  /// No description provided for @neighbourhoodSafety.
  ///
  /// In en, this message translates to:
  /// **'Neighbourhood Safety'**
  String get neighbourhoodSafety;

  /// No description provided for @reportIncident.
  ///
  /// In en, this message translates to:
  /// **'Report Incident'**
  String get reportIncident;

  /// No description provided for @safetyScore.
  ///
  /// In en, this message translates to:
  /// **'Safety Score'**
  String get safetyScore;

  /// No description provided for @activeIncidents.
  ///
  /// In en, this message translates to:
  /// **'active incidents nearby'**
  String get activeIncidents;

  /// No description provided for @startYourMove.
  ///
  /// In en, this message translates to:
  /// **'Start Your Move'**
  String get startYourMove;

  /// No description provided for @movingSoon.
  ///
  /// In en, this message translates to:
  /// **'Moving soon?'**
  String get movingSoon;

  /// No description provided for @listYourHome.
  ///
  /// In en, this message translates to:
  /// **'List your current home & find your next one.'**
  String get listYourHome;

  /// No description provided for @myMove.
  ///
  /// In en, this message translates to:
  /// **'My Move'**
  String get myMove;

  /// No description provided for @moveStatus.
  ///
  /// In en, this message translates to:
  /// **'Move Status'**
  String get moveStatus;

  /// No description provided for @moveDetails.
  ///
  /// In en, this message translates to:
  /// **'Move Details'**
  String get moveDetails;

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @cancelMove.
  ///
  /// In en, this message translates to:
  /// **'Cancel Move'**
  String get cancelMove;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Theme'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light Theme'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get themeDark;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @kiswahili.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili'**
  String get kiswahili;

  /// No description provided for @preferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved'**
  String get preferencesSaved;

  /// No description provided for @furnished.
  ///
  /// In en, this message translates to:
  /// **'Furnished'**
  String get furnished;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @parking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get parking;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @bedrooms.
  ///
  /// In en, this message translates to:
  /// **'{count} Bedrooms'**
  String bedrooms(int count);

  /// No description provided for @bathrooms.
  ///
  /// In en, this message translates to:
  /// **'{count} Bathrooms'**
  String bathrooms(int count);

  /// No description provided for @pricePerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price} / month'**
  String pricePerMonth(String price);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @rewardPoints.
  ///
  /// In en, this message translates to:
  /// **'Reward Points'**
  String get rewardPoints;

  /// No description provided for @pointsEarned.
  ///
  /// In en, this message translates to:
  /// **'{points} points earned'**
  String pointsEarned(int points);

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get pending;

  /// No description provided for @pendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String pendingCount(int count);

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'You are not logged in'**
  String get notLoggedIn;

  /// No description provided for @verifiedAccount.
  ///
  /// In en, this message translates to:
  /// **'Verified Account'**
  String get verifiedAccount;

  /// No description provided for @verificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification Pending'**
  String get verificationPending;

  /// No description provided for @unverifiedAccount.
  ///
  /// In en, this message translates to:
  /// **'Unverified Account'**
  String get unverifiedAccount;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, language & more'**
  String get settingsSubtitle;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @nationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get nationalId;

  /// No description provided for @agentLicense.
  ///
  /// In en, this message translates to:
  /// **'Agent License'**
  String get agentLicense;

  /// No description provided for @planning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get planning;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @verifyMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Verify My Account'**
  String get verifyMyAccount;

  /// No description provided for @accountVerification.
  ///
  /// In en, this message translates to:
  /// **'Account Verification'**
  String get accountVerification;

  /// No description provided for @verifyAccountDescription.
  ///
  /// In en, this message translates to:
  /// **'To verify your account, you need to provide:'**
  String get verifyAccountDescription;

  /// No description provided for @nidaRequired.
  ///
  /// In en, this message translates to:
  /// **'National ID (NIDA), Voter\'s Card or Driver\'s Licence'**
  String get nidaRequired;

  /// No description provided for @phoneVerificationRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number verification'**
  String get phoneVerificationRequired;

  /// No description provided for @verifiedUsersBenefit.
  ///
  /// In en, this message translates to:
  /// **'Verified users get a badge and more trust from clients.'**
  String get verifiedUsersBenefit;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @startVerification.
  ///
  /// In en, this message translates to:
  /// **'Start Verification'**
  String get startVerification;

  /// No description provided for @verificationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Verification request submitted!'**
  String get verificationSubmitted;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @totalEarned.
  ///
  /// In en, this message translates to:
  /// **'Total Earned'**
  String get totalEarned;

  /// No description provided for @pendingEarnings.
  ///
  /// In en, this message translates to:
  /// **'Pending Earnings'**
  String get pendingEarnings;

  /// No description provided for @withdrawableBalance.
  ///
  /// In en, this message translates to:
  /// **'Withdrawable Balance'**
  String get withdrawableBalance;

  /// No description provided for @successfulListings.
  ///
  /// In en, this message translates to:
  /// **'Successful Listings'**
  String get successfulListings;

  /// No description provided for @agencyFeeHistory.
  ///
  /// In en, this message translates to:
  /// **'Agency Fee History'**
  String get agencyFeeHistory;

  /// No description provided for @noEarningsYet.
  ///
  /// In en, this message translates to:
  /// **'No earnings yet. List a property to start earning!'**
  String get noEarningsYet;

  /// No description provided for @nearbyVacancies.
  ///
  /// In en, this message translates to:
  /// **'Nearby Vacancies'**
  String get nearbyVacancies;

  /// No description provided for @dealTracking.
  ///
  /// In en, this message translates to:
  /// **'Deal Tracking'**
  String get dealTracking;

  /// No description provided for @dealStatus.
  ///
  /// In en, this message translates to:
  /// **'Deal Status'**
  String get dealStatus;

  /// No description provided for @viewingScheduled.
  ///
  /// In en, this message translates to:
  /// **'Viewing Scheduled'**
  String get viewingScheduled;

  /// No description provided for @viewingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Viewing Completed'**
  String get viewingCompleted;

  /// No description provided for @negotiating.
  ///
  /// In en, this message translates to:
  /// **'Negotiating'**
  String get negotiating;

  /// No description provided for @tenancyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Tenancy Confirmed'**
  String get tenancyConfirmed;

  /// No description provided for @agencyFeePending.
  ///
  /// In en, this message translates to:
  /// **'Agency Fee Pending'**
  String get agencyFeePending;

  /// No description provided for @agencyFeePaid.
  ///
  /// In en, this message translates to:
  /// **'Agency Fee Paid'**
  String get agencyFeePaid;

  /// No description provided for @confirmTenancy.
  ///
  /// In en, this message translates to:
  /// **'Confirm Tenancy'**
  String get confirmTenancy;

  /// No description provided for @tenantConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I have successfully secured this property.'**
  String get tenantConfirmation;

  /// No description provided for @landlordConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This tenant has moved into my property.'**
  String get landlordConfirmation;

  /// No description provided for @claimProperty.
  ///
  /// In en, this message translates to:
  /// **'Claim Property'**
  String get claimProperty;

  /// No description provided for @propertyAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This property already exists in Dalali.'**
  String get propertyAlreadyExists;

  /// No description provided for @requestOwnershipClaim.
  ///
  /// In en, this message translates to:
  /// **'Request Ownership Claim'**
  String get requestOwnershipClaim;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @cancelListing.
  ///
  /// In en, this message translates to:
  /// **'Cancel Listing'**
  String get cancelListing;

  /// No description provided for @duplicateDetected.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Detected'**
  String get duplicateDetected;

  /// No description provided for @claimSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Claim submitted for review.'**
  String get claimSubmitted;

  /// No description provided for @trustBadgeVerifiedLandlord.
  ///
  /// In en, this message translates to:
  /// **'Verified Landlord'**
  String get trustBadgeVerifiedLandlord;

  /// No description provided for @trustBadgeVerifiedAgent.
  ///
  /// In en, this message translates to:
  /// **'Verified Agent'**
  String get trustBadgeVerifiedAgent;

  /// No description provided for @trustBadgeVerifiedProperty.
  ///
  /// In en, this message translates to:
  /// **'Verified Property'**
  String get trustBadgeVerifiedProperty;

  /// No description provided for @trustBadgeVerifiedCreator.
  ///
  /// In en, this message translates to:
  /// **'Verified Listing Creator'**
  String get trustBadgeVerifiedCreator;

  /// No description provided for @referral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get referral;

  /// No description provided for @campaigns.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get campaigns;

  /// No description provided for @influencerProgram.
  ///
  /// In en, this message translates to:
  /// **'Influencer Program'**
  String get influencerProgram;

  /// No description provided for @influencer.
  ///
  /// In en, this message translates to:
  /// **'Influencer'**
  String get influencer;

  /// No description provided for @applyToEarnCommissions.
  ///
  /// In en, this message translates to:
  /// **'Apply to earn commissions'**
  String get applyToEarnCommissions;

  /// No description provided for @listPropertyEarn.
  ///
  /// In en, this message translates to:
  /// **'List a Property & Earn'**
  String get listPropertyEarn;

  /// No description provided for @listPropertyEarnHint.
  ///
  /// In en, this message translates to:
  /// **'Know a vacant house? List it and earn commission when it\'s rented.'**
  String get listPropertyEarnHint;

  /// No description provided for @influencerDashboard.
  ///
  /// In en, this message translates to:
  /// **'Influencer Dashboard'**
  String get influencerDashboard;

  /// No description provided for @commissionHint.
  ///
  /// In en, this message translates to:
  /// **'Earn 10% of every agency fee paid by your referrals.'**
  String get commissionHint;

  /// No description provided for @totalClicks.
  ///
  /// In en, this message translates to:
  /// **'Total Clicks'**
  String get totalClicks;

  /// No description provided for @registrations.
  ///
  /// In en, this message translates to:
  /// **'Registrations'**
  String get registrations;

  /// No description provided for @conversions.
  ///
  /// In en, this message translates to:
  /// **'Conversions'**
  String get conversions;

  /// No description provided for @totalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get totalEarnings;

  /// No description provided for @availableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get availableBalance;

  /// No description provided for @pendingBalance.
  ///
  /// In en, this message translates to:
  /// **'Pending Balance'**
  String get pendingBalance;

  /// No description provided for @recentConversions.
  ///
  /// In en, this message translates to:
  /// **'Recent Conversions'**
  String get recentConversions;

  /// No description provided for @noConversionsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversions yet. Share your referral link to start earning!'**
  String get noConversionsYet;

  /// No description provided for @notInfluencerYet.
  ///
  /// In en, this message translates to:
  /// **'You are not an influencer yet. Apply to the Influencer Program to start earning commissions.'**
  String get notInfluencerYet;

  /// No description provided for @applyNow.
  ///
  /// In en, this message translates to:
  /// **'Apply Now'**
  String get applyNow;

  /// No description provided for @conversionRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get conversionRegistration;

  /// No description provided for @conversionAgencyFee.
  ///
  /// In en, this message translates to:
  /// **'Agency Fee Payment'**
  String get conversionAgencyFee;

  /// No description provided for @conversionPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium Payment'**
  String get conversionPremium;

  /// No description provided for @conversionDealClosed.
  ///
  /// In en, this message translates to:
  /// **'Deal Closed'**
  String get conversionDealClosed;

  /// No description provided for @yourReferralCode.
  ///
  /// In en, this message translates to:
  /// **'Your Referral Code'**
  String get yourReferralCode;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @referralShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Looking for a house to rent in Tanzania? 🏠 Dalali connects you with verified landlords and agents — browse listings, book a viewing, and move in without the hassle. Sign up with my referral code {code} and get started today: {url}'**
  String referralShareMessage(String code, String url);

  /// No description provided for @shareTo.
  ///
  /// In en, this message translates to:
  /// **'Share to'**
  String get shareTo;

  /// No description provided for @sharePasteHint.
  ///
  /// In en, this message translates to:
  /// **'Message copied — paste it in your {platform} post.'**
  String sharePasteHint(String platform);

  /// No description provided for @campaignLinks.
  ///
  /// In en, this message translates to:
  /// **'Campaign Links'**
  String get campaignLinks;

  /// No description provided for @noLinksYet.
  ///
  /// In en, this message translates to:
  /// **'No referral links yet.'**
  String get noLinksYet;

  /// No description provided for @myCampaigns.
  ///
  /// In en, this message translates to:
  /// **'My Campaigns'**
  String get myCampaigns;

  /// No description provided for @noCampaignsJoined.
  ///
  /// In en, this message translates to:
  /// **'You have not joined any campaigns yet.'**
  String get noCampaignsJoined;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @availableCampaigns.
  ///
  /// In en, this message translates to:
  /// **'Available Campaigns'**
  String get availableCampaigns;

  /// No description provided for @noCampaignsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No campaigns available right now.'**
  String get noCampaignsAvailable;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @joinedCampaign.
  ///
  /// In en, this message translates to:
  /// **'Joined campaign successfully'**
  String get joinedCampaign;

  /// No description provided for @joinCampaignFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not join campaign'**
  String get joinCampaignFailed;

  /// No description provided for @tiktokUrl.
  ///
  /// In en, this message translates to:
  /// **'TikTok URL'**
  String get tiktokUrl;

  /// No description provided for @instagramUrl.
  ///
  /// In en, this message translates to:
  /// **'Instagram URL'**
  String get instagramUrl;

  /// No description provided for @youtubeUrl.
  ///
  /// In en, this message translates to:
  /// **'YouTube URL'**
  String get youtubeUrl;

  /// No description provided for @followersCount.
  ///
  /// In en, this message translates to:
  /// **'Followers Count'**
  String get followersCount;

  /// No description provided for @contentNiche.
  ///
  /// In en, this message translates to:
  /// **'Content Niche'**
  String get contentNiche;

  /// No description provided for @audienceLocation.
  ///
  /// In en, this message translates to:
  /// **'Audience Location'**
  String get audienceLocation;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @applicationUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Application Under Review'**
  String get applicationUnderReview;

  /// No description provided for @applicationUnderReviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Your Influencer Program application is being reviewed. We will notify you soon.'**
  String get applicationUnderReviewMessage;

  /// No description provided for @applicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application Rejected'**
  String get applicationRejected;

  /// No description provided for @applicationApproved.
  ///
  /// In en, this message translates to:
  /// **'Application Approved'**
  String get applicationApproved;

  /// No description provided for @applicationApprovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You are now a Dalali influencer. Start sharing your referral link.'**
  String get applicationApprovedMessage;

  /// No description provided for @goToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to Dashboard'**
  String get goToDashboard;

  /// No description provided for @applicationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application submitted! We will review it shortly.'**
  String get applicationSubmitted;

  /// No description provided for @nicheRealEstate.
  ///
  /// In en, this message translates to:
  /// **'Real Estate'**
  String get nicheRealEstate;

  /// No description provided for @nicheLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get nicheLifestyle;

  /// No description provided for @nicheComedy.
  ///
  /// In en, this message translates to:
  /// **'Comedy'**
  String get nicheComedy;

  /// No description provided for @nicheEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get nicheEducation;

  /// No description provided for @nicheNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get nicheNews;

  /// No description provided for @nicheOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get nicheOther;

  /// No description provided for @nearMeTitle.
  ///
  /// In en, this message translates to:
  /// **'Near Me'**
  String get nearMeTitle;

  /// No description provided for @searchNearbyHint.
  ///
  /// In en, this message translates to:
  /// **'Search nearby homes...'**
  String get searchNearbyHint;

  /// No description provided for @entireCity.
  ///
  /// In en, this message translates to:
  /// **'Entire City'**
  String get entireCity;

  /// No description provided for @distanceAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String distanceAway(String distance);

  /// No description provided for @listingsNearby.
  ///
  /// In en, this message translates to:
  /// **'{count} listings nearby'**
  String listingsNearby(int count);

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @noListingsNearby.
  ///
  /// In en, this message translates to:
  /// **'No listings nearby.'**
  String get noListingsNearby;

  /// No description provided for @expandSearchRadius.
  ///
  /// In en, this message translates to:
  /// **'Expand search radius?'**
  String get expandSearchRadius;

  /// No description provided for @searchWithinRadius.
  ///
  /// In en, this message translates to:
  /// **'Search {radius}'**
  String searchWithinRadius(String radius);

  /// No description provided for @noMatchingFilters.
  ///
  /// In en, this message translates to:
  /// **'No listings match your search.'**
  String get noMatchingFilters;

  /// No description provided for @nearbyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load nearby listings.'**
  String get nearbyLoadError;

  /// No description provided for @retryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLabel;

  /// No description provided for @filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersTitle;

  /// No description provided for @priceRangeTzs.
  ///
  /// In en, this message translates to:
  /// **'Price range (TZS)'**
  String get priceRangeTzs;

  /// No description provided for @anyOption.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get anyOption;

  /// No description provided for @bedroomsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bedrooms'**
  String get bedroomsLabel;

  /// No description provided for @propertyTypeHeader.
  ///
  /// In en, this message translates to:
  /// **'Property Type'**
  String get propertyTypeHeader;

  /// No description provided for @premiumOnly.
  ///
  /// In en, this message translates to:
  /// **'Premium only'**
  String get premiumOnly;

  /// No description provided for @verifiedOnly.
  ///
  /// In en, this message translates to:
  /// **'Verified only'**
  String get verifiedOnly;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyFilters;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetFilters;

  /// No description provided for @newListingNearby.
  ///
  /// In en, this message translates to:
  /// **'A new apartment has been listed {distance} away.'**
  String newListingNearby(String distance);

  /// No description provided for @viewNow.
  ///
  /// In en, this message translates to:
  /// **'View Now'**
  String get viewNow;

  /// No description provided for @locationServicesOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off — showing Dar es Salaam.'**
  String get locationServicesOff;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied — showing Dar es Salaam.'**
  String get locationPermissionDenied;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @enableGps.
  ///
  /// In en, this message translates to:
  /// **'Turn on GPS'**
  String get enableGps;

  /// No description provided for @heatmapLabel.
  ///
  /// In en, this message translates to:
  /// **'Heatmap'**
  String get heatmapLabel;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @photoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload photo. Try again.'**
  String get photoUploadFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

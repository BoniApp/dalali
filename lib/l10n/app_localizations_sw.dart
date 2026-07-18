// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'Dalali';

  @override
  String get welcome => 'Karibu';

  @override
  String get welcomeToDalali => 'Karibu Dalali';

  @override
  String get appSubtitle => 'Jukwaa la kuaminika la mali nchini Tanzania';

  @override
  String get howWouldYouLikeToUse => 'Ungependa kutumia Dalali vipi?';

  @override
  String get welcomeBack => 'Karibu Tena';

  @override
  String get signInToContinue => 'Ingia ili kuendelea';

  @override
  String get signIn => 'Ingia';

  @override
  String get signInWithEmail => 'Ingia kwa Barua pepe';

  @override
  String get signUp => 'Jiandikishe';

  @override
  String get createAccount => 'Unda Akaunti';

  @override
  String get logout => 'Toka';

  @override
  String get email => 'Barua pepe';

  @override
  String get password => 'Nenosiri';

  @override
  String get confirmPassword => 'Thibitisha Nenosiri';

  @override
  String get fullName => 'Jina Kamili';

  @override
  String get phoneNumber => 'Namba ya Simu';

  @override
  String get forgotPassword => 'Umesahau Nenosiri?';

  @override
  String get alreadyHaveAccount => 'Tayari una akaunti?';

  @override
  String get dontHaveAccount => 'Huna akaunti?';

  @override
  String get pleaseEnterEmail => 'Tafadhali ingiza barua pepe yako';

  @override
  String get pleaseEnterValidEmail => 'Tafadhali ingiza barua pepe sahihi';

  @override
  String get pleaseEnterPassword => 'Tafadhali ingiza nenosiri lako';

  @override
  String get passwordMinLength => 'Nenosiri lazima liwe na herufi angalau 6';

  @override
  String get resetPassword => 'Weka upya Nenosiri';

  @override
  String get enterYourEmail => 'Weka barua pepe yako';

  @override
  String get send => 'Tuma';

  @override
  String get passwordResetSent => 'Barua ya kuweka upya nenosiri imetumwa!';

  @override
  String get home => 'Nyumbani';

  @override
  String get saved => 'Imehifadhiwa';

  @override
  String get visits => 'Ziara';

  @override
  String get messages => 'Ujumbe';

  @override
  String get profile => 'Wasifu';

  @override
  String get dashboard => 'Dashibodi';

  @override
  String get addProperty => 'Ongeza Mali';

  @override
  String get inquiries => 'Maswali';

  @override
  String get add => 'Ongeza';

  @override
  String get houseSeeker => 'Mtafuta Nyumba';

  @override
  String get landlord => 'Mwenye Nyumba';

  @override
  String get agent => 'Wakala';

  @override
  String get findYourHome => 'Pata nyumba yako bora';

  @override
  String get listAndManage => 'Orodhesha na simamia mali zako';

  @override
  String get manageClients => 'Simamia wateja na pata tume';

  @override
  String get featuredProperties => 'Mali Maalum';

  @override
  String get allProperties => 'Mali Zote';

  @override
  String get searchResults => 'Matokeo ya Utafutaji';

  @override
  String get searchHint => 'Tafuta kwa eneo au jina...';

  @override
  String get noPropertiesFound => 'Hakuna mali zilizopatikana';

  @override
  String get propertyDetails => 'Maelezo ya Mali';

  @override
  String get amenities => 'Vifaa';

  @override
  String get description => 'Maelezo';

  @override
  String get location => 'Eneo';

  @override
  String get reviews => 'Maoni';

  @override
  String get writeReview => 'Andika Maoni';

  @override
  String get noReviewsYet => 'Hakuna maoni bado';

  @override
  String get scheduleViewing => 'Panga Ziara';

  @override
  String get reportListing => 'Ripoti Tangazo Uongo';

  @override
  String get neighbourhoodSafety => 'Usalama wa Mtaa';

  @override
  String get reportIncident => 'Ripoti Tukio';

  @override
  String get safetyScore => 'Alama ya Usalama';

  @override
  String get activeIncidents => 'matukio ya usalama karibu';

  @override
  String get startYourMove => 'Anza Uhamisho Wako';

  @override
  String get movingSoon => 'Una uhamisho hivi karibuni?';

  @override
  String get listYourHome => 'Orodhesha nyumba yako sasa & pata nyingine.';

  @override
  String get myMove => 'Uhamisho Wangu';

  @override
  String get moveStatus => 'Hali ya Uhamisho';

  @override
  String get moveDetails => 'Maelezo ya Uhamisho';

  @override
  String get activate => 'Wezesha';

  @override
  String get complete => 'Kamilisha';

  @override
  String get cancelMove => 'Ghairi Uhamisho';

  @override
  String get settings => 'Mipangilio';

  @override
  String get appearance => 'Muonekano';

  @override
  String get language => 'Lugha';

  @override
  String get themeSystem => 'Mfumo wa Mwonekano';

  @override
  String get themeLight => 'Mwonekano Mwanga';

  @override
  String get themeDark => 'Mwonekano Mweusi';

  @override
  String get english => 'Kiingereza';

  @override
  String get kiswahili => 'Kiswahili';

  @override
  String get preferencesSaved => 'Mipangilio imehifadhiwa';

  @override
  String get furnished => 'Vyumba vimejengwa';

  @override
  String get water => 'Maji';

  @override
  String get parking => 'Maegesho';

  @override
  String get security => 'Usalama';

  @override
  String bedrooms(int count) {
    return 'Vyumba vya Kulala $count';
  }

  @override
  String bathrooms(int count) {
    return 'Bafu $count';
  }

  @override
  String pricePerMonth(String price) {
    return '$price / mwezi';
  }

  @override
  String get cancel => 'Ghairi';

  @override
  String get save => 'Hifadhi';

  @override
  String get submit => 'Wasiliana';

  @override
  String get delete => 'Futa';

  @override
  String get edit => 'Hariri';

  @override
  String get close => 'Funga';

  @override
  String get confirm => 'Thibitisha';

  @override
  String get rewardPoints => 'Alama za Zawadi';

  @override
  String pointsEarned(int points) {
    return 'Alama $points zilizopatikana';
  }

  @override
  String get pending => 'inasubiri';

  @override
  String pendingCount(int count) {
    return '$count zinasubiri';
  }

  @override
  String get notLoggedIn => 'Hujajaingia';

  @override
  String get verifiedAccount => 'Akaunti Iliyothibitishwa';

  @override
  String get verificationPending => 'Inasubiri Uthibitisho';

  @override
  String get unverifiedAccount => 'Akaunti Isiyothibitishwa';

  @override
  String get settingsSubtitle => 'Mandhari, lugha na zaidi';

  @override
  String get phone => 'Simu';

  @override
  String get role => 'Jukumu';

  @override
  String get nationalId => 'Kitambulisho cha Taifa';

  @override
  String get agentLicense => 'Leseni ya Wakala';

  @override
  String get planning => 'Kupanga';

  @override
  String get active => 'Inaendelea';

  @override
  String get verifyMyAccount => 'Thibitisha Akaunti Yangu';

  @override
  String get accountVerification => 'Uthibitisho wa Akaunti';

  @override
  String get verifyAccountDescription =>
      'Ili kuthibitisha akaunti yako, unahitaji kutoa:';

  @override
  String get nidaRequired => 'Kitambulisho cha Taifa (NIDA)';

  @override
  String get phoneVerificationRequired => 'Uthibitisho wa namba ya simu';

  @override
  String get verifiedUsersBenefit =>
      'Watumiaji walioithibitisha wanapata nembo na kuaminika zaidi na wateja.';

  @override
  String get later => 'Baadaye';

  @override
  String get startVerification => 'Anza Uthibitisho';

  @override
  String get verificationSubmitted => 'Ombi la uthibitisho limewasilishwa!';

  @override
  String get opportunities => 'Fursa';

  @override
  String get earnings => 'Mapato';

  @override
  String get totalEarned => 'Jumla ya Mapato';

  @override
  String get pendingEarnings => 'Mapato Yanayosubiri';

  @override
  String get withdrawableBalance => 'Salio la Kutoa';

  @override
  String get successfulListings => 'Orodha Zilizofanikiwa';

  @override
  String get agencyFeeHistory => 'Historia ya Ada ya Wakala';

  @override
  String get noEarningsYet =>
      'Hakuna mapato bado. Orodhesha mali kuanza kupata!';

  @override
  String get opportunityFeed => 'Lishe ya Fursa';

  @override
  String get highDemandAreas => 'Maeneo ya Mahitaji Makubwa';

  @override
  String get recentlyListed => 'Zilizoingia Hivi Karibuni';

  @override
  String get fastMoving => 'Zinazosonga Haraka';

  @override
  String get nearbyVacancies => 'Nafasi za Karibu';

  @override
  String get dealTracking => 'Ufuatiliaji wa Makubaliano';

  @override
  String get dealStatus => 'Hali ya Makubaliano';

  @override
  String get viewingScheduled => 'Ziara Imepangwa';

  @override
  String get viewingCompleted => 'Ziara Imekamilika';

  @override
  String get negotiating => 'Inajadiliwa';

  @override
  String get tenancyConfirmed => 'Kukodishwa Kimethibitishwa';

  @override
  String get agencyFeePending => 'Ada ya Wakala Inasubiri';

  @override
  String get agencyFeePaid => 'Ada ya Wakala Imelipwa';

  @override
  String get confirmTenancy => 'Thibitisha Kukodishwa';

  @override
  String get tenantConfirmation => 'Nimepata mali hii kwa mafanikio.';

  @override
  String get landlordConfirmation => 'Mpangaji huyu amehama kwenye mali yangu.';

  @override
  String get claimProperty => 'Dai Mali';

  @override
  String get propertyAlreadyExists => 'Mali hii tayari ipo Dalali.';

  @override
  String get requestOwnershipClaim => 'Omba Dai la Umiliki';

  @override
  String get contactSupport => 'Wasiliana na Msaada';

  @override
  String get cancelListing => 'Ghairi Orodha';

  @override
  String get duplicateDetected => 'Nakala Imegundulika';

  @override
  String get claimSubmitted => 'Dai limewasilishwa kwa ukaguzi.';

  @override
  String get trustBadgeVerifiedLandlord => 'Mwenye Nyumba Aliyethibitishwa';

  @override
  String get trustBadgeVerifiedAgent => 'Wakala Aliyethibitishwa';

  @override
  String get trustBadgeVerifiedProperty => 'Mali Iliyothibitishwa';

  @override
  String get trustBadgeVerifiedCreator => 'Muumba wa Orodha Aliyethibitishwa';
}

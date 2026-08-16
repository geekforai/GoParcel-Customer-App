import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';

const localePrefsKey = 'gp_customer_locale';

class AppLocaleNotifier extends Notifier<String> {
  @override
  String build() {
    return ref.read(sharedPreferencesProvider).getString(localePrefsKey) ?? 'en';
  }

  Future<void> setLocale(String code) async {
    state = code == 'hi' ? 'hi' : 'en';
    await ref.read(sharedPreferencesProvider).setString(localePrefsKey, state);
  }

  bool get isHindi => state == 'hi';
}

final appLocaleProvider =
    NotifierProvider<AppLocaleNotifier, String>(AppLocaleNotifier.new);

final l10nProvider = Provider<L10n>((ref) {
  return L10n(ref.watch(appLocaleProvider) == 'hi');
});

String tr(WidgetRef ref, String en, String hi) {
  return ref.watch(appLocaleProvider) == 'hi' ? hi : en;
}

class L10n {
  const L10n(this.hi);
  final bool hi;

  String t(String en, String hindi) => hi ? hindi : en;

  String get language => t('Language', 'भाषा');
  String get settings => t('Settings', 'सेटिंग्स');
  String get home => t('Home', 'होम');
  String get orders => t('Orders', 'ऑर्डर');
  String get alerts => t('Alerts', 'अलर्ट');
  String get profile => t('Profile', 'प्रोफ़ाइल');
  String get welcome => t('Welcome to GoParcel', 'गोपरसल में स्वागत है');
  String get loginSubtitle =>
      t('Jaipur deliveries — login with your mobile number.',
          'जयपुर डिलीवरी — मोबाइल नंबर से लॉगिन करें।');
  String get continueLabel => t('Continue', 'जारी रखें');
  String get referralOptional =>
      t('Referral code (optional)', 'रेफरल कोड (वैकल्पिक)');
  String get termsPrefix => t('By continuing, you agree to our ', 'जारी रखकर आप हमारी ');
  String get terms => t('Terms & Conditions', 'नियम और शर्तें');
  String get andWord => t(' and ', ' और ');
  String get privacy => t('Privacy Policy', 'गोपनीयता नीति');
  String get bookParcel => t('Book a parcel', 'पार्सल बुक करें');
  String get sameCity => t('Same-city delivery in minutes', 'शहर के अंदर कुछ मिनटों में डिलीवरी');
  String get savedAddresses => t('Saved addresses', 'सेव पते');
  String get recentOrders => t('Recent orders', 'हाल के ऑर्डर');
  String get continueTrip => t('Continue active trip', 'चालू ट्रिप जारी रखें');
  String get wallet => t('Wallet', 'वॉलेट');
  String get payments => t('Payment Methods', 'पेमेंट तरीके');
  String get support => t('Support', 'सहायता');
  String get about => t('About', 'ऐप के बारे में');
  String get logout => t('Logout', 'लॉग आउट');
  String get faqs => t('FAQs', 'सवाल-जवाब');
  String get refund => t('Refund Policy', 'रिफंड नीति');
  String get help => t('Help / Contact', 'मदद / संपर्क');
  String get english => 'English';
  String get hindiLabel => 'हिन्दी';
  String get chooseLanguage => t('Choose language', 'भाषा चुनें');
  String get goodMorning => t('Good Morning', 'सुप्रभात');
  String get goodAfternoon => t('Good Afternoon', 'शुभ दोपहर');
  String get goodEvening => t('Good Evening', 'शुभ संध्या');
  String get parcelDetails => t('Parcel details', 'पार्सल विवरण');
  String get vehicle => t('Vehicle', 'वाहन');
  String get electric => t('Electric', 'इलेक्ट्रिक');
  String get fuel => t('Diesel / Petrol', 'डीजल / पेट्रोल');
  String get sending => t('What are you sending?', 'आप क्या भेज रहे हैं?');
  String get documents => t('Documents', 'दस्तावेज़');
  String get electronics => t('Electronics', 'इलेक्ट्रॉनिक्स');
  String get clothes => t('Clothes', 'कपड़े');
  String get food => t('Food', 'खाना');
  String get others => t('Others', 'अन्य');
  String get addPhoto => t('Add parcel photo', 'पार्सल फ़ोटो जोड़ें');
  String get photoAdded => t('Photo added', 'फ़ोटो जुड़ गई');
  String get noTip => t('No tip', 'टिप नहीं');
  String get instructionsHint =>
      t('Handle with care, call on arrival…', 'सावधानी से संभालें, पहुँचने पर कॉल करें…');
  String get evBenefit =>
      t('Lower fare · lower emissions', 'कम किराया · कम उत्सर्जन');
  String get bookNow => t('Book now', 'अभी बुक करें');
  String get estimatedFare => t('Estimated fare', 'अनुमानित किराया');
  String get tipOptional => t('Tip (optional)', 'टिप (वैकल्पिक)');
  String get whereTo => t('Where to?', 'कहाँ भेजना है?');
  String get searchDrop => t('Search drop location', 'ड्रॉप लोकेशन खोजें');
  String get searchPickup => t('Search pickup location', 'पिकअप लोकेशन खोजें');
  String get currentLocation => t('Current location', 'वर्तमान लोकेशन');
  String get recentSearches => t('Recent searches', 'हाल की खोज');
  String get savedPlaces => t('Saved', 'सेव्ड');
  String get pickup => t('Pickup', 'पिकअप');
  String get drop => t('Drop', 'ड्रॉप');
  String get useMyNumber => t('Use my number', 'मेरा नंबर इस्तेमाल करें');
  String get receiverName => t('Receiver name', 'रिसीवर का नाम');
  String get phone => t('Phone', 'फ़ोन');
  String get findingDriver => t('Finding driver', 'ड्राइवर ढूँढ रहे हैं');
  String get matching => t('Matching nearby drivers', 'पास के ड्राइवर मैच हो रहे हैं');
  String get cancelBooking => t('Cancel booking', 'बुकिंग रद्द करें');
  String get rateDriver => t('Please rate your driver', 'कृपया ड्राइवर को रेट करें');
  String get delivered => t('Delivered!', 'डिलीवर हो गया!');
  String get bookAnother => t('Book another', 'और बुक करें');
  String get gstin => t('GSTIN (optional)', 'GSTIN (वैकल्पिक)');
  String get co2 => t('CO₂ saved from EV trips', 'EV ट्रिप से बचा CO₂');
  String get verifyOtp => t('Verify OTP', 'OTP वेरिफाई करें');
  String get enterOtp => t('Enter OTP', 'OTP दर्ज करें');
  String get otpHint =>
      t('SMS is not enabled yet. Use OTP 1234', 'SMS अभी चालू नहीं है। OTP 1234 इस्तेमाल करें');
  String get verifyContinue => t('Verify & Continue', 'वेरिफाई करके आगे बढ़ें');
  String get all => t('All', 'सभी');
  String get completed => t('Completed', 'पूरे');
  String get ongoing => t('Ongoing', 'चालू');
  String get cancelled => t('Cancelled', 'रद्द');
  String get noOrders => t('No orders yet', 'अभी कोई ऑर्डर नहीं');
  String get noOrdersSub =>
      t('Your deliveries will show up here', 'आपकी डिलीवरी यहाँ दिखेंगी');
  String get trackLive => t('Track', 'ट्रैक');
  String get viewDetails => t('Details', 'विवरण');
  String get orderDetails => t('Order details', 'ऑर्डर विवरण');
  String get tripRoute => t('Route', 'रूट');
  String get shipment => t('Shipment', 'शिपमेंट');
  String get partner => t('Delivery partner', 'डिलीवरी पार्टनर');
  String get pickupOtp => t('Pickup OTP', 'पिकअप OTP');
  String get deliveryOtp => t('Delivery OTP', 'डिलीवरी OTP');
  String get timeline => t('Updates', 'अपडेट');
  String get noTimeline => t('Updates will appear once the trip starts', 'ट्रिप शुरू होने पर अपडेट दिखेंगे');
  String get keepOrder => t('Keep order', 'ऑर्डर रखें');
  String get cancelOrder => t('Cancel order', 'ऑर्डर रद्द करें');
  String get cancelUntilPickup =>
      t('You can cancel until pickup.', 'पिकअप तक ऑर्डर रद्द कर सकते हैं।');
  String get farePaid => t('Amount', 'राशि');
  String get bookedOn => t('Booked', 'बुक किया');
  String get weight => t('Weight', 'वज़न');
  String get instructions => t('Note', 'नोट');
  String get shareOtpHint =>
      t('Share only with the assigned partner', 'केवल असाइन पार्टनर को बताएँ');

  String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return goodMorning;
    if (h < 17) return goodAfternoon;
    return goodEvening;
  }
}

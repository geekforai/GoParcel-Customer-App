/// Customer FAQs and booking rules (official GoParcel content).
abstract final class GoParcelContent {
  static const waitingPolicy =
      '50 minutes of loading/unloading time is included. After that, ₹3 per minute waiting charges will apply.';

  static const readBeforeBooking = <String>[
    'Please provide accurate parcel weight, size and quantity.',
    'Keep your parcel ready before the driver arrives.',
    '50 minutes of loading/unloading time is included.',
    'After 50 minutes, ₹3/minute waiting charges will apply.',
    'Fare may be revised if the pickup/drop location is changed.',
    'Loading/unloading labour arrangements and charges are the customer\'s responsibility.',
    'Overloading is strictly not allowed.',
    'Illegal, hazardous, restricted or prohibited items cannot be transported.',
  ];

  static const customerFaqs = <(String, String)>[
    (
      'What is Go Parcel?',
      'Go Parcel helps you book a vehicle to transport parcels and goods from one location to another.',
    ),
    (
      'How can I book a vehicle?',
      'Enter your pickup and drop location, select the required vehicle, check the fare and confirm your booking.',
    ),
    (
      'Which vehicles are available?',
      'Available vehicle options may include 2-Wheeler, 3-Wheeler, Mini 3-Wheeler, Tata Ace and Pickup 8ft, depending on your city.',
    ),
    (
      'How is the fare calculated?',
      'Your fare is based on the selected vehicle, travel distance and applicable charges. The estimated fare is shown before you confirm the booking.',
    ),
    (
      'Can I see the fare before booking?',
      'Yes. The estimated fare will be displayed before you confirm your booking.',
    ),
    (
      'How much loading/unloading time is included?',
      '50 minutes of loading/unloading time is included. After that, ₹3 per minute waiting charges will apply.',
    ),
    (
      'Can I cancel my booking?',
      'Yes, you can cancel your booking from the app. Applicable cancellation charges, if any, will be displayed according to the cancellation policy.',
    ),
    (
      'How can I pay for my booking?',
      'You can use the payment options available in the Go Parcel app, such as Cash or Online Payment.',
    ),
    (
      'Can I track my booking?',
      'Yes, you can view the booking status and assigned driver details from the app.',
    ),
    (
      'Can I change my pickup or drop location?',
      'You can request a location change. If the updated route changes the trip cost, the fare may be recalculated.',
    ),
    (
      'What items can I send?',
      'You can send permitted parcels and goods that are suitable for transportation through the selected vehicle.',
    ),
    (
      'Which items are not allowed?',
      'Illegal, hazardous, restricted or prohibited items are not accepted for transportation.',
    ),
    (
      'What if I have a problem with my booking?',
      'You can contact Go Parcel through the Help & Support section in the app.',
    ),
    (
      'Can I use Go Parcel for business deliveries?',
      'Yes. Go Parcel can be used for regular shop, business and local delivery requirements.',
    ),
    (
      'Can I book a vehicle for another person?',
      'Yes, you can provide the receiver\'s name and mobile number while making the booking.',
    ),
  ];
}

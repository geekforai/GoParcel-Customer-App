# GoParcel Customer App

Flutter customer app for hyperlocal parcel booking (GoParcel).

## Features

- Phone / WhatsApp login with OTP
- Location permission onboarding
- Book parcel flow: locations → parcel details → driver search → live tracking
- Orders, notifications, profile (wallet, addresses, settings)

## Run

```bash
cd customer_app
flutter pub get
flutter run
```

## Stack

- flutter_riverpod, go_router, shared_preferences, image_picker
- Mock repositories for local demo (OTP `0000` fails; any other 4-digit OTP works)

## Analyze

```bash
dart analyze lib
```

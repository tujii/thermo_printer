# thermo_printer

Flutter demo for connecting to a Bluetooth thermal printer (ESC/POS) and sending a print command.

## Features
- List paired Bluetooth printers
- Connect and disconnect
- Print a test ticket with custom text

## Prerequisites
- Flutter SDK installed
- Android device with Bluetooth
- Thermal printer paired in Android Bluetooth settings

## Run (Android)
1. Connect your phone and ensure Bluetooth is enabled.
2. Run `flutter pub get`.
3. Run `flutter run`.
4. In the app, select a paired printer, connect, and tap "Print test ticket".

cd /Users/tujiiprince/develop/thermo_printer/packages/blue_thermal_printer/example 
flutter run -d adb-48221FDKD001ZS-j6RdTw._adb-tls-connect._tcp

## Notes
- This sample uses the `blue_thermal_printer` plugin and expects a paired device.
- Android 12+ requires Bluetooth permissions at runtime; ensure they are granted.
- The print command is ESC/POS compatible. Adjust formatting in `lib/main.dart` as needed.

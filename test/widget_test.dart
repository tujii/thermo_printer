// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:thermo_printer/main.dart';

void main() {
  testWidgets('App loads printer screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ThermoPrinterApp());

    expect(find.text('Thermal Printer Demo'), findsOneWidget);
    expect(find.text('Print test ticket'), findsOneWidget);
  });
}

import '../lib/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Verify Platform version', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());
  });
}

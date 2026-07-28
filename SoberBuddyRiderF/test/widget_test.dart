import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sober_buddy_rider/app.dart';

void main() {
  testWidgets('App smoke test placeholder', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SoberBuddyApp(),
      ),
    );
    expect(find.byType(SoberBuddyApp), findsOneWidget);
  });
}

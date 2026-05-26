import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/app/app.dart';

void main() {
  testWidgets('renders app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RobyneApp()));

    expect(find.text('Robyne'), findsOneWidget);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Plugins'), findsOneWidget);
  });
}

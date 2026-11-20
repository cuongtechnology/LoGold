import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lo/screens/utilities_screen.dart';
import 'package:lo/stores/app_store.dart';
import 'package:provider/provider.dart';

Widget _app(int tab) => ChangeNotifierProvider(
      create: (_) => AppStore(),
      child: MaterialApp(home: UtilitiesScreen(initialTab: tab)),
    );

void main() {
  testWidgets('opens directly on the requested tab', (tester) async {
    await tester.pumpWidget(_app(UtilityTab.spread));
    await tester.pumpAndSettle();
    expect(find.text('Chênh lệch mua - bán'), findsOneWidget);
  });

  testWidgets('target profit: 5 chỉ, 60tr vốn, lãi 10% -> 132tr/lượng',
      (tester) async {
    await tester.pumpWidget(_app(UtilityTab.targetProfit));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '60.000.000');
    await tester.enterText(fields.at(1), '5');
    await tester.pumpAndSettle();

    expect(find.textContaining('132.000.000'), findsOneWidget);
    expect(find.text('6.000.000đ'), findsOneWidget); // tiền lãi
  });

  testWidgets('budget: 50tr at 12tr/chỉ buys 4.17 chỉ', (tester) async {
    await tester.pumpWidget(_app(UtilityTab.budget));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '50000000');
    await tester.enterText(fields.at(1), '12.000.000');
    await tester.pumpAndSettle();

    expect(find.text('4.17 chỉ'), findsOneWidget);
    expect(find.text('4 chỉ'), findsOneWidget);
    expect(find.text('2.000.000đ'), findsOneWidget); // tiền thừa
  });

  testWidgets('average cost of two lots', (tester) async {
    await tester.pumpWidget(_app(UtilityTab.averageCost));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '2');
    await tester.enterText(fields.at(1), '10.000.000');
    await tester.enterText(fields.at(2), '3');
    await tester.enterText(fields.at(3), '12.000.000');
    await tester.pumpAndSettle();

    // (2×10tr + 3×12tr) / 5 = 11.2tr/chỉ
    expect(find.text('11.200.000đ/chỉ'), findsOneWidget);

    // Removing a lot must not throw (controllers are disposed after the frame).
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('12.000.000đ/chỉ'), findsOneWidget);
  });
}

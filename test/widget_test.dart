import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalali/models/user_model.dart';
import 'package:dalali/widgets/verification_badge.dart';

void main() {
  testWidgets('VerificationBadge shows verified icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VerificationBadge(status: VerificationStatus.verified),
      ),
    );
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('VerificationBadge shows pending icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VerificationBadge(status: VerificationStatus.pending),
      ),
    );
    expect(find.byIcon(Icons.pending), findsOneWidget);
  });

  testWidgets('VerificationBadge shows unverified icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VerificationBadge(status: VerificationStatus.unverified),
      ),
    );
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });
}

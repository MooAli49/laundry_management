import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/constants/app_constants.dart';
import 'package:laundry_management/laundry_management.dart';

void main() {
  testWidgets('Foundation App Bootstrap Test', (WidgetTester tester) async {
    await tester.pumpWidget(const LaundryManagementApp());
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('الرئيسية'), findsAtLeast(1));
  });
}

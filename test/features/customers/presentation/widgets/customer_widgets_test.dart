import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/domain/entities/customer.dart';
import 'package:laundry_management/features/customers/presentation/models/customer_list_item_view_model.dart';
import 'package:laundry_management/features/customers/presentation/widgets/customer_card.dart';
import 'package:laundry_management/features/customers/presentation/widgets/customer_form_dialog.dart';

Widget testBoilerplate(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Customer Widgets Tests', () {
    testWidgets('CustomerCard renders customer info, order count and handles tap', (tester) async {
      bool tapped = false;
      final now = DateTime.now();
      final customer = Customer(
        id: 'c-1',
        name: 'كريم محمود',
        phone: '01012345678',
        createdAt: now,
        updatedAt: now,
      );

      final item = CustomerListItemViewModel(customer: customer, orderCount: 3);

      await tester.pumpWidget(testBoilerplate(
        CustomerCard(
          item: item,
          onTap: () => tapped = true,
        ),
      ));

      expect(find.text('كريم محمود'), findsOneWidget);
      expect(find.text('01012345678'), findsOneWidget);
      expect(find.text('3 طلبات'), findsOneWidget);

      await tester.tap(find.byType(CustomerCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('CustomerFormDialog renders add form and validates required fields', (tester) async {
      String? savedName;
      String? savedPhone;

      await tester.pumpWidget(testBoilerplate(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => CustomerFormDialog(
                  onSave: ({required name, required phone, notes}) async {
                    savedName = name;
                    savedPhone = phone;
                  },
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('إضافة عميل جديد'), findsOneWidget);

      // Attempt to submit empty form
      await tester.tap(find.text('حفظ العميل'));
      await tester.pump();
      expect(find.text('اسم العميل مطلوب'), findsOneWidget);

      // Enter name only
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'محمد سالم');
      await tester.tap(find.text('حفظ العميل'));
      await tester.pump();
      expect(find.text('رقم الهاتف مطلوب'), findsOneWidget);

      // Enter invalid phone
      await tester.enterText(textFields.at(1), '01398765432');
      await tester.tap(find.text('حفظ العميل'));
      await tester.pump();
      expect(find.text('رقم الهاتف غير صحيح'), findsOneWidget);

      // Enter valid Egyptian phone
      await tester.enterText(textFields.at(1), '01098765432');
      await tester.tap(find.text('حفظ العميل'));
      await tester.pumpAndSettle();

      expect(savedName, equals('محمد سالم'));
      expect(savedPhone, equals('01098765432'));
      // Dialog should have closed
      expect(find.text('إضافة عميل جديد'), findsNothing);
    });

    testWidgets('CustomerFormDialog pre-populates fields when editing', (tester) async {
      final now = DateTime.now();
      final customer = Customer(
        id: 'c-edit',
        name: 'عميل سابق',
        phone: '01011112222',
        notes: 'ملاحظة سابقة',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(testBoilerplate(
        CustomerFormDialog(
          customer: customer,
          onSave: ({required name, required phone, notes}) async {},
        ),
      ));

      expect(find.text('تعديل بيانات العميل'), findsOneWidget);
      expect(find.text('عميل سابق'), findsOneWidget);
      expect(find.text('01011112222'), findsOneWidget);
      expect(find.text('ملاحظة سابقة'), findsOneWidget);
      expect(find.text('حفظ التعديلات'), findsOneWidget);
    });
  });
}

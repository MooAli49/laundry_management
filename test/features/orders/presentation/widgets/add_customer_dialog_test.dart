import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/features/orders/presentation/widgets/add_customer_dialog.dart';

Future<void> _pump(
  WidgetTester tester,
  String? query, {
  Future<void> Function({
    required String name,
    required String phone,
    String? address,
    String? notes,
  })?
  onSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: AddCustomerDialog(
            initialQuery: query,
            onSave:
                onSave ??
                ({required name, required phone, address, notes}) async {},
          ),
        ),
      ),
    ),
  );
}

String _name(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .elementAt(0)
    .controller!
    .text;

String _phone(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .elementAt(1)
    .controller!
    .text;

void main() {
  group('AddCustomerDialog initial query', () {
    testWidgets('ASCII phone goes to phone', (tester) async {
      await _pump(tester, '01012345678');
      expect(_name(tester), '');
      expect(_phone(tester), '01012345678');
    });

    testWidgets('Arabic-Indic phone is normalized into phone', (tester) async {
      await _pump(tester, '٠١٠١٢٣٤٥٦٧٨');
      expect(_name(tester), '');
      expect(_phone(tester), '01012345678');
    });

    testWidgets('Arabic name goes to name', (tester) async {
      await _pump(tester, 'محمد أحمد');
      expect(_name(tester), 'محمد أحمد');
      expect(_phone(tester), '');
    });

    testWidgets('mixed query remains a name', (tester) async {
      await _pump(tester, 'محمد ٠١٠');
      expect(_name(tester), 'محمد ٠١٠');
      expect(_phone(tester), '');
    });

    testWidgets('saving Arabic-Indic phone persists normalized ASCII', (
      tester,
    ) async {
      String? savedName;
      String? savedPhone;
      await _pump(
        tester,
        '٠١٠١٢٣٤٥٦٧٨',
        onSave: ({required name, required phone, address, notes}) async {
          savedName = name;
          savedPhone = phone;
        },
      );
      await tester.enterText(
        find.byType(TextField).first,
        'محمد أحمد',
      );
      await tester.tap(find.text('حفظ العميل'));
      await tester.pump();

      expect(savedName, 'محمد أحمد');
      expect(savedPhone, '01012345678');
    });

    testWidgets('typed Arabic-Indic phone is normalized on save', (
      tester,
    ) async {
      String? savedPhone;
      await _pump(
        tester,
        null,
        onSave: ({required name, required phone, address, notes}) async {
          savedPhone = phone;
        },
      );
      await tester.enterText(find.byType(TextField).at(0), 'محمد');
      await tester.enterText(find.byType(TextField).at(1), '٠١٠١٢٣٤٥٦٧٨');
      await tester.tap(find.text('حفظ العميل'));
      await tester.pump();

      expect(savedPhone, '01012345678');
    });
  });
}

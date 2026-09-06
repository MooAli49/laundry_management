import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/theme/app_theme.dart';
import 'package:laundry_management/core/widgets/app_button.dart';
import 'package:laundry_management/core/widgets/app_card.dart';
import 'package:laundry_management/core/widgets/app_error_state.dart';
import 'package:laundry_management/core/widgets/app_text_field.dart';
import 'package:laundry_management/core/widgets/empty_state.dart';
import 'package:laundry_management/core/widgets/loading_indicator.dart';
import 'package:laundry_management/core/widgets/page_header.dart';

void main() {
  group('Foundation UI Widgets Tests', () {
    testWidgets(
      'AppButton renders label, handles taps, and supports loading state',
      (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppButton(
                label: 'حفظ الطلب',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        );

        expect(find.text('حفظ الطلب'), findsOneWidget);
        await tester.tap(find.byType(AppButton));
        expect(tapped, isTrue);

        // Verify loading state renders spinner and disables callback
        tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppButton(
                label: 'حفظ الطلب',
                isLoading: true,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byType(AppButton));
        expect(tapped, isFalse);
      },
    );

    testWidgets('AppTextField renders label, hint, and handles text input', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              controller: controller,
              label: 'اسم العميل',
              hintText: 'أدخل الاسم هنا',
            ),
          ),
        ),
      );

      expect(find.text('اسم العميل'), findsOneWidget);
      expect(find.text('أدخل الاسم هنا'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'محمد علي');
      expect(controller.text, equals('محمد علي'));
    });

    testWidgets('AppCard renders child and handles taps', (
      WidgetTester tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              onTap: () => tapped = true,
              child: const Text('بطاقة اختبار'),
            ),
          ),
        ),
      );

      expect(find.text('بطاقة اختبار'), findsOneWidget);
      await tester.tap(find.text('بطاقة اختبار'));
      expect(tapped, isTrue);
    });

    testWidgets('EmptyState renders title, message, and action button', (
      WidgetTester tester,
    ) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              title: 'لا توجد طلبات',
              message: 'لم يتم العثور على أي طلبات مسجلة',
              actionButton: ElevatedButton(
                onPressed: () => actionTapped = true,
                child: const Text('إضافة طلب'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('لا توجد طلبات'), findsOneWidget);
      expect(find.text('لم يتم العثور على أي طلبات مسجلة'), findsOneWidget);
      expect(find.text('إضافة طلب'), findsOneWidget);

      await tester.tap(find.text('إضافة طلب'));
      expect(actionTapped, isTrue);
    });

    testWidgets('LoadingIndicator renders spinner and optional message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingIndicator(message: 'جاري تحميل البيانات...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('جاري تحميل البيانات...'), findsOneWidget);
    });

    testWidgets('AppButton renders destructive, text, outline variants and honors null onPressed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                AppButton(
                  label: 'حذف',
                  variant: AppButtonVariant.destructive,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'إلغاء',
                  variant: AppButtonVariant.text,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'مخطط',
                  variant: AppButtonVariant.outline,
                  onPressed: () {},
                ),
                const AppButton(
                  label: 'معطل',
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('حذف'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('مخطط'), findsOneWidget);
      expect(find.text('معطل'), findsOneWidget);

      final buttons = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton)).toList();
      // The 4th button has null onPressed
      expect(buttons[3].onPressed, isNull);
    });

    testWidgets('AppTextField renders disabled state and error message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                AppTextField(
                  label: 'حقل معطل',
                  enabled: false,
                  hintText: 'غير متاح',
                ),
                AppTextField(
                  label: 'حقل بخطأ',
                  errorText: 'القيمة غير صالحة',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('حقل معطل'), findsOneWidget);
      expect(find.text('غير متاح'), findsOneWidget);
      expect(find.text('حقل بخطأ'), findsOneWidget);
      expect(find.text('القيمة غير صالحة'), findsOneWidget);
    });

    testWidgets('PageHeader renders title, subtitle, and action widgets in RTL', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PageHeader(
                title: 'شاشة تجريبية',
                subtitle: 'وصف إضافي للشاشة',
                actions: [
                  ElevatedButton(onPressed: null, child: Text('إجراء')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('شاشة تجريبية'), findsOneWidget);
      expect(find.text('وصف إضافي للشاشة'), findsOneWidget);
      expect(find.text('إجراء'), findsOneWidget);
    });

    testWidgets('AppErrorState renders error icon, title, message, and handles retry', (
      WidgetTester tester,
    ) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppErrorState(
              title: 'خطأ في الاتصال',
              message: 'تعذر الوصول إلى الخادم',
              onRetry: () => retried = true,
              retryLabel: 'إعادة المحاولة',
            ),
          ),
        ),
      );

      expect(find.text('خطأ في الاتصال'), findsOneWidget);
      expect(find.text('تعذر الوصول إلى الخادم'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, isTrue);
    });
  });
}

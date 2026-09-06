import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/theme/app_colors.dart';
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

      // destructive: error presentation background and onError foreground
      expect(buttons[0].style?.backgroundColor?.resolve({}), equals(AppColors.error));
      expect(buttons[0].style?.foregroundColor?.resolve({}), equals(AppColors.onError));

      // text: low-emphasis, transparent background and no outline border
      expect(buttons[1].style?.backgroundColor?.resolve({}), equals(Colors.transparent));
      expect(buttons[1].style?.side?.resolve({}), isNull);

      // outline: backward-compatible outline border with primary color and transparent background
      expect(buttons[2].style?.backgroundColor?.resolve({}), equals(Colors.transparent));
      expect(buttons[2].style?.side?.resolve({})?.color, equals(AppColors.primary));

      // The 4th button has null onPressed
      expect(buttons[3].onPressed, isNull);
    });

    testWidgets('AppButton loading state prevents interaction and duplicate submissions', (
      WidgetTester tester,
    ) async {
      int pressCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppButton(
              label: 'إرسال',
              isLoading: true,
              onPressed: () => pressCount++,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(elevatedButton.onPressed, isNull);

      // Taps during loading must be ignored
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      await tester.pump();

      expect(pressCount, equals(0));
    });

    testWidgets('AppTextField covers enabled, focused, error, and disabled states', (
      WidgetTester tester,
    ) async {
      final enabledController = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                AppTextField(
                  controller: enabledController,
                  label: 'حقل نشط',
                  hintText: 'أدخل نص',
                ),
                AppTextField(
                  focusNode: focusNode,
                  label: 'حقل مركز',
                  hintText: 'تركيز',
                ),
                const AppTextField(
                  label: 'حقل بخطأ',
                  errorText: 'القيمة غير صالحة',
                ),
                const AppTextField(
                  label: 'حقل معطل',
                  enabled: false,
                  hintText: 'غير متاح',
                ),
              ],
            ),
          ),
        ),
      );

      // 1. Enabled/default state accepts text
      await tester.enterText(find.widgetWithText(TextFormField, 'أدخل نص'), 'قيمة جديدة');
      expect(enabledController.text, equals('قيمة جديدة'));

      // 2. Focused state: request focus and verify focus state
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // 3. Error state displays error message
      expect(find.text('القيمة غير صالحة'), findsOneWidget);

      // 4. Disabled state uses disabled presentation
      expect(find.text('حقل معطل'), findsOneWidget);
      expect(find.text('غير متاح'), findsOneWidget);
      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      final disabledField = textFields.last;
      expect(disabledField.enabled, isFalse);
      expect(disabledField.decoration?.fillColor, equals(AppColors.disabledBackground));
    });

    testWidgets('PageHeader enforces Arabic RTL layout with start-side title and end-side actions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: PageHeader(
                  title: 'شاشة تجريبية',
                  subtitle: 'وصف إضافي للشاشة',
                  actions: [
                    ElevatedButton(onPressed: null, child: Text('إجراء')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('شاشة تجريبية'), findsOneWidget);
      expect(find.text('وصف إضافي للشاشة'), findsOneWidget);
      expect(find.text('إجراء'), findsOneWidget);

      final titleTopRight = tester.getTopRight(find.text('شاشة تجريبية'));
      final subtitleTopRight = tester.getTopRight(find.text('وصف إضافي للشاشة'));
      final actionTopLeft = tester.getTopLeft(find.text('إجراء'));

      // In Arabic RTL, start is right (higher X) and end is left (lower X)
      expect(titleTopRight.dx, greaterThan(actionTopLeft.dx));
      // Title and subtitle are start-aligned to the right
      expect((titleTopRight.dx - subtitleTopRight.dx).abs(), lessThanOrEqualTo(1.0));
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

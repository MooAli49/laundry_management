import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/domain/entities/customer.dart';

void main() {
  group('Customer Domain Entity Tests', () {
    final now = DateTime.utc(2026, 9, 25, 12, 0, 0);

    test('instantiates with required fields and optional address', () {
      final customer = Customer(
        id: 'cust-1',
        name: 'أحمد محمود',
        phone: '01012345678',
        address: '12 شارع الجمهورية',
        notes: 'ملاحظة',
        createdAt: now,
        updatedAt: now,
      );

      expect(customer.id, 'cust-1');
      expect(customer.name, 'أحمد محمود');
      expect(customer.phone, '01012345678');
      expect(customer.address, '12 شارع الجمهورية');
      expect(customer.notes, 'ملاحظة');
    });

    test('instantiates without address defaulting to null', () {
      final customer = Customer(
        id: 'cust-2',
        name: 'محمد علي',
        phone: '01012345679',
        createdAt: now,
        updatedAt: now,
      );

      expect(customer.address, isNull);
    });

    test('validates required fields: id, name, phone cannot be empty', () {
      expect(
        () => Customer(
          id: '',
          name: 'محمد',
          phone: '01011112222',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => Customer(
          id: 'c-1',
          name: '   ',
          phone: '01011112222',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );

      expect(
        () => Customer(
          id: 'c-1',
          name: 'محمد',
          phone: '  ',
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('copyWith sequence: address = "شارع التحرير" -> address = "شارع النيل" -> address = null', () {
      final initial = Customer(
        id: 'cust-seq',
        name: 'عميل التحرير',
        phone: '01099998888',
        address: 'شارع التحرير',
        createdAt: now,
        updatedAt: now,
      );
      expect(initial.address, 'شارع التحرير');

      // Then address = "شارع النيل"
      final step2 = initial.copyWith(address: 'شارع النيل');
      expect(step2.address, 'شارع النيل');
      expect(step2.name, 'عميل التحرير');

      // Then address = null
      final step3 = step2.copyWith(address: null);
      expect(step3.address, isNull);
      expect(step3.name, 'عميل التحرير');

      // Without specifying address keeps existing
      final step4 = step2.copyWith(name: 'اسم جديد');
      expect(step4.address, 'شارع النيل');
      expect(step4.name, 'اسم جديد');
    });

    test('copyWith supports clearAddress: true', () {
      final customer = Customer(
        id: 'cust-clr',
        name: 'عميل الحذف',
        phone: '01099997777',
        address: 'شارع الهرم',
        createdAt: now,
        updatedAt: now,
      );

      final cleared = customer.copyWith(clearAddress: true);
      expect(cleared.address, isNull);
    });

    test('equality and hashCode take address into account', () {
      final c1 = Customer(
        id: 'c-1',
        name: 'أحمد',
        phone: '01011112222',
        address: 'شارع 1',
        createdAt: now,
        updatedAt: now,
      );

      final c2 = Customer(
        id: 'c-1',
        name: 'أحمد',
        phone: '01011112222',
        address: 'شارع 1',
        createdAt: now,
        updatedAt: now,
      );

      final c3 = Customer(
        id: 'c-1',
        name: 'أحمد',
        phone: '01011112222',
        address: 'شارع 2',
        createdAt: now,
        updatedAt: now,
      );

      expect(c1, equals(c2));
      expect(c1.hashCode, equals(c2.hashCode));
      expect(c1, isNot(equals(c3)));
    });

    test('toString includes address', () {
      final customer = Customer(
        id: 'c-1',
        name: 'أحمد',
        phone: '01011112222',
        address: 'شارع الجمهورية',
        createdAt: now,
        updatedAt: now,
      );

      expect(customer.toString(), contains('address: شارع الجمهورية'));
    });
  });
}

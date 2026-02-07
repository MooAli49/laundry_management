import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:laundry_management/features/orders/presentation/widgets/order_card_widget.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الطلبات',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_active,
              color: Colors.grey.shade200.withOpacity(0.2),
              size: 24.sp,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Search and Filter Row
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: IconButton(
                  icon: Icon(Icons.tune, color: Colors.black54, size: 24.sp),
                  onPressed: () {},
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'البحث عن رقم الطلب أو اسم العميل',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20.sp,
                      ),
                      hintStyle: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(context).textTheme.bodySmall!.color,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Date Header
          _buildDateHeader('أكتوبر 2023'),
          SizedBox(height: 16.h),

          // Order Cards
          const OrderCard(
            orderNumber: 'ORD-2491#',
            customerName: 'أحمد محمد الشمري',
            date: '12 أكتوبر 2023',
            serviceDetails: 'تنظيف سجاد يدوي - قطعتين',
            status: 'قيد التنفيذ',
            statusColor: Color(0xFFC2410C), // Dark Orange
            statusBgColor: Color(0xFFFFEDD5), // Light Orange
          ),
          const OrderCard(
            orderNumber: 'ORD-2488#',
            customerName: 'سارة العتيبي',
            date: '11 أكتوبر 2023',
            serviceDetails: 'تنظيف سجاد حرير - قطعة واحدة',
            status: 'جاهز للتسليم',
            statusColor: Color(0xFF15803D), // Dark Green
            statusBgColor: Color(0xFFDCFCE7), // Light Green
          ),

          SizedBox(height: 24.h),
          // Date Header
          _buildDateHeader('سبتمبر 2023'),
          SizedBox(height: 16.h),

          const OrderCard(
            orderNumber: 'ORD-2485#',
            customerName: 'فهد بن سلمان',
            date: '28 سبتمبر 2023',
            serviceDetails: 'سجاد مكتب كبير - 4 قطع',
            status: 'بانتظار الاستلام',
            statusColor: Color(0xFF1D4ED8), // Dark Blue
            statusBgColor: Color(0xFFDBEAFE), // Light Blue
          ),

          SizedBox(height: 80.h), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Row(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            date,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
      ],
    );
  }
}

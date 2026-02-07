import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:laundry_management/core/extension/text_theme_extension.dart';
import 'package:laundry_management/core/theme/color_manager.dart';
import 'package:laundry_management/features/orders/presentation/widgets/order_item_widgets.dart';

class AddNewOrderScreen extends StatefulWidget {
  const AddNewOrderScreen({super.key});

  @override
  State<AddNewOrderScreen> createState() => _AddNewOrderScreenState();
}

class _AddNewOrderScreenState extends State<AddNewOrderScreen> {
  bool isUrgent = false;
  bool isDelivery = true;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'إضافة طلب جديد',
            style: context.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    // Search Bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'البحث برقم الجوال أو الاسم..',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Container(
                          width: 48.w,
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: ColorManager.primary,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.person_add,
                              color: Colors.white,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),

                    // Clothes Section
                    SectionHeader(
                      title: 'الملابس',
                      count: '2',
                      onAdd: () {},
                      icon: Icons.checkroom,
                      // Needs material icon, using checkroom as generic clothes
                    ),
                    const ClothesItemCard(title: 'توب رجالي', itemNumber: '1'),
                    const ClothesItemCard(title: 'شماغ', itemNumber: ''),

                    // Carpets Section
                    SectionHeader(
                      title: 'السجاد',
                      count: '1',
                      onAdd: () {},
                      icon: Icons.grid_view,
                    ),
                    const CarpetItemCard(title: 'سجادة صالون', itemNumber: '1'),

                    // Blankets Section
                    SectionHeader(
                      title: 'بطانيات',
                      count: '1',
                      onAdd: () {},
                      icon: Icons.bed,
                    ),
                    const BlanketItemCard(
                      title: 'بطانية كينج',
                      price: '35.00 ر.س',
                    ),

                    SizedBox(height: 24.h),

                    // Urgent Service Toggle
                    _buildServiceToggle(
                      title: 'خدمة مستعجلة',
                      value: isUrgent,
                      onChanged: (val) => setState(() => isUrgent = val),
                      icon: Icons.flash_on,
                      activeColor: Colors.blue,
                    ),
                    SizedBox(height: 12.h),

                    // Delivery Service Toggle
                    _buildServiceToggle(
                      title: 'خدمة التوصيل',
                      value: isDelivery,
                      onChanged: (val) => setState(() => isDelivery = val),
                      icon: Icons.local_shipping,
                      activeColor: Colors.blue,
                    ),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
            // Bottom Summary Section
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          'خصم الشركات 10%',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'المجموع النهائي (4 قطع)',
                            style: context.bodyMediumRegular,
                          ),
                          Row(
                            children: [
                              Text(
                                '215.00',
                                style: context.titleMedium.copyWith(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' ر.س',
                                style: context.bodyMediumRegular.copyWith(
                                  fontSize: 14.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '239.00 ر.س',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade400,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.primary,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'تأكيد وإنشاء الطلب',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceToggle({
    required String title,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
    required Color activeColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (val) => onChanged(val ?? false),
            activeColor: activeColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: activeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: activeColor, size: 20.sp),
          ),
        ],
      ),
    );
  }
}

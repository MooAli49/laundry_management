import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:laundry_management/core/extension/text_theme_extension.dart';
import 'package:laundry_management/core/theme/color_manager.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? count;
  final VoidCallback? onAdd;
  final IconData icon; // Add icon support for categories

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.onAdd,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: ColorManager.primary, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                title,
                style: context.bodyMediumRegular.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: 4.w),
                Text(
                  '($count)',
                  style: context.bodyMediumRegular.copyWith(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
          if (onAdd != null)
            InkWell(
              onTap: onAdd,
              child: Row(
                children: [
                  Text(
                    'إضافة بند',
                    style: TextStyle(
                      color: ColorManager.secondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.add_circle,
                    color: ColorManager.secondary,
                    size: 20.sp,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class BaseItemCard extends StatelessWidget {
  final String title;
  final String itemNumber;
  final Widget content;

  const BaseItemCard({
    super.key,
    required this.title,
    required this.itemNumber,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: context.bodyMediumRegular.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.more_vert, size: 20.sp, color: Colors.grey),
            ],
          ),
          SizedBox(height: 12.h),
          content,
        ],
      ),
    );
  }
}

class ClothesItemCard extends StatefulWidget {
  final String title;
  final String itemNumber;

  const ClothesItemCard({
    super.key,
    required this.title,
    required this.itemNumber,
  });

  @override
  State<ClothesItemCard> createState() => _ClothesItemCardState();
}

class _ClothesItemCardState extends State<ClothesItemCard> {
  int _selectedOption = 0; // 0: Wash & Iron, 1: Dry Clean

  @override
  Widget build(BuildContext context) {
    return BaseItemCard(
      title: '${widget.title} ${widget.itemNumber}',
      itemNumber: widget.itemNumber,
      content: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildServiceOption(
                  title: 'غسيل وكي',
                  isSelected: _selectedOption == 0,
                  onTap: () => setState(() => _selectedOption = 0),
                  icon: Icons.check_circle,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildServiceOption(
                  title: 'صبغة',
                  isSelected: _selectedOption == 1,
                  onTap: () => setState(() => _selectedOption = 1),
                  icon: Icons.circle_outlined,
                  isRadio: true,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildNoteField('ملحوظة للتمييز..', Icons.label_outline),
          SizedBox(height: 8.h),
          _buildNoteField('ملاحظات أخرى..', Icons.edit_outlined),
        ],
      ),
    );
  }

  Widget _buildServiceOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    bool isRadio = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? ColorManager.primary : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(20.r),
          color: isSelected ? ColorManager.primary.withOpacity(0.05) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isRadio && isSelected) ...[
              Icon(icon, color: ColorManager.primary, size: 16.sp),
              SizedBox(width: 4.w),
            ],
            if (isRadio) ...[
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? ColorManager.primary : Colors.grey,
                size: 16.sp,
              ),
              SizedBox(width: 4.w),
            ],
            Text(
              title,
              style: TextStyle(
                color: isSelected ? ColorManager.primary : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField(String hint, IconData icon) {
    return Container(
      height: 40.h,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12.sp,
                ),
              ),
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
          Icon(icon, color: Colors.grey.shade400, size: 18.sp),
        ],
      ),
    );
  }
}

class CarpetItemCard extends StatelessWidget {
  final String title;
  final String itemNumber;

  const CarpetItemCard({
    super.key,
    required this.title,
    required this.itemNumber,
  });

  @override
  Widget build(BuildContext context) {
    return BaseItemCard(
      title: '$title $itemNumber',
      itemNumber: itemNumber,
      content: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDimensionInput('الطول (م)')),
              SizedBox(width: 12.w),
              Expanded(child: _buildDimensionInput('العرض (م)')),
            ],
          ),
          SizedBox(height: 12.h),
          _buildNoteField(
            context,
            'ملاحظات (بقع، روائح..)',
            Icons.edit_outlined,
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المساحة: 14 م²',
                style: TextStyle(color: Colors.grey, fontSize: 12.sp),
              ),
              Text(
                '140.00 ر.س',
                style: TextStyle(
                  color: ColorManager.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionInput(String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.sp, color: Colors.grey),
          ),
          Text(
            '4.0', // Placeholder
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteField(BuildContext context, String hint, IconData icon) {
    return Container(
      height: 40.h,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12.sp,
                ),
              ),
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
          Icon(icon, color: Colors.grey.shade400, size: 18.sp),
        ],
      ),
    );
  }
}

class BlanketItemCard extends StatefulWidget {
  final String title;
  final String price;

  const BlanketItemCard({super.key, required this.title, required this.price});

  @override
  State<BlanketItemCard> createState() => _BlanketItemCardState();
}

class _BlanketItemCardState extends State<BlanketItemCard> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.price,
                style: TextStyle(
                  color: ColorManager.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => quantity++),
                      iconSize: 18.sp,
                      constraints: BoxConstraints(
                        minWidth: 32.w,
                        minHeight: 32.h,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    Text(
                      '$quantity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => setState(() {
                        if (quantity > 0) quantity--;
                      }),
                      iconSize: 18.sp,
                      constraints: BoxConstraints(
                        minWidth: 32.w,
                        minHeight: 32.h,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              Spacer(),
              Text(
                'الكمية',
                style: TextStyle(color: Colors.grey, fontSize: 12.sp),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildNoteField(context, 'إضافة ملاحظات خاصة..', Icons.edit_outlined),
        ],
      ),
    );
  }

  Widget _buildNoteField(BuildContext context, String hint, IconData icon) {
    return Container(
      height: 40.h,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12.sp,
                ),
              ),
              style: TextStyle(fontSize: 12.sp),
            ),
          ),
          Icon(icon, color: Colors.grey.shade400, size: 18.sp),
        ],
      ),
    );
  }
}

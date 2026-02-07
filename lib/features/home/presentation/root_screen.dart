import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:laundry_management/core/routing/routes.dart';
import 'package:laundry_management/core/theme/color_manager.dart';
import 'package:laundry_management/features/home/presentation/home_screen.dart';
import 'package:laundry_management/features/orders/presentation/orders_screen.dart';
import 'package:laundry_management/features/settings/presentation/settings_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int currentIndex = 0;
  var pages = [
    const HomeScreen(),
    const OrdersScreen(),
    const Center(child: Text('التقارير')),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: pages[currentIndex],
        floatingActionButton: Container(
          height: 60.w,
          width: 60.w,
          margin: EdgeInsets.only(top: 10.h),
          child: FloatingActionButton(
            backgroundColor: ColorManager.primary,
            elevation: 4,
            shape: const CircleBorder(),
            onPressed: () {
              context.pushNamed(Routes.addNewOrder);
            },
            child: Icon(Icons.add, size: 30.sp, color: Colors.white),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 10.0,
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).scaffoldBackgroundColor,
          elevation: 10,
          child: SizedBox(
            height: 70.h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_filled, 'الرئيسية'),
                _buildNavItem(1, Icons.receipt_long, 'الطلبات'),
                SizedBox(width: 48.w), // Space for FAB
                _buildNavItem(2, Icons.bar_chart_rounded, 'التقارير'),
                _buildNavItem(
                  3,
                  Icons.person,
                  'حسابي',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? ColorManager.primary : Colors.grey.shade400,
            size: 26.sp,
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? ColorManager.primary : Colors.grey.shade400,
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

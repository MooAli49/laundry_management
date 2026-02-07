import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:laundry_management/core/extension/text_theme_extension.dart';
import 'package:laundry_management/core/theme/color_manager.dart';
import 'package:laundry_management/core/theme/theme_manager.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildSectionHeader(context, 'أدوات الأعمال'),
          _buildSettingsItem(
            context,
            icon: Icons.people_alt_rounded,
            title: 'إدارة العملاء',
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.shade50,
            onTap: () {},
          ),
          _buildSettingsItem(
            context,
            icon: Icons.attach_money_rounded,
            title: 'إدارة المصروفات',
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.shade50,
            onTap: () {},
          ),
          SizedBox(height: 24.h),

          _buildSectionHeader(context, 'إعدادات التطبيق'),
          _buildSettingsItem(
            context,
            icon: Icons.print_rounded,
            title: 'إعدادات الطابعة',
            subtitle: 'اتصال بلوتوث',
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.shade50,
            onTap: () {},
          ),
          _buildSettingsItem(
            context,
            icon: Icons.message_rounded,
            title: 'إشعارات واتساب',
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.shade50,
            onTap: () {},
          ),
          _buildSettingsItem(
            context,
            icon: Icons.receipt_long_rounded,
            title: 'تخصيص الفاتورة',
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.shade50,
            onTap: () {},
          ),
          // Dark Mode Toggle
          ListenableBuilder(
            listenable: ThemeManager(),
            builder: (context, _) {
              final isDark = ThemeManager().isDarkMode;
              return _buildSettingsItem(
                context,
                icon: isDark ? Icons.dark_mode : Icons.light_mode,
                title: 'الوضع الليلي',
                iconColor: Colors.purple,
                iconBgColor: Colors.purple.shade50,
                trailing: Switch(
                  value: isDark,
                  onChanged: (val) => ThemeManager().toggleTheme(val),
                  activeThumbColor: ColorManager.primary,
                ),
              );
            },
          ),

          SizedBox(height: 24.h),

          _buildSectionHeader(context, 'الحساب'),
          _buildSettingsItem(
            context,
            icon: Icons.person_outline_rounded,
            title: 'الملف الشخصي',
            iconColor: Colors.blue,
            iconBgColor: Colors.blue.shade50,
            onTap: () {},
          ),
          _buildSettingsItem(
            context,
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            iconColor: Colors.red,
            iconBgColor: Colors.red.shade50,
            onTap: () {},
            isDestructive: true,
          ),

          SizedBox(height: 40.h),
          Center(
            child: Column(
              children: [
                Text(
                  'Laundry Pro v2.4.0',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '© 2024 Laundry Solutions Hub',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, top: 4.h),
      child: Text(title, style: context.titleMedium),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color iconBgColor,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: ThemeManager().isDarkMode
            ? ColorManager.darkSurfaceColor
            : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          if (!ThemeManager().isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ListTile(
        onTap: trailing != null ? null : onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        leading: Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: isDestructive ? iconBgColor : iconBgColor,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : iconColor,
            size: 24.sp,
          ),
        ),
        title: Text(
          title,
          style: context.bodyMediumRegular.copyWith(
            color: isDestructive ? Colors.red : null,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: context.bodySmallRegular.copyWith(
                  fontSize: 12.sp,
                  color: Colors.grey.shade500,
                ),
              )
            : null,
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16.sp,
              color: Colors.grey.shade400,
            ),
      ),
    );
  }
}

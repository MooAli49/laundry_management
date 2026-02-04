import 'package:flutter/material.dart';
import 'package:laundry_management/features/home/presentation/home_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int currentIndex = 0;
  var pages = [
    const HomeScreen(),
    const Center(child: Text('صفحة الطلبات')),
    const Center(child: Text('التقارير')),
    const Center(child: Text('الإعدادات')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),

          BottomNavigationBarItem(
            icon: Icon(Icons.request_quote),
            label: 'الطلبات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insert_chart_outlined_sharp),
            label: 'التقارير',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

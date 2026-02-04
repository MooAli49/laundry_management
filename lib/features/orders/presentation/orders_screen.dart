import 'package:flutter/material.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطلبات'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'البحث عن رقم الطلب أو اسم المتجر',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          buildOrderCard(
            'ORD-2491#',
            'أحمد محمد الشمري',
            'قيد التشفيش',
            'اكتوبر 2023',
            '12 اكتوبر 2023',
          ),
          const SizedBox(height: 12),
          buildOrderCard(
            'ORD-2488#',
            'سارة العتيبي',
            'جاهز للتسليم',
            'اكتوبر 2023',
            '11 اكتوبر 2023',
          ),
          const SizedBox(height: 12),
          buildOrderCard(
            'ORD-2485#',
            'فهد بن سلمان',
            'بانتظار الاستلام',
            'سبتمبر 2023',
            '28 سبتمبر 2023',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget buildOrderCard(
    String orderId,
    String name,
    String status,
    String month,
    String date,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.yellow[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(status, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              date,
              style: const TextStyle(fontSize: 12, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text(
                  'تغيير الحالة',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

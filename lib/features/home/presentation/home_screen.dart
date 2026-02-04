import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مرحبا, أحمد'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundImage: NetworkImage('https://via.placeholder.com/50'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 24),
          _buildStatusSection(),
          const SizedBox(height: 24),
          _buildOrdersSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      color: Colors.blue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('رصيدك اليوم', style: TextStyle(color: Colors.white)),
            const Text(
              '2,450',
              style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () {}, child: const Text('شحن الرصيد')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'حالة الطلبات',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatusCard('42', 'الكل'),
            _buildStatusCard('12', 'قيد الغسيل'),
            _buildStatusCard('8', 'جاهز'),
            _buildStatusCard('2', 'منتهي'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('عرض الكل', style: TextStyle(color: Colors.blue)),
            const Text(
              'أحدث الطلبات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._buildOrdersList(),
      ],
    );
  }

  List<Widget> _buildOrdersList() {
    return [
      _buildOrderCard('1024#', '150 ريال'),
      _buildOrderCard('1023#', '45 ريال'),
      _buildOrderCard('1022#', '120 ريال'),
    ];
  }

  Widget _buildOrderCard(String orderNo, String price) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.bookmark, color: Colors.blue),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [Text(orderNo), Text(price)],
            ),
          ],
        ),
      ),
    );
  }
}

class AppRoutes {
  AppRoutes._();

  static const String dashboard = '/';
  static const String orders = '/orders';
  static const String ordersNew = '/orders/new';
  static const String ordersDetail = '/orders/:id';
  static const String customers = '/customers';
  static const String customersDetail = '/customers/:id';
  static const String storage = '/storage';
  static const String reports = '/reports';
  static const String settings = '/settings';

  static String orderDetailPath(String id) => '/orders/$id';
  static String customerDetailPath(String id) => '/customers/$id';
  static String storagePath({String? orderId, String? orderNumber}) {
    final params = <String, String>{};
    if (orderId != null) params['orderId'] = orderId;
    if (orderNumber != null) params['orderNumber'] = orderNumber;
    if (params.isEmpty) return storage;
    return Uri(path: storage, queryParameters: params).toString();
  }
}

class AppStrings {
  AppStrings._();

  // Application
  static const String appName = 'نظام إدارة المغسلة';
  static const String defaultBusinessName = 'المغسلة الحديثة';

  // Primary Navigation & Route Titles
  static const String dashboard = 'الرئيسية';
  static const String orders = 'الطلبات';
  static const String customers = 'العملاء';
  static const String storage = 'التخزين';
  static const String reports = 'التقارير';
  static const String settings = 'الإعدادات';

  // Currency
  static const String currency = 'ج.م';
  static const String currencyCode = 'EGP';

  // Technical Errors / Failures
  static const String errorTitle = 'حدث خطأ ما';
  static const String errorDescription = 'تعذر إتمام العملية، يرجى المحاولة مرة أخرى';
  static const String serverError = 'حدث خطأ في الاتصال بالخادم';
  static const String cacheError = 'حدث خطأ في الوصول إلى البيانات المحلية';
  static const String networkError = 'يرجى التحقق من الاتصال بالإنترنت';
  static const String unexpectedError = 'حدث خطأ غير متوقع';

  // Common UI Actions & States
  static const String retry = 'إعادة المحاولة';
  static const String cancel = 'إلغاء';
  static const String confirm = 'تأكيد';
  static const String save = 'حفظ';
  static const String delete = 'حذف';
  static const String edit = 'تعديل';
  static const String search = 'بحث';
  static const String loading = 'جاري التحميل...';
  static const String noData = 'لا توجد بيانات';
  static const String emptyStateDefaultTitle = 'لا توجد عناصر لعرضها';

  // Customers — Header, List & Search
  static const String addCustomer = 'إضافة عميل';
  static String totalCustomersCount(int count) => 'إجمالي $count عميل';
  static const String searchCustomerPlaceholder = 'بحث باسم العميل أو رقم الهاتف...';
  static const String failedToLoadCustomers = 'تعذر تحميل العملاء';
  static const String noMatchingResults = 'لا توجد نتائج مطابقة';
  static const String noCustomersYet = 'لا يوجد عملاء حتى الآن';
  static const String noMatchingCustomersMessage = 'لم يتم العثور على عملاء مطابقين لنص البحث.';
  static const String addFirstCustomerPrompt = 'قم بإضافة عميلك الأول لبدء إدارة الطلبات.';
  static const String clearSearch = 'مسح البحث';
  static const String loadMoreCustomers = 'تحميل المزيد من العملاء';

  // Customers — Card & Summary
  static const String defaultCustomerInitial = 'ع';
  static String customerOrdersCount(int count) => '$count طلبات';
  static const String noOrdersYet = 'لا توجد طلبات';

  // Customers — Form Dialog
  static const String addCustomerTitle = 'إضافة عميل جديد';
  static const String editCustomerTitle = 'تعديل بيانات العميل';
  static const String customerNameLabel = 'اسم العميل *';
  static const String customerNameHint = 'مثال: محمد أحمد';
  static const String customerPhoneLabel = 'رقم الهاتف *';
  static const String customerPhoneHint = 'مثال: 01012345678';
  static const String notesLabel = 'ملاحظات';
  static const String customerNotesHint = 'أي ملاحظات خاصة بالعميل';
  static const String saveChanges = 'حفظ التعديلات';
  static const String saveCustomer = 'حفظ العميل';
  static const String viewCustomer = 'عرض العميل';

  // Customers — Validation Messages
  static const String customerNameRequired = 'اسم العميل مطلوب';
  static const String customerPhoneRequired = 'رقم الهاتف مطلوب';
  static const String customerPhoneInvalid = 'رقم الهاتف غير صحيح';
  static const String duplicateCustomerPhone = 'يوجد عميل مسجل بهذا الرقم';

  // Customers — Details Screen
  static const String failedToLoadCustomerDetails = 'تعذر تحميل بيانات العميل';
  static const String customerNotFound = 'العميل غير موجود';
  static const String back = 'رجوع';
  static const String createOrder = 'إنشاء طلب';
  static const String editCustomer = 'تعديل العميل';
  static const String totalOrders = 'إجمالي الطلبات';
  static const String activeOrders = 'طلبات جارية';
  static const String completedOrders = 'طلبات مكتملة';
  static const String totalPaid = 'إجمالي المدفوع';
  static const String totalRemaining = 'إجمالي المتبقي';
  static String orderHistoryWithCount(int count) => 'سجل الطلبات ($count)';
  static const String noOrdersForCustomer = 'لا توجد طلبات لهذا العميل';
  static const String createFirstOrderForCustomerPrompt = 'يمكنك إنشاء طلب جديد لهذا العميل بالضغط على زر إنشاء طلب.';
  static const String fullyPaid = 'مدفوع بالكامل';
  static String paidAmount(String amount) => 'المدفوع: $amount ج.م';
  static String remainingAmount(String amount) => 'المتبقي: $amount ج.م';
  static const String loadMoreOrders = 'تحميل المزيد من الطلبات';
  static const String customerUpdatedSuccessfully = 'تم تحديث بيانات العميل بنجاح';
}

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
  static const String errorDescription =
      'تعذر إتمام العملية، يرجى المحاولة مرة أخرى';
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
  static const String searchCustomerPlaceholder =
      'بحث باسم العميل أو رقم الهاتف...';
  static const String failedToLoadCustomers = 'تعذر تحميل العملاء';
  static const String noMatchingResults = 'لا توجد نتائج مطابقة';
  static const String noCustomersYet = 'لا يوجد عملاء حتى الآن';
  static const String noMatchingCustomersMessage =
      'لم يتم العثور على عملاء مطابقين لنص البحث.';
  static const String addFirstCustomerPrompt =
      'قم بإضافة عميلك الأول لبدء إدارة الطلبات.';
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
  static const String createFirstOrderForCustomerPrompt =
      'يمكنك إنشاء طلب جديد لهذا العميل بالضغط على زر إنشاء طلب.';
  static const String fullyPaid = 'مدفوع بالكامل';
  static String paidAmount(String amount) => 'المدفوع: $amount ج.م';
  static String remainingAmount(String amount) => 'المتبقي: $amount ج.م';
  static const String loadMoreOrders = 'تحميل المزيد من الطلبات';
  static const String customerUpdatedSuccessfully =
      'تم تحديث بيانات العميل بنجاح';

  // Storage
  static const String itemsRequiringStorage = 'تحتاج إلى تخزين';
  static const String currentStorage = 'مخزنة حاليًا';
  static const String searchStoragePlaceholder =
      'بحث برقم الطلب، اسم العميل، أو رقم الهاتف...';
  static const String storeAction = 'تخزين';
  static const String storeItemsAction = 'تخزين العناصر';
  static const String moveAction = 'نقل';
  static const String unstoreAction = 'إزالة من التخزين';
  static const String unstoreConfirmTitle = 'إزالة من التخزين؟';
  static const String unstoreConfirmMessage =
      'سيتم إلغاء التخزين الحالي لهذا العنصر وسيعود إلى قائمة العناصر التي تحتاج إلى تخزين، ويمكن تخزينه لاحقاً.';
  static const String confirmUnstore = 'تأكيد الإزالة';
  static const String storeItemsSuccess = 'تم تخزين العناصر بنجاح';
  static const String storeItemSuccess = 'تم تخزين العنصر بنجاح';
  static const String moveItemSuccess = 'تم نقل العنصر بنجاح';
  static const String unstoreItemSuccess = 'تمت إزالة العنصر من التخزين بنجاح';
  static String selectedItemsCount(int count) => 'تم تحديد $count عناصر';
  static const String noItemsRequiringStorage = 'لا توجد عناصر تحتاج إلى تخزين';
  static const String noCurrentStorageItems = 'لا توجد عناصر مخزنة حاليًا';
  static const String noStorageResults = 'لا توجد نتائج مطابقة';
  static const String noStorageResultsMessage =
      'لم يتم العثور على أي عناصر مطابقة لمعايير البحث أو الفلتر.';
  static const String failedToLoadStorage = 'تعذر تحميل بيانات التخزين';
  static const String storageLocationLabel = 'مكان التخزين *';
  static const String chooseStorageLocation = 'اختر موقع التخزين';
  static const String currentLocationLabel = 'الموقع الحالي';
  static const String newLocationLabel = 'الموقع الجديد *';
  static const String confirmStore = 'تأكيد التخزين';
  static const String confirmMove = 'تأكيد النقل';
  static const String cannotMoveToSameLocation =
      'لا يمكن نقل العنصر إلى نفس الموقع';
  static const String incompatibleLocation =
      'الموقع المحدد غير متوافق مع نوع العنصر';
  static const String conflictingTypesWarning =
      'القطع المحددة تتطلب أماكن تخزين مختلفة (أنواع مختلفة). يرجى تخزين كل نوع على حدة.';
  static const String loadMoreStorageItems = 'تحميل المزيد';
  static const String allItemTypes = 'جميع الأنواع';
  static const String allServices = 'جميع الخدمات';
  static const String allLocations = 'جميع المواقع';
  static const String filterByItemType = 'نوع القطعة';
  static const String filterByService = 'الخدمة';
  static const String filterByLocation = 'الموقع';
  static const String filterByExpectedPickup = 'تاريخ الاستلام المتوقع';
  static const String filterByOrderReceived = 'تاريخ استلام الطلب';
  static const String resetFilters = 'إعادة ضبط الفلاتر';
  static const String selectAtLeastOneItem = 'يجب اختيار قطعة واحدة على الأقل';
  static const String selectLocation = 'يجب اختيار مكان التخزين';
  static const String orderNumberPrefix = 'طلب #';

  // Settings — Navigation Tabs
  static const String settingsSubtitle =
      'إدارة البيانات الأساسية وإعدادات النظام';
  static const String tabBusinessInfo = 'بيانات النشاط';
  static const String tabInvoice = 'الفاتورة';
  static const String tabServices = 'الخدمات';
  static const String tabItemTypes = 'أنواع القطع';
  static const String tabItemDefinitions = 'تعريفات القطع';
  static const String tabCarpetSizes = 'مقاسات السجاد';
  static const String tabStorageLocations = 'مواقع التخزين';
  static const String tabExpenseCategories = 'تصنيفات المصروفات';

  // Settings — Business Info
  static const String businessNameLabel = 'اسم النشاط *';
  static const String businessNameHint = 'مثال: مغسلة الأمانة الحديثة';
  static const String businessNameRequired = 'اسم النشاط مطلوب';
  static const String businessPhoneLabel = 'رقم الهاتف';
  static const String businessPhoneHint = 'مثال: 01012345678';
  static const String businessAddressLabel = 'العنوان';
  static const String businessAddressHint =
      'مثال: شارع الجمهورية، المعادي، القاهرة';
  static const String invoiceFooterLabel = 'نص تذييل الفاتورة';
  static const String invoiceFooterHint =
      'مثال: شكراً لتعاملكم معنا، نسعد بخدمتكم دائماً';
  static const String saveBusinessSettingsSuccess =
      'تم حفظ بيانات النشاط بنجاح';

  // Settings — Invoice Preview
  static const String invoicePreviewTitle = 'معاينة الفاتورة الحرارية (80 مم)';
  static const String invoicePreviewDescription =
      'هذه معاينة حية لشكل الفاتورة بناءً على بيانات النشاط المدخلة';
  static const String sampleInvoiceItem1 = 'بدلة رجالي (2 قطعة) — غسيل ومكواة';
  static const String sampleInvoiceItem2 = 'سجادة صوف (2 × 3 م) — غسيل سجاد';
  static const String sampleInvoiceSubtotal = 'الإجمالي الفرعي';
  static const String sampleInvoiceTotal = 'الإجمالي المطلوب';
  static const String sampleInvoicePaid = 'المدفوع';
  static const String sampleInvoiceRemaining = 'المتبقي';

  // Settings — Services
  static const String addService = 'إضافة خدمة جديدة';
  static const String editService = 'تعديل الخدمة';
  static const String serviceNameLabel = 'اسم الخدمة *';
  static const String serviceNameHint = 'مثال: غسيل ومكواة';
  static const String serviceDescriptionLabel = 'الوصف';
  static const String serviceDescriptionHint = 'وصف اختياري للخدمة';
  static const String pricingTypeLabel = 'نوع التسعير *';
  static const String pricingPerPiece = 'بالقطعة';
  static const String pricingPerSquareMeter = 'بالمتر المربع';
  static const String pricingFixedPrice = 'سعر ثابت';
  static const String servicePriceLabel = 'السعر *';
  static const String priceLabelPerPiece = 'سعر القطعة';
  static const String priceLabelPerSquareMeter = 'سعر المتر المربع';
  static const String priceLabelFixedPrice = 'السعر الثابت';
  static const String supportedItemTypesLabel = 'أنواع القطع المدعومة *';
  static const String selectAtLeastOneItemType =
      'يجب اختيار نوع قطعة واحد على الأقل';
  static const String serviceNameRequired = 'اسم الخدمة مطلوب';
  static const String servicePriceRequired = 'السعر مطلوب';
  static const String servicePriceMustBePositive =
      'السعر يجب أن يكون أكبر من صفر';
  static const String servicePriceChangeNotice =
      'سيتم تطبيق السعر الجديد على الطلبات الجديدة فقط. الطلبات الحالية لن تتأثر.';
  static const String duplicateNameError = 'هذا الاسم مستخدم بالفعل';
  static const String deactivateServiceConfirmMessage =
      'سيتم تعطيل الخدمة ولن تظهر للطلبات الجديدة.\nالطلبات الحالية لن تتأثر.';
  static const String noServices = 'لا توجد خدمات مضافة';

  // Settings — Item Types
  static const String addItemType = 'إضافة نوع قطعة';
  static const String editItemType = 'تعديل نوع القطعة';
  static const String itemTypeNameLabel = 'اسم نوع القطعة *';
  static const String itemTypeNameHint = 'مثال: ملابس، سجاد، ستائر';
  static const String itemTypeNameRequired = 'اسم نوع القطعة مطلوب';
  static const String deactivateItemTypeConfirmMessage =
      'سيتم تعطيل نوع القطعة ولن يظهر في الطلبات الجديدة.';
  static const String noItemTypes = 'لا توجد أنواع قطع مضافة';
  static const String definitionsCount = 'عدد التعريفات';

  // Settings — Item Definitions
  static const String addItemDefinition = 'إضافة تعريف قطعة';
  static const String editItemDefinition = 'تعديل تعريف القطعة';
  static const String filterDefinitionsByItemType = 'عرض تعريفات:';
  static const String allItemDefinitions = 'جميع التعريفات';
  static const String itemDefinitionNameLabel = 'اسم التعريف *';
  static const String itemDefinitionNameHint = 'مثال: قميص، بنطلون، فستان';
  static const String itemDefinitionNameRequired = 'اسم التعريف مطلوب';
  static const String deactivateItemDefinitionConfirmMessage =
      'سيتم تعطيل تعريف القطعة ولن يظهر في الطلبات الجديدة.';
  static const String noItemDefinitions = 'لا توجد تعريفات مضافة';

  // Settings — Carpet Sizes
  static const String addCarpetSize = 'إضافة مقاس سجاد';
  static const String editCarpetSize = 'تعديل مقاس السجاد';
  static const String carpetLengthLabel = 'الطول (م) *';
  static const String carpetWidthLabel = 'العرض (م) *';
  static const String carpetAreaLabel = 'المساحة (م²)';
  static const String carpetLengthRequired =
      'الطول مطلوب ويجب أن يكون أكبر من صفر';
  static const String carpetWidthRequired =
      'العرض مطلوب ويجب أن يكون أكبر من صفر';
  static const String deactivateCarpetSizeConfirmMessage =
      'سيتم تعطيل مقاس السجاد ولن يظهر في الطلبات الجديدة.';
  static const String noCarpetSizes = 'لا توجد مقاسات سجاد مضافة';

  // Settings — Storage Locations
  static const String addStorageLocation = 'إضافة موقع تخزين';
  static const String editStorageLocation = 'تعديل موقع التخزين';
  static const String storageLocationNameLabel = 'اسم الموقع *';
  static const String storageLocationNameHint = 'مثال: رف A-1، ستاند السجاد 2';
  static const String storageLocationNameRequired = 'اسم الموقع مطلوب';
  static const String storageLocationCannotDeactivateWithItems =
      'لا يمكن تعطيل موقع التخزين لوجود قطع مخزنة به حالياً';
  static const String deactivateStorageLocationConfirmMessage =
      'سيتم تعطيل موقع التخزين ولن يتاح لتخزين قطع جديدة.';
  static const String noStorageLocations = 'لا توجد مواقع تخزين مضافة';

  // Settings — Expense Categories
  static const String addExpenseCategory = 'إضافة تصنيف مصروفات';
  static const String editExpenseCategory = 'تعديل تصنيف المصروفات';
  static const String expenseCategoryNameLabel = 'اسم التصنيف *';
  static const String expenseCategoryNameHint =
      'مثال: فواتير كهرباء، منظفات، صيانة';
  static const String expenseCategoryNameRequired = 'اسم التصنيف مطلوب';
  static const String deactivateExpenseCategoryConfirmMessage =
      'سيتم تعطيل تصنيف المصروفات ولن يظهر في تسجيل المصروفات الجديدة.';
  static const String noExpenseCategories = 'لا توجد تصنيفات مصروفات مضافة';

  // Settings — Shared Table & Status
  static const String statusActive = 'مُفعّلة';
  static const String statusInactive = 'معطّلة';
  static const String actionActivate = 'تفعيل';
  static const String actionDeactivate = 'تعطيل';
  static const String confirmDeactivationTitle = 'تأكيد التعطيل';
  static const String confirmDeactivationButton = 'نعم، تعطيل';
  static const String tableHeaderName = 'الاسم';
  static const String tableHeaderStatus = 'الحالة';
  static const String tableHeaderActions = 'الإجراءات';
  static const String tableHeaderPricingType = 'نوع التسعير';
  static const String tableHeaderPrice = 'السعر';
  static const String tableHeaderSupportedTypes = 'أنواع القطع المدعومة';
  static const String tableHeaderDimensions = 'المقاس';
  static const String tableHeaderArea = 'المساحة';
  static const String tableHeaderItemType = 'نوع القطعة';
}

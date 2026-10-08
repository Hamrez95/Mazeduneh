abstract final class AdminPermissions {
  static const dashboardRead = 'dashboard.read';
  static const ordersRead = 'orders.read';
  static const ordersExport = 'orders.export';
  static const ordersDocumentsRead = 'orders.documents.read';
  static const customersPiiRead = 'customers.pii.read';
  static const productsRead = 'products.read';
  static const productsWrite = 'products.write';
  static const inventoryRead = 'inventory.read';
  static const inventoryWrite = 'inventory.write';
  static const reportsRead = 'reports.read';
  static const customersRead = 'customers.read';
  static const customersExport = 'customers.export';
  static const pricingRead = 'pricing.read';
  static const pricingWrite = 'pricing.write';
  static const corporateRead = 'corporate.read';
  static const auditRead = 'audit.read';
  static const usersRead = 'users.read';

  static const groups = <String, List<AdminPermissionOption>>{
    'نمای کلی و گزارش‌ها': [
      AdminPermissionOption(
        dashboardRead,
        'داشبورد',
        'مشاهده آمار و شاخص‌های فروش.',
      ),
      AdminPermissionOption(
        reportsRead,
        'گزارش‌ها',
        'مشاهده گزارش‌های کسب‌وکار.',
      ),
    ],
    'سفارش و مشتری': [
      AdminPermissionOption(
        ordersRead,
        'مشاهده سفارش‌ها',
        'دیدن جزئیات و وضعیت سفارش‌ها.',
      ),
      AdminPermissionOption(
        'orders.write',
        'مدیریت سفارش‌ها',
        'تغییر وضعیت و پردازش سفارش‌ها.',
      ),
      AdminPermissionOption(
        ordersExport,
        'دریافت خروجی سفارش‌ها',
        'دریافت فایل سفارش‌ها با اطلاعات مجاز این کاربر.',
      ),
      AdminPermissionOption(
        ordersDocumentsRead,
        'مشاهده اسناد سفارش',
        'دسترسی به فاکتور و برگه بسته‌بندی با مجوز اطلاعات مشتری.',
      ),
      AdminPermissionOption(
        customersRead,
        'مشتری‌ها',
        'مشاهده پرونده مشتریان.',
      ),
      AdminPermissionOption(
        customersPiiRead,
        'مشاهده اطلاعات تماس مشتری',
        'مشاهده نام، تلفن و نشانی در بخش‌های مجاز.',
      ),
      AdminPermissionOption(
        'customers.export',
        'خروجی مشتری‌ها',
        'دریافت فایل خروجی از اطلاعات مشتریان.',
      ),
      AdminPermissionOption(
        'corporate.read',
        'درخواست‌های سازمانی',
        'مشاهده درخواست‌های خرید سازمانی.',
      ),
      AdminPermissionOption(
        'corporate.write',
        'مدیریت فروش سازمانی',
        'رسیدگی به درخواست‌های سازمانی.',
      ),
    ],
    'محصول و انبار': [
      AdminPermissionOption(
        productsRead,
        'مشاهده محصولات',
        'دیدن فهرست و مشخصات محصولات.',
      ),
      AdminPermissionOption(
        productsWrite,
        'ویرایش محصولات',
        'ساختن و ویرایش محصولات.',
      ),
      AdminPermissionOption(
        'categories.read',
        'مشاهده دسته‌بندی‌ها',
        'دیدن دسته‌بندی محصولات.',
      ),
      AdminPermissionOption(
        'categories.write',
        'مدیریت دسته‌بندی‌ها',
        'ساختن و ویرایش دسته‌بندی‌ها.',
      ),
      AdminPermissionOption(
        inventoryRead,
        'مشاهده موجودی',
        'دیدن موجودی و گردش کالا.',
      ),
      AdminPermissionOption(
        inventoryWrite,
        'مدیریت موجودی',
        'ثبت و اصلاح موجودی.',
      ),
    ],
    'قیمت‌گذاری و محتوا': [
      AdminPermissionOption(
        pricingRead,
        'مشاهده قیمت‌گذاری',
        'دیدن تنظیمات قیمت و فروش.',
      ),
      AdminPermissionOption(
        pricingWrite,
        'مدیریت قیمت‌گذاری',
        'تغییر قیمت‌ها و قواعد فروش.',
      ),
      AdminPermissionOption(
        'content.read',
        'مشاهده محتوا',
        'دیدن محتوای فروشگاه.',
      ),
      AdminPermissionOption(
        'content.write',
        'مدیریت محتوا',
        'ویرایش محتوا و رسانه‌ها.',
      ),
    ],
    'امنیت': [
      AdminPermissionOption(
        auditRead,
        'گزارش امنیتی',
        'مشاهده رویدادهای ثبت‌شده مدیریتی.',
      ),
      AdminPermissionOption(
        'settings.write',
        'تنظیمات فروشگاه',
        'تغییر تنظیمات تجاری فروشگاه.',
      ),
    ],
  };
}

class AdminPermissionOption {
  const AdminPermissionOption(this.key, this.label, this.description);
  final String key;
  final String label;
  final String description;
}


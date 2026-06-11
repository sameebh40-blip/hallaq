enum AppUserRole {
  unknown,
  customer,
  barber,
  shopOwner,
  admin;

  static AppUserRole fromDb(String? value) {
    return switch (value) {
      'client' => AppUserRole.customer,
      'barber' => AppUserRole.barber,
      'shop_owner' => AppUserRole.shopOwner,
      'admin' => AppUserRole.admin,
      'customer' => AppUserRole.customer,
      _ => AppUserRole.unknown,
    };
  }

  String toDb() {
    return switch (this) {
      AppUserRole.unknown => 'unknown',
      AppUserRole.customer => 'customer',
      AppUserRole.barber => 'barber',
      AppUserRole.shopOwner => 'shop_owner',
      AppUserRole.admin => 'admin',
    };
  }
}

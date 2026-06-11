import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = <Locale>[Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return value ?? const AppLocalizations(Locale('en'));
  }

  static const _en = <String, String>{
    'appName': 'Hallaq',
    'cityTitle': 'HALLAQ CITY',
    'citySubtitle': 'Your city companion',
    'quickActionsTitle': 'Quick Actions',
    'nearbyBarbers': 'Nearby Barbers',
    'nearbyShops': 'Nearby Shops',
    'trendingToday': 'Trending Today',
    'offersNearYou': 'Offers Near You',
    'popularStyles': 'Popular Styles',
    'cityStatistics': 'City Statistics',
    'bookBarber': 'Book Barber',
    'findShops': 'Find Shops',
    'discoverReels': 'Discover Reels',
    'offers': 'Offers',
    'barbersLabel': 'Barbers',
    'shopsLabel': 'Shops',
    'changeArea': 'Change Area',
    'autoDetected': 'Auto detected',
    'nextTime': 'Next: {time}',
    'now': 'now',
    'discountOff': '{discount} OFF',
    'specialOffer': 'Special Offer',
    'premiumDealNearYou': 'Premium deal near you.',
    'trendingReel': 'Trending Reel',
    'bookingsToday': '{count} bookings today',
    'viewsToday': '{count} views today',
    'likesToday': '{count} likes today',
    'mostBookedBarber': 'Most Booked Barber',
    'mostBookedShop': 'Most Booked Shop',
    'mostWatchedReel': 'Most Watched Reel',
    'mostLikedStyle': 'Most Liked Style',
    'activeBarbersStat': 'Active Barbers',
    'barberShopsStat': 'Barber Shops',
    'monthlyBookingsStat': 'Monthly Bookings',
    'averageRatingStat': 'Average Rating',
    'noBarbersNearbyTitle': 'No barbers nearby',
    'noBarbersNearbyDescription': 'Change area to see recommendations.',
    'noShopsNearbyTitle': 'No shops nearby',
    'noShopsNearbyDescription': 'Change area to see premium shops.',
    'noOffersRightNowTitle': 'No offers right now',
    'noOffersRightNowDescription': 'Check back soon for premium deals.',
    'noStylesYetTitle': 'No styles yet',
    'noStylesYetDescription': 'New styles will appear here.',
    'validUntil': 'Valid until {date}',
    'city': 'City',
    'authWelcomeTitle': 'Book your best cut in Bahrain',
    'next': 'Next',
    'getStarted': 'Get started',
    'skip': 'Skip',
    'onboardingFindBestBarbersTitle': 'Find Bahrain’s Best Barbers',
    'onboardingFindBestBarbersSubtitle': 'Curated barbers. Premium experience.',
    'onboardingTrendingHaircutsTitle': 'Discover Trending Haircuts',
    'onboardingTrendingHaircutsSubtitle': 'Big visuals. Luxury vibes.',
    'onboardingBookInSecondsTitle': 'Book In Seconds',
    'onboardingBookInSecondsSubtitle': 'Service → date → time. Done.',
    'onboardingGetStartedTitle': 'Join Bahrain’s Grooming Community',
    'onboardingGetStartedSubtitle': 'Follow top barbers, save looks, and book instantly.',
    'demoMode': 'Launch mode',
    'demoModeSubtitle': 'Loads premium demo content for presentations.',
    'somethingWentWrongTitle': 'Could not load',
    'somethingWentWrongDescription': 'Check your connection and try again.',
    'tryAgain': 'Try again',
    'noBookingsTitle': 'No bookings yet',
    'noBookingsDescription': 'Book your first appointment in Bahrain.',
    'noNotificationsTitle': 'No notifications',
    'noNotificationsDescription': 'When something happens, it’ll show up here.',
    'exploreNow': 'Discover',
    'noReviewsTitle': 'No reviews yet',
    'noReviewsDescription': 'No reviews yet. Be the first to review after your booking.',
    'noAvailabilityTitle': 'No available times',
    'noAvailabilityDescription': 'No available times for this day. Please pick another date.',
    'noServicesDescription': 'No services added yet.',
    'noPortfolioDescription': 'No portfolio yet.',
    'all': 'All',
    'select': 'Select',
    'popular': 'Popular',
    'verified': 'Verified',
    'reply': 'Reply',
    'signIn': 'Sign in',
    'signUp': 'Sign up',
    'fullName': 'Full name',
    'email': 'Email',
    'phoneNumber': 'Phone number',
    'changePhoto': 'Change photo',
    'changeCover': 'Change cover',
    'removePhoto': 'Remove photo',
    'guestBrowsingTitle': 'You are browsing as a guest',
    'guestBrowsingSubtitle': 'Sign in to manage bookings and save favorites.',
    'password': 'Password',
    'confirmPassword': 'Confirm password',
    'forgotPassword': 'Forgot password?',
    'emailSent': 'Email sent',
    'resetPassword': 'Reset password',
    'newPassword': 'New password',
    'updatePassword': 'Update password',
    'continueText': 'Continue',
    'orContinueWith': 'Or continue with',
    'google': 'Google',
    'apple': 'Apple',
    'chooseRoleTitle': 'Choose account type',
    'chooseRoleSubtitle': 'This helps personalize your experience',
    'chooseRoleCustomerSubtitle': 'Discover and book barbers',
    'chooseRoleBarberSubtitle': 'Accept bookings and post reels',
    'chooseRoleShopOwnerSubtitle': 'Manage shop and staff',
    'home': 'Home',
    'explore': 'Discover',
    'bookings': 'Bookings',
    'upcomingBookings': 'Upcoming',
    'completedBookings': 'Completed',
    'notifications': 'Notifications',
    'profile': 'Profile',
    'premiumBadge': 'Premium',
    'currentLocationLabel': 'Current location',
    'enableLocationTitle': 'Find Nearby Barbers',
    'enableLocationDescription': 'Allow Hallaq to access your location to discover nearby barbers, salons, beauty centers, and offers around you.',
    'allowLocation': 'Allow Location',
    'homeSearchPlaceholder': 'Search barbers, salons, beauty centers, services…',
    'categoriesTitle': 'Categories',
    'nearbyShopsTitle': 'Nearby shops',
    'topBarbersNearYouTitle': 'Top barbers near you',
    'noNearbyShopsTitle': 'No nearby shops yet',
    'noNearbyShopsDescription': 'Try another area or check back soon.',
    'noNearbyBarbersTitle': 'No nearby barbers yet',
    'noNearbyBarbersDescription': 'Try another area or check back soon.',
    'searchHint': 'Search barbers, shops, styles, areas',
    'search': 'Search',
    'trendingBarbers': 'Trending barbers',
    'featuredShops': 'Featured barbershops',
    'viewShop': 'View shop',
    'independent': 'Independent',
    'team': 'Team',
    'gallery': 'Gallery',
    'about': 'About',
    'bookWithTeam': 'Book with team',
    'chooseSpecificBarber': 'Choose specific barber',
    'anyAvailableBarber': 'Any available barber',
    'viewProfile': 'View profile',
    'ourStory': 'Our story',
    'contact': 'Contact',
    'openingHoursTitle': 'Opening hours',
    'addressTitle': 'Address',
    'call': 'Call',
    'whatsapp': 'WhatsApp',
    'instagram': 'Instagram',
    'like': 'Like',
    'comment': 'Comment',
    'save': 'Save',
    'shareAction': 'Share',
    'visitShop': 'Visit shop',
    'getDirections': 'Get Directions',
    'writeAComment': 'Write a comment…',
    'nearby': 'Nearby',
    'newHaircuts': 'New haircuts',
    'discoverBahrain': 'Discover Bahrain',
    'discoverPremiumSpots': 'Premium spots & studios',
    'specialOffers': 'Special offers',
    'bookNow': 'Book now',
    'yourBarber': 'Your barber',
    'nextAvailable': 'Next available',
    'nextAppointment': 'Next appointment',
    'bookAgain': 'Book again',
    'setAsMyBarber': 'Set as My Barber',
    'removeMyBarber': 'Remove My Barber',
    'makeMyBarberTitle': 'Make this My Barber',
    'makeMyBarberSubtitle': 'Rebook instantly and get special offers.',
    'notNow': 'Not now',
    'manage': 'Manage',
    'usuallyRespondsIn': 'Usually responds in',
    'fastResponder': 'Fast responder',
    'peopleViewedToday': 'people viewed today',
    'freshCutReminder': 'Time for a fresh cut?',
    'moreTimes': 'More times',
    'today': 'Today',
    'tomorrow': 'Tomorrow',
    'noAvailabilityThisWeek': 'No availability this week',
    'requestATime': 'Request a time',
    'follow': 'Follow',
    'following': 'Following',
    'savedBarbers': 'Saved barbers',
    'savedBarbersStat': 'Saved barbers',
    'savedShops': 'Saved shops',
    'haircutHistory': 'Haircut history',
    'paymentMethods': 'Payment methods',
    'premiumCustomer': 'Premium Customer',
    'editProfile': 'Edit profile',
    'member': 'Member',
    'memberSince': 'Member since {date}',
    'loyaltyPoints': 'Loyalty points',
    'pointsHistory': 'Points history',
    'redeemPoints': 'Redeem',
    'earned': 'Earned',
    'spent': 'Spent',
    'noPointsYetTitle': 'No points yet',
    'noPointsYetSubtitle': 'Complete bookings to start earning loyalty points.',
    'genericError': 'Could not load. Please try again.',
    'profileZeroStatsCta': 'Start exploring barbers and book your first haircut',
    'services': 'Services',
    'reviews': 'Reviews',
    'portfolio': 'Portfolio',
    'videos': 'Videos',
    'workingHours': 'Working hours',
    'settings': 'Settings',
    'helpSupport': 'Help & Support',
    'language': 'Language',
    'systemLanguage': 'System',
    'englishLanguage': 'English',
    'arabicLanguage': 'Arabic',
    'theme': 'Theme',
    'darkMode': 'Dark mode',
    'lightMode': 'Light mode',
    'systemMode': 'System',
    'logout': 'Logout',
    'roleCustomer': 'Customer',
    'roleBarber': 'Barber',
    'roleShopOwner': 'Shop owner',
    'roleAdmin': 'Admin',
    'availableNow': 'Available now',
    'queue': 'Queue',
    'waitingTime': 'Waiting time',
    'minutes': 'min',
    'myBookings': 'My bookings',
    'upcoming': 'Upcoming',
    'past': 'Past',
    'cancel': 'Cancel',
    'reschedule': 'Reschedule',
    'confirmBooking': 'Confirm booking',
    'selectBarber': 'Select barber',
    'selectService': 'Select service',
    'selectDate': 'Select date',
    'selectTime': 'Select time',
    'bookingChange': 'Change',
    'bookingAnyBarber': 'Any barber',
    'bookingSelected': 'Selected',
    'bookingChoose': 'Choose',
    'bookingAnyBarberSelectedHint': 'Any barber selected.',
    'bookingChooseBarberToSeeDates': 'Choose a barber to see available dates.',
    'bookingBarberSelectedHint': 'Barber selected.',
    'bookingNoAvailabilityThisMonth': 'No availability this month',
    'bookingNextAvailableDay': 'Next available day',
    'bookingSearching': 'Searching…',
    'bookingSelectedDate': 'Selected date',
    'bookingChooseDateToContinue': 'Choose a date to continue',
    'bookingReservedTimeExpired': 'Reserved time expired. Please select the time again.',
    'bookingStatusPast': 'Past',
    'bookingStatusAvailable': 'Available',
    'bookingStatusFull': 'Fully booked',
    'bookingStatusLoading': 'Loading availability…',
    'bookingPastDateSnack': 'Past date. Choose another day.',
    'bookingFullyBookedSnack': 'Fully booked. Choose another day.',
    'bookingLoadingAvailabilitySnack': 'Loading availability…',
    'bookingAnyBarberSubtitle': 'We’ll assign an available barber at confirmation.',
    'bookingAnyBarberSubtitle2': 'We’ll pick an available barber for the time you choose.',
    'bookingNoBarbersAvailable': 'No barbers available.',
    'bookingSelectServiceToSeeAvailability': 'Select a service to see availability.',
    'bookingSelectShopToSeeAvailability': 'Select a shop to see availability.',
    'bookingSelectBarberToSeeAvailability': 'Select a barber to see availability.',
    'bookingNoAvailabilityFoundUpcomingMonths': 'No availability found in upcoming months.',
    'bookingNoBarberAvailableTime': 'No barber is available at that time. Please pick another time.',
    'bookingTimeNoLongerAvailable': 'That time is no longer available. Please pick another time.',
    'done': 'Done',
    'requiredField': 'Required',
    'acceptTermsMessage': 'Please accept Terms & Conditions',
    'invalidEmail': 'Enter a valid email',
    'invalidPhone': 'Enter a valid phone number',
    'passwordTooShort': 'Password must be at least 8 characters',
    'passwordsDontMatch': 'Passwords do not match',
    'errorGeneric': 'Could not load',
    'retry': 'Retry',
    'welcomeBack': 'Welcome back',
    'currentAreaLabel': 'Current area',
    'homeHeroTitle': 'Bahrain’s Best Barbers',
    'homeHeroSubtitle': 'Book your next cut in seconds.',
    'featuredBarbers': 'Featured barbers',
    'quickCategories': 'Quick categories',
    'categoryFade': 'Fade',
    'categoryBeard': 'Beard',
    'categoryKids': 'Kids',
    'categoryColor': 'Hair color',
    'categoryVip': 'VIP',
    'categoryAvailableNow': 'Available now',
    'premiumMembership': 'Hallaq Premium',
    'comingSoon': 'Coming soon',
    'premiumBenefitPriority': 'Priority Booking',
    'premiumBenefitDiscounts': 'Exclusive Discounts',
    'premiumBenefitVip': 'VIP Offers',
    'seasonalRamadan': 'Ramadan Specials',
    'seasonalEid': 'Eid Offers',
    'seasonalGraduation': 'Graduation Cuts',
    'seasonalWedding': 'Wedding Packages',
    'trendingSearches': 'Trending searches',
    'typeToSearch': 'Type to search',
    'noResults': 'No results',
    'searchBarbers': 'Barbers',
    'searchShops': 'Shops',
    'badgeVerified': 'Verified',
    'badgeElite': 'Elite',
    'badgeTrending': 'Trending',
    'badgeCertified': 'Hallaq Certified',
    'badgeTopRated': 'Top Rated',
    'followers': 'Followers',
    'bookingsCount': 'Bookings',
    'awards': 'Hallaq Awards',
    'monthlyRankings': 'Monthly rankings',
    'awardBestBarber': 'Best Barber Bahrain',
    'awardBestFade': 'Best Fade Specialist',
    'awardMostBooked': 'Most Booked Barber',
    'awardRisingStar': 'Rising Star',
    'awardBestShop': 'Best Barbershop',
    'aboutHallaq': 'About Hallaq',
    'builtInBahrain': 'Built in Bahrain',
    'supportingLocalBarbers': 'Supporting local barbers',
    'secureBookingExperience': 'Secure booking experience',
    'verifiedProfessionals': 'Verified professionals',
    'modernDiscoveryPlatform': 'Modern barber discovery platform',
    'bahrain': 'Bahrain',
    'seasonal': 'Seasonal',
    'viewAll': 'View all',
    'open': 'Open',
    'closed': 'Closed',
    'bio': 'Bio',
    'experience': 'Experience',
    'worksAt': 'Works at',
    'write': 'Write',
    'professional': 'Professional',
    'years10Plus': '10+ years',
    'bioFallback': 'Premium barber in Bahrain. Book with confidence.',
    'recentSearches': 'Recent searches',
    'clear': 'Clear',
    'duration': 'Duration',
    'total': 'Total',
    'bookingCreatedTitle': 'Booking confirmed',
    'bookingCreatedSubtitle': 'See you soon.',
    'share': 'Share',
    'qrCode': 'QR Code',
    'errorOfflineTitle': 'Offline mode',
    'errorOfflineDescription': 'You are offline. Please reconnect and try again.',
    'errorConnection': 'Connection error. Please try again.',
    'errorPermissionDenied': 'Permission denied.',
    'errorSessionExpired': 'Session expired. Please sign in again.',
    'errorStorageBucketMissing': 'Storage bucket missing.',
    'errorInvalidGoogleMapsLink': 'Invalid Google Maps link.',
    'errorMissingRequiredField': 'Missing required field.',
    'errorInvalidImageType': 'Invalid image type.',
    'errorFileTooLarge': 'File too large.',
    'errorUploadFailed': 'Upload failed.',
    'errorSaveFailed': 'Save failed.',
    'errorDetailsAction': 'Details',
    'errorDetailsTitle': 'Error details',
    'copy': 'Copy',
    'close': 'Close',
    'errorAvailabilityTitle': 'Can’t load availability',
    'errorAvailabilityGeneric': 'Availability can’t be loaded right now. Please try again.',
    'errorAvailabilityTimeout': 'The server is taking too long to respond. Please try again.',
    'errorAvailabilityMissingRpc':
        'Availability service is not configured on the server (missing RPC). Please deploy the Supabase migrations and try again.',
    'errorAvailabilityPermission': 'You don’t have permission to load availability. Please sign in again, or fix Supabase permissions.',
  };

  static const _ar = <String, String>{
    'appName': 'حلّاق',
    'cityTitle': 'مدينة حلّاق',
    'citySubtitle': 'دليلك في مدينتك',
    'city': 'المدينة',
    'quickActionsTitle': 'إجراءات سريعة',
    'nearbyBarbers': 'حلاقون قريبون',
    'nearbyShops': 'صالونات قريبة',
    'trendingToday': 'الأكثر رواجًا اليوم',
    'offersNearYou': 'عروض بالقرب منك',
    'popularStyles': 'قصّات رائجة',
    'cityStatistics': 'إحصائيات المدينة',
    'bookBarber': 'احجز حلاق',
    'findShops': 'ابحث عن صالونات',
    'discoverReels': 'استكشف الريلز',
    'offers': 'العروض',
    'barbersLabel': 'حلاقون',
    'shopsLabel': 'صالونات',
    'changeArea': 'تغيير المنطقة',
    'autoDetected': 'تم تحديده تلقائيًا',
    'nextTime': 'التالي: {time}',
    'now': 'الآن',
    'discountOff': 'خصم {discount}',
    'specialOffer': 'عرض خاص',
    'premiumDealNearYou': 'عرض مميز بالقرب منك.',
    'trendingReel': 'ريلز رائج',
    'bookingsToday': '{count} حجوزات اليوم',
    'viewsToday': '{count} مشاهدة اليوم',
    'likesToday': '{count} إعجابات اليوم',
    'mostBookedBarber': 'الأكثر حجزًا (حلاق)',
    'mostBookedShop': 'الأكثر حجزًا (صالون)',
    'mostWatchedReel': 'الأكثر مشاهدة (ريلز)',
    'mostLikedStyle': 'الأكثر إعجابًا (قصة)',
    'activeBarbersStat': 'حلاقون نشطون',
    'barberShopsStat': 'صالونات حلاقة',
    'monthlyBookingsStat': 'حجوزات شهرية',
    'averageRatingStat': 'متوسط التقييم',
    'noBarbersNearbyTitle': 'لا يوجد حلاقون قريبون',
    'noBarbersNearbyDescription': 'غيّر المنطقة لرؤية الاقتراحات.',
    'noShopsNearbyTitle': 'لا توجد صالونات قريبة',
    'noShopsNearbyDescription': 'غيّر المنطقة لرؤية صالونات مميزة.',
    'noOffersRightNowTitle': 'لا توجد عروض الآن',
    'noOffersRightNowDescription': 'عد قريبًا لعروض مميزة.',
    'noStylesYetTitle': 'لا توجد قصّات بعد',
    'noStylesYetDescription': 'ستظهر القصّات الجديدة هنا.',
    'validUntil': 'صالحة حتى {date}',
    'authWelcomeTitle': 'احجز أفضل قصة في البحرين',
    'next': 'التالي',
    'getStarted': 'ابدأ الآن',
    'skip': 'تخطي',
    'onboardingFindBestBarbersTitle': 'اعثر على أفضل حلاقين البحرين',
    'onboardingFindBestBarbersSubtitle': 'حلاقون مختارون. تجربة فاخرة.',
    'onboardingTrendingHaircutsTitle': 'اكتشف القصّات الرائجة',
    'onboardingTrendingHaircutsSubtitle': 'صور كبيرة. طابع فاخر.',
    'onboardingBookInSecondsTitle': 'احجز خلال ثوانٍ',
    'onboardingBookInSecondsSubtitle': 'الخدمة → التاريخ → الوقت. تم.',
    'onboardingGetStartedTitle': 'انضم إلى مجتمع العناية في البحرين',
    'onboardingGetStartedSubtitle': 'تابع أفضل الحلاقين، احفظ الإلهام، واحجز فورًا.',
    'demoMode': 'وضع الإطلاق',
    'demoModeSubtitle': 'يحمّل محتوى تجريبي فاخر للعروض.',
    'somethingWentWrongTitle': 'تعذر التحميل',
    'somethingWentWrongDescription': 'تحقق من الاتصال وحاول مرة أخرى.',
    'tryAgain': 'حاول مرة أخرى',
    'noBookingsTitle': 'لا توجد حجوزات بعد',
    'noBookingsDescription': 'احجز موعدك الأول في البحرين.',
    'noNotificationsTitle': 'لا توجد إشعارات',
    'noNotificationsDescription': 'عندما يحدث شيء، سيظهر هنا.',
    'exploreNow': 'اكتشف',
    'noReviewsTitle': 'لا توجد تقييمات بعد',
    'noReviewsDescription': 'لا توجد مراجعات بعد. كن أول من يراجع بعد الحجز.',
    'noAvailabilityTitle': 'لا توجد مواعيد متاحة',
    'noAvailabilityDescription': 'لا توجد مواعيد متاحة لهذا اليوم. اختر تاريخًا آخر.',
    'noServicesDescription': 'لم تتم إضافة خدمات بعد.',
    'noPortfolioDescription': 'لا يوجد معرض أعمال بعد.',
    'all': 'الكل',
    'select': 'اختر',
    'popular': 'الأكثر طلباً',
    'verified': 'موثّق',
    'reply': 'رد',
    'signIn': 'تسجيل الدخول',
    'signUp': 'إنشاء حساب',
    'fullName': 'الاسم الكامل',
    'email': 'البريد الإلكتروني',
    'phoneNumber': 'رقم الهاتف',
    'changePhoto': 'تغيير الصورة',
    'changeCover': 'تغيير الغلاف',
    'removePhoto': 'إزالة الصورة',
    'guestBrowsingTitle': 'أنت تتصفح كضيف',
    'guestBrowsingSubtitle': 'سجّل الدخول لإدارة حجوزاتك وحفظ المفضلة.',
    'password': 'كلمة المرور',
    'confirmPassword': 'تأكيد كلمة المرور',
    'forgotPassword': 'نسيت كلمة المرور؟',
    'emailSent': 'تم إرسال البريد',
    'resetPassword': 'إعادة تعيين كلمة المرور',
    'newPassword': 'كلمة مرور جديدة',
    'updatePassword': 'تحديث كلمة المرور',
    'continueText': 'متابعة',
    'orContinueWith': 'أو تابع باستخدام',
    'google': 'جوجل',
    'apple': 'آبل',
    'chooseRoleTitle': 'اختر نوع الحساب',
    'chooseRoleSubtitle': 'يساعدنا ذلك على تخصيص تجربتك',
    'chooseRoleCustomerSubtitle': 'اكتشف واحجز عند الحلاقين',
    'chooseRoleBarberSubtitle': 'استقبل الحجوزات وانشر الريلز',
    'chooseRoleShopOwnerSubtitle': 'أدر الصالون والطاقم',
    'home': 'الرئيسية',
    'explore': 'اكتشف',
    'bookings': 'الحجوزات',
    'upcomingBookings': 'القادمة',
    'completedBookings': 'المكتملة',
    'notifications': 'الإشعارات',
    'profile': 'الملف الشخصي',
    'premiumBadge': 'بريميوم',
    'currentLocationLabel': 'الموقع الحالي',
    'enableLocationTitle': 'اعثر على الحلاقين القريبين',
    'enableLocationDescription': 'اسمح لـ Hallaq بالوصول إلى موقعك لاكتشاف الحلاقين القريبين والصالونات ومراكز التجميل والعروض من حولك.',
    'allowLocation': 'السماح بالموقع',
    'homeSearchPlaceholder': 'ابحث عن حلاقين، صالونات، مراكز تجميل، خدمات…',
    'categoriesTitle': 'الفئات',
    'nearbyShopsTitle': 'المتاجر القريبة',
    'topBarbersNearYouTitle': 'أفضل الحلاقين قربك',
    'noNearbyShopsTitle': 'لا توجد متاجر قريبة بعد',
    'noNearbyShopsDescription': 'جرّب منطقة أخرى أو عد لاحقًا.',
    'noNearbyBarbersTitle': 'لا يوجد حلاقون قريبون بعد',
    'noNearbyBarbersDescription': 'جرّب منطقة أخرى أو عد لاحقًا.',
    'searchHint': 'ابحث عن حلاقين، صالونات، ستايلات، مناطق',
    'search': 'بحث',
    'trendingBarbers': 'حلاقون رائجون',
    'featuredShops': 'صالونات مميزة',
    'viewShop': 'عرض الصالون',
    'independent': 'مستقل',
    'team': 'الفريق',
    'gallery': 'المعرض',
    'about': 'نبذة',
    'bookWithTeam': 'احجز مع الفريق',
    'chooseSpecificBarber': 'اختر حلاقًا محددًا',
    'anyAvailableBarber': 'أي حلاق متاح',
    'viewProfile': 'عرض الملف',
    'ourStory': 'قصتنا',
    'contact': 'تواصل',
    'openingHoursTitle': 'ساعات العمل',
    'addressTitle': 'العنوان',
    'call': 'اتصال',
    'whatsapp': 'واتساب',
    'instagram': 'إنستغرام',
    'like': 'إعجاب',
    'comment': 'تعليق',
    'save': 'حفظ',
    'shareAction': 'مشاركة',
    'visitShop': 'زيارة الصالون',
    'getDirections': 'الاتجاهات',
    'writeAComment': 'اكتب تعليقًا…',
    'nearby': 'بالقرب منك',
    'newHaircuts': 'قصّات جديدة',
    'discoverBahrain': 'اكتشف البحرين',
    'discoverPremiumSpots': 'أماكن وتجارب فاخرة',
    'specialOffers': 'عروض خاصة',
    'bookNow': 'احجز الآن',
    'yourBarber': 'حلاقك',
    'nextAvailable': 'أقرب موعد',
    'nextAppointment': 'موعدك القادم',
    'bookAgain': 'احجز مرة أخرى',
    'setAsMyBarber': 'اجعله حلاقك',
    'removeMyBarber': 'إزالة الحلاق',
    'makeMyBarberTitle': 'اجعله حلاقك',
    'makeMyBarberSubtitle': 'احجز بسرعة واحصل على عروض خاصة.',
    'notNow': 'ليس الآن',
    'manage': 'إدارة',
    'usuallyRespondsIn': 'عادةً يرد خلال',
    'fastResponder': 'رد سريع',
    'peopleViewedToday': 'شاهدوا هذا اليوم',
    'freshCutReminder': 'حان وقت قصة جديدة؟',
    'moreTimes': 'مواعيد أكثر',
    'today': 'اليوم',
    'tomorrow': 'غدًا',
    'noAvailabilityThisWeek': 'لا توجد مواعيد هذا الأسبوع',
    'requestATime': 'اطلب وقتًا',
    'follow': 'متابعة',
    'following': 'متابع',
    'savedBarbers': 'الحلاقون المحفوظون',
    'savedBarbersStat': 'الحلاقون المحفوظون',
    'savedShops': 'الصالونات المحفوظة',
    'haircutHistory': 'سجل القصّات',
    'paymentMethods': 'طرق الدفع',
    'premiumCustomer': 'عميل بريميوم',
    'editProfile': 'تعديل الملف',
    'member': 'عضو',
    'memberSince': 'عضو منذ {date}',
    'loyaltyPoints': 'نقاط الولاء',
    'pointsHistory': 'سجل النقاط',
    'redeemPoints': 'استبدال',
    'earned': 'مكتسبة',
    'spent': 'مستخدمة',
    'noPointsYetTitle': 'لا توجد نقاط بعد',
    'noPointsYetSubtitle': 'أكمل الحجوزات لبدء جمع نقاط الولاء.',
    'genericError': 'تعذر التحميل. يرجى المحاولة مرة أخرى.',
    'profileZeroStatsCta': 'ابدأ باستكشاف الحلاقين واحجز أول قصة',
    'services': 'الخدمات',
    'reviews': 'التقييمات',
    'portfolio': 'الأعمال',
    'videos': 'الفيديوهات',
    'workingHours': 'ساعات العمل',
    'settings': 'الإعدادات',
    'helpSupport': 'المساعدة والدعم',
    'language': 'اللغة',
    'systemLanguage': 'النظام',
    'englishLanguage': 'English',
    'arabicLanguage': 'العربية',
    'theme': 'المظهر',
    'darkMode': 'داكن',
    'lightMode': 'فاتح',
    'systemMode': 'النظام',
    'logout': 'تسجيل الخروج',
    'roleCustomer': 'عميل',
    'roleBarber': 'حلاق',
    'roleShopOwner': 'مالك صالون',
    'roleAdmin': 'مشرف',
    'availableNow': 'متاح الآن',
    'queue': 'الطابور',
    'waitingTime': 'وقت الانتظار',
    'minutes': 'د',
    'myBookings': 'حجوزاتي',
    'upcoming': 'القادمة',
    'past': 'السابقة',
    'cancel': 'إلغاء',
    'reschedule': 'إعادة جدولة',
    'confirmBooking': 'تأكيد الحجز',
    'selectBarber': 'اختر الحلاق',
    'selectService': 'اختر الخدمة',
    'selectDate': 'اختر التاريخ',
    'selectTime': 'اختر الوقت',
    'bookingChange': 'تغيير',
    'bookingAnyBarber': 'أي حلاق',
    'bookingSelected': 'محدد',
    'bookingChoose': 'اختر',
    'bookingAnyBarberSelectedHint': 'تم اختيار أي حلاق.',
    'bookingChooseBarberToSeeDates': 'اختر حلاقًا لعرض المواعيد المتاحة.',
    'bookingBarberSelectedHint': 'تم اختيار الحلاق.',
    'bookingNoAvailabilityThisMonth': 'لا توجد مواعيد هذا الشهر',
    'bookingNextAvailableDay': 'أقرب يوم متاح',
    'bookingSearching': 'جارٍ البحث…',
    'bookingSelectedDate': 'التاريخ المحدد',
    'bookingChooseDateToContinue': 'اختر تاريخًا للمتابعة',
    'bookingReservedTimeExpired': 'انتهت صلاحية حجز الوقت. اختر الوقت مرة أخرى.',
    'bookingStatusPast': 'ماضٍ',
    'bookingStatusAvailable': 'متاح',
    'bookingStatusFull': 'محجوز بالكامل',
    'bookingStatusLoading': 'جارٍ تحميل المواعيد…',
    'bookingPastDateSnack': 'تاريخ ماضٍ. اختر يومًا آخر.',
    'bookingFullyBookedSnack': 'محجوز بالكامل. اختر يومًا آخر.',
    'bookingLoadingAvailabilitySnack': 'جارٍ تحميل المواعيد…',
    'bookingAnyBarberSubtitle': 'سنقوم بتعيين حلاق متاح عند التأكيد.',
    'bookingAnyBarberSubtitle2': 'سنختار حلاقًا متاحًا للوقت الذي تختاره.',
    'bookingNoBarbersAvailable': 'لا يوجد حلاقون متاحون.',
    'bookingSelectServiceToSeeAvailability': 'اختر خدمة لعرض المواعيد المتاحة.',
    'bookingSelectShopToSeeAvailability': 'اختر صالونًا لعرض المواعيد المتاحة.',
    'bookingSelectBarberToSeeAvailability': 'اختر حلاقًا لعرض المواعيد المتاحة.',
    'bookingNoAvailabilityFoundUpcomingMonths': 'لم يتم العثور على مواعيد في الأشهر القادمة.',
    'bookingNoBarberAvailableTime': 'لا يوجد حلاق متاح في هذا الوقت. اختر وقتًا آخر.',
    'bookingTimeNoLongerAvailable': 'هذا الوقت لم يعد متاحًا. اختر وقتًا آخر.',
    'done': 'تم',
    'requiredField': 'مطلوب',
    'acceptTermsMessage': 'يرجى الموافقة على الشروط والأحكام',
    'invalidEmail': 'أدخل بريدًا صحيحًا',
    'invalidPhone': 'أدخل رقم هاتف صحيح',
    'passwordTooShort': 'كلمة المرور 8 أحرف على الأقل',
    'passwordsDontMatch': 'كلمتا المرور غير متطابقتين',
    'errorGeneric': 'تعذر التحميل',
    'retry': 'إعادة المحاولة',
    'welcomeBack': 'أهلًا بعودتك',
    'currentAreaLabel': 'المنطقة الحالية',
    'homeHeroTitle': 'أفضل حلاقين البحرين',
    'homeHeroSubtitle': 'احجز قصّتك القادمة خلال ثوانٍ.',
    'featuredBarbers': 'حلاقون مميزون',
    'quickCategories': 'فئات سريعة',
    'categoryFade': 'فيد',
    'categoryBeard': 'لحية',
    'categoryKids': 'أطفال',
    'categoryColor': 'صبغة شعر',
    'categoryVip': 'VIP',
    'categoryAvailableNow': 'متاح الآن',
    'premiumMembership': 'حلّاق بريميوم',
    'comingSoon': 'قريبًا',
    'premiumBenefitPriority': 'أولوية الحجز',
    'premiumBenefitDiscounts': 'خصومات حصرية',
    'premiumBenefitVip': 'عروض VIP',
    'seasonalRamadan': 'عروض رمضان',
    'seasonalEid': 'عروض العيد',
    'seasonalGraduation': 'قصّات التخرج',
    'seasonalWedding': 'باقات الزفاف',
    'trendingSearches': 'عمليات بحث رائجة',
    'typeToSearch': 'ابدأ بالكتابة للبحث',
    'noResults': 'لا توجد نتائج',
    'searchBarbers': 'حلاقون',
    'searchShops': 'صالونات',
    'badgeVerified': 'موثّق',
    'badgeElite': 'نخبة',
    'badgeTrending': 'رائج',
    'badgeCertified': 'حلّاق معتمد',
    'badgeTopRated': 'الأعلى تقييمًا',
    'followers': 'المتابعون',
    'bookingsCount': 'الحجوزات',
    'awards': 'جوائز حلّاق',
    'monthlyRankings': 'الترتيب الشهري',
    'awardBestBarber': 'أفضل حلاق في البحرين',
    'awardBestFade': 'أفضل متخصص في الفيد',
    'awardMostBooked': 'الأكثر حجزًا',
    'awardRisingStar': 'نجم صاعد',
    'awardBestShop': 'أفضل صالون',
    'aboutHallaq': 'عن حلّاق',
    'builtInBahrain': 'صُنع في البحرين',
    'supportingLocalBarbers': 'ندعم الحلاقين المحليين',
    'secureBookingExperience': 'تجربة حجز آمنة',
    'verifiedProfessionals': 'محترفون موثّقون',
    'modernDiscoveryPlatform': 'منصة حديثة لاكتشاف الحلاقين',
    'bahrain': 'البحرين',
    'seasonal': 'موسمي',
    'viewAll': 'عرض الكل',
    'open': 'مفتوح',
    'closed': 'مغلق',
    'bio': 'نبذة',
    'experience': 'الخبرة',
    'worksAt': 'يعمل في',
    'write': 'اكتب',
    'professional': 'محترف',
    'years10Plus': 'أكثر من 10 سنوات',
    'bioFallback': 'حلاق فاخر في البحرين. احجز بثقة.',
    'recentSearches': 'عمليات البحث الأخيرة',
    'clear': 'مسح',
    'duration': 'المدة',
    'total': 'الإجمالي',
    'bookingCreatedTitle': 'تم تأكيد الحجز',
    'bookingCreatedSubtitle': 'نراك قريبًا.',
    'share': 'مشاركة',
    'qrCode': 'رمز QR',
    'errorOfflineTitle': 'غير متصل',
    'errorOfflineDescription': 'أنت غير متصل بالإنترنت. يرجى إعادة الاتصال والمحاولة مرة أخرى.',
    'errorConnection': 'خطأ في الاتصال. يرجى المحاولة مرة أخرى.',
    'errorPermissionDenied': 'تم رفض الإذن.',
    'errorSessionExpired': 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
    'errorStorageBucketMissing': 'حاوية التخزين غير موجودة.',
    'errorInvalidGoogleMapsLink': 'رابط خرائط Google غير صالح.',
    'errorMissingRequiredField': 'حقل مطلوب مفقود.',
    'errorInvalidImageType': 'نوع الصورة غير صالح.',
    'errorFileTooLarge': 'الملف كبير جدًا.',
    'errorUploadFailed': 'فشل الرفع.',
    'errorSaveFailed': 'فشل الحفظ.',
    'errorDetailsAction': 'التفاصيل',
    'errorDetailsTitle': 'تفاصيل الخطأ',
    'copy': 'نسخ',
    'close': 'إغلاق',
    'errorAvailabilityTitle': 'لا يمكن تحميل المواعيد المتاحة',
    'errorAvailabilityGeneric': 'لا يمكن تحميل المواعيد المتاحة الآن. حاول مرة أخرى.',
    'errorAvailabilityTimeout': 'الخادم يستغرق وقتًا طويلاً للرد. حاول مرة أخرى.',
    'errorAvailabilityMissingRpc': 'خدمة المواعيد غير مهيأة على الخادم. يرجى تطبيق تحديثات Supabase ثم المحاولة مرة أخرى.',
    'errorAvailabilityPermission': 'لا تملك صلاحية تحميل المواعيد. يرجى تسجيل الدخول مرة أخرى أو تعديل صلاحيات Supabase.',
  };

  Map<String, String> get _strings => locale.languageCode == 'ar' ? _ar : _en;

  String _t(String key) => _strings[key] ?? _en[key] ?? key;

  String get appName => _t('appName');
  String get cityTitle => _t('cityTitle');
  String get citySubtitle => _t('citySubtitle');
  String get quickActionsTitle => _t('quickActionsTitle');
  String get nearbyBarbers => _t('nearbyBarbers');
  String get nearbyShops => _t('nearbyShops');
  String get trendingToday => _t('trendingToday');
  String get offersNearYou => _t('offersNearYou');
  String get popularStyles => _t('popularStyles');
  String get cityStatistics => _t('cityStatistics');
  String get bookBarber => _t('bookBarber');
  String get findShops => _t('findShops');
  String get discoverReels => _t('discoverReels');
  String get offers => _t('offers');
  String get barbersLabel => _t('barbersLabel');
  String get shopsLabel => _t('shopsLabel');
  String get changeArea => _t('changeArea');
  String get autoDetected => _t('autoDetected');
  String nextTime(String time) => _t('nextTime').replaceAll('{time}', time);
  String get now => _t('now');
  String discountOff(String discount) => _t('discountOff').replaceAll('{discount}', discount);
  String get specialOffer => _t('specialOffer');
  String get premiumDealNearYou => _t('premiumDealNearYou');
  String get trendingReel => _t('trendingReel');
  String bookingsToday(String count) => _t('bookingsToday').replaceAll('{count}', count);
  String viewsToday(String count) => _t('viewsToday').replaceAll('{count}', count);
  String likesToday(String count) => _t('likesToday').replaceAll('{count}', count);
  String get mostBookedBarber => _t('mostBookedBarber');
  String get mostBookedShop => _t('mostBookedShop');
  String get mostWatchedReel => _t('mostWatchedReel');
  String get mostLikedStyle => _t('mostLikedStyle');
  String get activeBarbersStat => _t('activeBarbersStat');
  String get barberShopsStat => _t('barberShopsStat');
  String get monthlyBookingsStat => _t('monthlyBookingsStat');
  String get averageRatingStat => _t('averageRatingStat');
  String get noBarbersNearbyTitle => _t('noBarbersNearbyTitle');
  String get noBarbersNearbyDescription => _t('noBarbersNearbyDescription');
  String get noShopsNearbyTitle => _t('noShopsNearbyTitle');
  String get noShopsNearbyDescription => _t('noShopsNearbyDescription');
  String get noOffersRightNowTitle => _t('noOffersRightNowTitle');
  String get noOffersRightNowDescription => _t('noOffersRightNowDescription');
  String get noStylesYetTitle => _t('noStylesYetTitle');
  String get noStylesYetDescription => _t('noStylesYetDescription');
  String validUntil(String date) => _t('validUntil').replaceAll('{date}', date);
  String get city => _t('city');
  String get authWelcomeTitle => _t('authWelcomeTitle');
  String get next => _t('next');
  String get getStarted => _t('getStarted');
  String get skip => _t('skip');
  String get onboardingFindBestBarbersTitle => _t('onboardingFindBestBarbersTitle');
  String get onboardingFindBestBarbersSubtitle => _t('onboardingFindBestBarbersSubtitle');
  String get onboardingTrendingHaircutsTitle => _t('onboardingTrendingHaircutsTitle');
  String get onboardingTrendingHaircutsSubtitle => _t('onboardingTrendingHaircutsSubtitle');
  String get onboardingBookInSecondsTitle => _t('onboardingBookInSecondsTitle');
  String get onboardingBookInSecondsSubtitle => _t('onboardingBookInSecondsSubtitle');
  String get onboardingGetStartedTitle => _t('onboardingGetStartedTitle');
  String get onboardingGetStartedSubtitle => _t('onboardingGetStartedSubtitle');
  String get demoMode => _t('demoMode');
  String get demoModeSubtitle => _t('demoModeSubtitle');
  String get somethingWentWrongTitle => _t('somethingWentWrongTitle');
  String get somethingWentWrongDescription => _t('somethingWentWrongDescription');
  String get tryAgain => _t('tryAgain');
  String get noBookingsTitle => _t('noBookingsTitle');
  String get noBookingsDescription => _t('noBookingsDescription');
  String get noNotificationsTitle => _t('noNotificationsTitle');
  String get noNotificationsDescription => _t('noNotificationsDescription');
  String get exploreNow => _t('exploreNow');
  String get noReviewsTitle => _t('noReviewsTitle');
  String get noReviewsDescription => _t('noReviewsDescription');
  String get noAvailabilityTitle => _t('noAvailabilityTitle');
  String get noAvailabilityDescription => _t('noAvailabilityDescription');
  String get noServicesDescription => _t('noServicesDescription');
  String get noPortfolioDescription => _t('noPortfolioDescription');
  String get all => _t('all');
  String get select => _t('select');
  String get popular => _t('popular');
  String get verified => _t('verified');
  String get reply => _t('reply');
  String get signIn => _t('signIn');
  String get signUp => _t('signUp');
  String get fullName => _t('fullName');
  String get email => _t('email');
  String get phoneNumber => _t('phoneNumber');
  String get changePhoto => _t('changePhoto');
  String get changeCover => _t('changeCover');
  String get removePhoto => _t('removePhoto');
  String get guestBrowsingTitle => _t('guestBrowsingTitle');
  String get guestBrowsingSubtitle => _t('guestBrowsingSubtitle');
  String get password => _t('password');
  String get confirmPassword => _t('confirmPassword');
  String get forgotPassword => _t('forgotPassword');
  String get emailSent => _t('emailSent');
  String get resetPassword => _t('resetPassword');
  String get newPassword => _t('newPassword');
  String get updatePassword => _t('updatePassword');
  String get continueText => _t('continueText');
  String get orContinueWith => _t('orContinueWith');
  String get google => _t('google');
  String get apple => _t('apple');
  String get chooseRoleTitle => _t('chooseRoleTitle');
  String get chooseRoleSubtitle => _t('chooseRoleSubtitle');
  String get chooseRoleCustomerSubtitle => _t('chooseRoleCustomerSubtitle');
  String get chooseRoleBarberSubtitle => _t('chooseRoleBarberSubtitle');
  String get chooseRoleShopOwnerSubtitle => _t('chooseRoleShopOwnerSubtitle');
  String get home => _t('home');
  String get explore => _t('explore');
  String get bookings => _t('bookings');
  String get upcomingBookings => _t('upcomingBookings');
  String get completedBookings => _t('completedBookings');
  String get notifications => _t('notifications');
  String get profile => _t('profile');
  String get search => _t('search');
  String get searchHint => _t('searchHint');
  String get trendingBarbers => _t('trendingBarbers');
  String get featuredShops => _t('featuredShops');
  String get worksAt => _t('worksAt');
  String get viewShop => _t('viewShop');
  String get independent => _t('independent');
  String get team => _t('team');
  String get gallery => _t('gallery');
  String get about => _t('about');
  String get bookWithTeam => _t('bookWithTeam');
  String get chooseSpecificBarber => _t('chooseSpecificBarber');
  String get anyAvailableBarber => _t('anyAvailableBarber');
  String get viewProfile => _t('viewProfile');
  String get ourStory => _t('ourStory');
  String get contact => _t('contact');
  String get openingHoursTitle => _t('openingHoursTitle');
  String get addressTitle => _t('addressTitle');
  String get call => _t('call');
  String get whatsapp => _t('whatsapp');
  String get instagram => _t('instagram');
  String get like => _t('like');
  String get comment => _t('comment');
  String get save => _t('save');
  String get shareAction => _t('shareAction');
  String get visitShop => _t('visitShop');
  String get getDirections => _t('getDirections');
  String get writeAComment => _t('writeAComment');
  String get nearby => _t('nearby');
  String get newHaircuts => _t('newHaircuts');
  String get discoverBahrain => _t('discoverBahrain');
  String get discoverPremiumSpots => _t('discoverPremiumSpots');
  String get specialOffers => _t('specialOffers');
  String get bookNow => _t('bookNow');
  String get yourBarber => _t('yourBarber');
  String get nextAvailable => _t('nextAvailable');
  String get nextAppointment => _t('nextAppointment');
  String get bookAgain => _t('bookAgain');
  String get setAsMyBarber => _t('setAsMyBarber');
  String get removeMyBarber => _t('removeMyBarber');
  String get makeMyBarberTitle => _t('makeMyBarberTitle');
  String get makeMyBarberSubtitle => _t('makeMyBarberSubtitle');
  String get notNow => _t('notNow');
  String get manage => _t('manage');
  String get usuallyRespondsIn => _t('usuallyRespondsIn');
  String get fastResponder => _t('fastResponder');
  String get peopleViewedToday => _t('peopleViewedToday');
  String get freshCutReminder => _t('freshCutReminder');
  String get moreTimes => _t('moreTimes');
  String get today => _t('today');
  String get tomorrow => _t('tomorrow');
  String get noAvailabilityThisWeek => _t('noAvailabilityThisWeek');
  String get requestATime => _t('requestATime');
  String get follow => _t('follow');
  String get following => _t('following');
  String get savedBarbers => _t('savedBarbers');
  String get savedBarbersStat => _t('savedBarbersStat');
  String get savedShops => _t('savedShops');
  String get haircutHistory => _t('haircutHistory');
  String get paymentMethods => _t('paymentMethods');
  String get premiumCustomer => _t('premiumCustomer');
  String get editProfile => _t('editProfile');
  String get member => _t('member');
  String memberSince(String date) => _t('memberSince').replaceAll('{date}', date);
  String get loyaltyPoints => _t('loyaltyPoints');
  String get pointsHistory => _t('pointsHistory');
  String get redeemPoints => _t('redeemPoints');
  String get comingSoon => _t('comingSoon');
  String get earned => _t('earned');
  String get spent => _t('spent');
  String get noPointsYetTitle => _t('noPointsYetTitle');
  String get noPointsYetSubtitle => _t('noPointsYetSubtitle');
  String get genericError => _t('genericError');
  String get errorOfflineTitle => _t('errorOfflineTitle');
  String get errorOfflineDescription => _t('errorOfflineDescription');
  String get errorConnection => _t('errorConnection');
  String get errorPermissionDenied => _t('errorPermissionDenied');
  String get errorSessionExpired => _t('errorSessionExpired');
  String get errorStorageBucketMissing => _t('errorStorageBucketMissing');
  String get errorInvalidGoogleMapsLink => _t('errorInvalidGoogleMapsLink');
  String get errorMissingRequiredField => _t('errorMissingRequiredField');
  String get errorInvalidImageType => _t('errorInvalidImageType');
  String get errorFileTooLarge => _t('errorFileTooLarge');
  String get errorUploadFailed => _t('errorUploadFailed');
  String get errorSaveFailed => _t('errorSaveFailed');
  String get errorDetailsAction => _t('errorDetailsAction');
  String get errorDetailsTitle => _t('errorDetailsTitle');
  String get copy => _t('copy');
  String get close => _t('close');
  String get errorAvailabilityTitle => _t('errorAvailabilityTitle');
  String get errorAvailabilityGeneric => _t('errorAvailabilityGeneric');
  String get errorAvailabilityTimeout => _t('errorAvailabilityTimeout');
  String get errorAvailabilityMissingRpc => _t('errorAvailabilityMissingRpc');
  String get errorAvailabilityPermission => _t('errorAvailabilityPermission');
  String get profileZeroStatsCta => _t('profileZeroStatsCta');
  String get services => _t('services');
  String get reviews => _t('reviews');
  String get portfolio => _t('portfolio');
  String get videos => _t('videos');
  String get workingHours => _t('workingHours');
  String get settings => _t('settings');
  String get helpSupport => _t('helpSupport');
  String get language => _t('language');
  String get systemLanguage => _t('systemLanguage');
  String get englishLanguage => _t('englishLanguage');
  String get arabicLanguage => _t('arabicLanguage');
  String get theme => _t('theme');
  String get darkMode => _t('darkMode');
  String get lightMode => _t('lightMode');
  String get systemMode => _t('systemMode');
  String get logout => _t('logout');
  String get roleCustomer => _t('roleCustomer');
  String get roleBarber => _t('roleBarber');
  String get roleShopOwner => _t('roleShopOwner');
  String get roleAdmin => _t('roleAdmin');
  String get availableNow => _t('availableNow');
  String get queue => _t('queue');
  String get waitingTime => _t('waitingTime');
  String get minutes => _t('minutes');
  String get myBookings => _t('myBookings');
  String get upcoming => _t('upcoming');
  String get past => _t('past');
  String get cancel => _t('cancel');
  String get reschedule => _t('reschedule');
  String get confirmBooking => _t('confirmBooking');
  String get selectBarber => _t('selectBarber');
  String get selectService => _t('selectService');
  String get selectDate => _t('selectDate');
  String get selectTime => _t('selectTime');
  String get bookingChange => _t('bookingChange');
  String get bookingAnyBarber => _t('bookingAnyBarber');
  String get bookingSelected => _t('bookingSelected');
  String get bookingChoose => _t('bookingChoose');
  String get bookingAnyBarberSelectedHint => _t('bookingAnyBarberSelectedHint');
  String get bookingChooseBarberToSeeDates => _t('bookingChooseBarberToSeeDates');
  String get bookingBarberSelectedHint => _t('bookingBarberSelectedHint');
  String get bookingNoAvailabilityThisMonth => _t('bookingNoAvailabilityThisMonth');
  String get bookingNextAvailableDay => _t('bookingNextAvailableDay');
  String get bookingSearching => _t('bookingSearching');
  String get bookingSelectedDate => _t('bookingSelectedDate');
  String get bookingChooseDateToContinue => _t('bookingChooseDateToContinue');
  String get bookingReservedTimeExpired => _t('bookingReservedTimeExpired');
  String get bookingStatusPast => _t('bookingStatusPast');
  String get bookingStatusAvailable => _t('bookingStatusAvailable');
  String get bookingStatusFull => _t('bookingStatusFull');
  String get bookingStatusLoading => _t('bookingStatusLoading');
  String get bookingPastDateSnack => _t('bookingPastDateSnack');
  String get bookingFullyBookedSnack => _t('bookingFullyBookedSnack');
  String get bookingLoadingAvailabilitySnack => _t('bookingLoadingAvailabilitySnack');
  String get bookingAnyBarberSubtitle => _t('bookingAnyBarberSubtitle');
  String get bookingAnyBarberSubtitle2 => _t('bookingAnyBarberSubtitle2');
  String get bookingNoBarbersAvailable => _t('bookingNoBarbersAvailable');
  String get bookingSelectServiceToSeeAvailability => _t('bookingSelectServiceToSeeAvailability');
  String get bookingSelectShopToSeeAvailability => _t('bookingSelectShopToSeeAvailability');
  String get bookingSelectBarberToSeeAvailability => _t('bookingSelectBarberToSeeAvailability');
  String get bookingNoAvailabilityFoundUpcomingMonths => _t('bookingNoAvailabilityFoundUpcomingMonths');
  String get bookingNoBarberAvailableTime => _t('bookingNoBarberAvailableTime');
  String get bookingTimeNoLongerAvailable => _t('bookingTimeNoLongerAvailable');
  String get done => _t('done');
  String get requiredField => _t('requiredField');
  String get acceptTermsMessage => _t('acceptTermsMessage');
  String get invalidEmail => _t('invalidEmail');
  String get invalidPhone => _t('invalidPhone');
  String get passwordTooShort => _t('passwordTooShort');
  String get passwordsDontMatch => _t('passwordsDontMatch');
  String get errorGeneric => _t('errorGeneric');
  String get retry => _t('retry');
  String get welcomeBack => _t('welcomeBack');
  String get currentAreaLabel => _t('currentAreaLabel');
  String get homeHeroTitle => _t('homeHeroTitle');
  String get homeHeroSubtitle => _t('homeHeroSubtitle');
  String get featuredBarbers => _t('featuredBarbers');
  String get quickCategories => _t('quickCategories');
  String get categoryFade => _t('categoryFade');
  String get categoryBeard => _t('categoryBeard');
  String get categoryKids => _t('categoryKids');
  String get categoryColor => _t('categoryColor');
  String get categoryVip => _t('categoryVip');
  String get categoryAvailableNow => _t('categoryAvailableNow');
  String get premiumMembership => _t('premiumMembership');
  String get premiumBenefitPriority => _t('premiumBenefitPriority');
  String get premiumBenefitDiscounts => _t('premiumBenefitDiscounts');
  String get premiumBenefitVip => _t('premiumBenefitVip');
  String get seasonalRamadan => _t('seasonalRamadan');
  String get seasonalEid => _t('seasonalEid');
  String get seasonalGraduation => _t('seasonalGraduation');
  String get seasonalWedding => _t('seasonalWedding');
  String get trendingSearches => _t('trendingSearches');
  String get typeToSearch => _t('typeToSearch');
  String get noResults => _t('noResults');
  String get searchBarbers => _t('searchBarbers');
  String get searchShops => _t('searchShops');
  String get badgeVerified => _t('badgeVerified');
  String get badgeElite => _t('badgeElite');
  String get badgeTrending => _t('badgeTrending');
  String get badgeCertified => _t('badgeCertified');
  String get badgeTopRated => _t('badgeTopRated');
  String get followers => _t('followers');
  String get bookingsCount => _t('bookingsCount');
  String get awards => _t('awards');
  String get monthlyRankings => _t('monthlyRankings');
  String get awardBestBarber => _t('awardBestBarber');
  String get awardBestFade => _t('awardBestFade');
  String get awardMostBooked => _t('awardMostBooked');
  String get awardRisingStar => _t('awardRisingStar');
  String get awardBestShop => _t('awardBestShop');
  String get aboutHallaq => _t('aboutHallaq');
  String get builtInBahrain => _t('builtInBahrain');
  String get supportingLocalBarbers => _t('supportingLocalBarbers');
  String get secureBookingExperience => _t('secureBookingExperience');
  String get verifiedProfessionals => _t('verifiedProfessionals');
  String get modernDiscoveryPlatform => _t('modernDiscoveryPlatform');
  String get bahrain => _t('bahrain');
  String get seasonal => _t('seasonal');
  String get viewAll => _t('viewAll');
  String get premiumBadge => _t('premiumBadge');
  String get currentLocationLabel => _t('currentLocationLabel');
  String get enableLocationTitle => _t('enableLocationTitle');
  String get enableLocationDescription => _t('enableLocationDescription');
  String get allowLocation => _t('allowLocation');
  String get homeSearchPlaceholder => _t('homeSearchPlaceholder');
  String get categoriesTitle => _t('categoriesTitle');
  String get nearbyShopsTitle => _t('nearbyShopsTitle');
  String get topBarbersNearYouTitle => _t('topBarbersNearYouTitle');
  String get noNearbyShopsTitle => _t('noNearbyShopsTitle');
  String get noNearbyShopsDescription => _t('noNearbyShopsDescription');
  String get noNearbyBarbersTitle => _t('noNearbyBarbersTitle');
  String get noNearbyBarbersDescription => _t('noNearbyBarbersDescription');
  String get open => _t('open');
  String get closed => _t('closed');
  String get bio => _t('bio');
  String get experience => _t('experience');
  String get write => _t('write');
  String get professional => _t('professional');
  String get years10Plus => _t('years10Plus');
  String get bioFallback => _t('bioFallback');
  String get recentSearches => _t('recentSearches');
  String get clear => _t('clear');
  String get duration => _t('duration');
  String get total => _t('total');
  String get bookingCreatedTitle => _t('bookingCreatedTitle');
  String get bookingCreatedSubtitle => _t('bookingCreatedSubtitle');
  String get share => _t('share');
  String get qrCode => _t('qrCode');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

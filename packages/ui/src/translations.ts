export type Locale = "ar" | "en";

const messages = {
  ar: {
    customer: {
      nav: {
        home: "الرئيسية",
        discover: "استكشف",
        city: "مدينة حلّاق",
        bookings: "الحجوزات",
        profile: "الملف الشخصي"
      },
      city: {
        title: "مدينة حلّاق",
        subtitle: "اكتشف مشهد الحلاقة في البحرين",
        searchPlaceholder: "ابحث عن حلاقين، صالونات، ستايلات، عروض"
      }
    },
    home: {
      title: "حلّاق",
      subtitle: "اكتشف أفضل الحلاقين في البحرين واحجز موعدك بسهولة.",
      demoCardTitle: "تجربة فاخرة",
      demoCardBody: "هذا مشروع Next.js جديد مبني على Supabase وتصميم أسود وذهبي."
    },
    shop: {
      title: "لوحة المتجر",
      subtitle: "إدارة المواعيد والخدمات والطاقم.",
      demoCardTitle: "جاهز للانطلاق",
      demoCardBody: "سجّل الدخول للبدء أو قدّم طلب ترقية الدور."
    },
    admin: {
      title: "لوحة الإدارة",
      subtitle: "إدارة المنصة والمستخدمين والمحتوى.",
      demoCardTitle: "تحكم كامل",
      demoCardBody: "سجّل الدخول بحساب إداري للوصول.",
      nav: {
        dashboard: "لوحة التحكم",
        users: "المستخدمون",
        stores: "المتاجر",
        barbers: "الحلاقون",
        appointments: "المواعيد",
        postsReels: "المنشورات والريلز",
        reviews: "المراجعات",
        verification: "التوثيق",
        awards: "الجوائز",
        advertisements: "الإعلانات",
        analytics: "التحليلات",
        reports: "التقارير",
        settings: "الإعدادات",
        logout: "تسجيل الخروج"
      },
      common: {
        search: "بحث",
        create: "إنشاء",
        live: "مباشر",
        upload: "رفع",
        approve: "موافقة",
        reject: "رفض",
        feature: "تمييز",
        unfeature: "إلغاء التمييز",
        sponsor: "تمويل",
        unsponsor: "إلغاء التمويل",
        verify: "توثيق",
        unverify: "إلغاء التوثيق",
        save: "حفظ",
        refresh: "تحديث",
        status: "الحالة",
        pending: "قيد المراجعة",
        approved: "معتمد",
        rejected: "مرفوض"
      },
      dashboard: {
        title: "لوحة التحكم",
        subtitle: "نظرة فاخرة على صحة المنصة والنمو والموافقات.",
        kpis: {
          totalUsers: "إجمالي المستخدمين",
          totalStores: "إجمالي المتاجر",
          totalBarbers: "إجمالي الحلاقين",
          totalBookings: "إجمالي الحجوزات",
          totalRevenue: "إجمالي الإيرادات",
          totalPosts: "إجمالي المنشورات",
          totalReels: "إجمالي الريلز",
          pendingApprovals: "موافقات معلّقة"
        }
      },
      reels: {
        title: "المنشورات والريلز",
        subtitle: "مراجعة الرفع، إدارة الموافقات، وتتبع التفاعل.",
        uploadTitle: "رفع ريل",
        uploadSubtitle: "رفع فيديو أو صورة مع معاينة فورية.",
        detailTitle: "تفاصيل الريل",
        moderation: "مراجعة المحتوى"
      },
      reports: {
        title: "التقارير",
        subtitle: "تصدير بيانات المنصة للعمليات والمالية.",
        exportCsv: "تصدير CSV"
      },
      settings: {
        title: "الإعدادات",
        subtitle: "حساب الإدارة وإعدادات المنصة."
      }
    },
    auth: {
      signIn: "تسجيل الدخول",
      signUp: "إنشاء حساب",
      email: "البريد الإلكتروني",
      password: "كلمة المرور",
      fullName: "الاسم الكامل",
      forgotPassword: "نسيت كلمة المرور",
      resetPassword: "إعادة تعيين كلمة المرور",
      sendResetLink: "إرسال رابط التعيين",
      backToSignIn: "العودة لتسجيل الدخول",
      setNewPassword: "تعيين كلمة مرور جديدة",
      updatePassword: "تحديث كلمة المرور",
      resetLinkSent: "تم إرسال الرابط. تحقق من بريدك الإلكتروني."
    }
  },
  en: {
    customer: {
      nav: {
        home: "Home",
        discover: "Discover",
        city: "Hallaq City",
        bookings: "Bookings",
        profile: "Profile"
      },
      city: {
        title: "HALLAQ CITY",
        subtitle: "Discover Bahrain’s Grooming Scene",
        searchPlaceholder: "Search barbers, shops, styles, offers"
      }
    },
    home: {
      title: "Hallaq",
      subtitle: "Discover Bahrain’s best barbers and book instantly.",
      demoCardTitle: "Luxury baseline",
      demoCardBody: "A new Next.js foundation powered by Supabase and black & gold UI."
    },
    shop: {
      title: "Shop Dashboard",
      subtitle: "Manage appointments, services, and staff.",
      demoCardTitle: "Ready to launch",
      demoCardBody: "Sign in to start or request a role upgrade."
    },
    admin: {
      title: "Admin Dashboard",
      subtitle: "Manage the platform, users, and content.",
      demoCardTitle: "Full control",
      demoCardBody: "Sign in with an admin account to access.",
      nav: {
        dashboard: "Dashboard",
        users: "Users",
        stores: "Stores",
        barbers: "Barbers",
        appointments: "Appointments",
        postsReels: "Posts & Reels",
        reviews: "Reviews",
        verification: "Verification",
        awards: "Awards",
        advertisements: "Advertisements",
        analytics: "Analytics",
        reports: "Reports",
        settings: "Settings",
        logout: "Logout"
      },
      common: {
        search: "Search",
        create: "Create",
        live: "Live",
        upload: "Upload",
        approve: "Approve",
        reject: "Reject",
        feature: "Feature",
        unfeature: "Unfeature",
        sponsor: "Sponsor",
        unsponsor: "Unsponsor",
        verify: "Verify",
        unverify: "Unverify",
        save: "Save",
        refresh: "Refresh",
        status: "Status",
        pending: "Pending",
        approved: "Approved",
        rejected: "Rejected"
      },
      dashboard: {
        title: "Dashboard",
        subtitle: "Premium overview of platform health, growth, and approvals.",
        kpis: {
          totalUsers: "Total Users",
          totalStores: "Total Stores",
          totalBarbers: "Total Barbers",
          totalBookings: "Total Bookings",
          totalRevenue: "Total Revenue",
          totalPosts: "Total Posts",
          totalReels: "Total Reels",
          pendingApprovals: "Pending Approvals"
        }
      },
      reels: {
        title: "Posts & Reels",
        subtitle: "Review uploads, manage approvals, and track engagement.",
        uploadTitle: "Upload Reel",
        uploadSubtitle: "Upload video or image with instant preview.",
        detailTitle: "Reel Details",
        moderation: "Content moderation"
      },
      reports: {
        title: "Reports",
        subtitle: "Export platform data for finance and ops.",
        exportCsv: "Export CSV"
      },
      settings: {
        title: "Settings",
        subtitle: "Admin account and platform settings."
      }
    },
    auth: {
      signIn: "Sign in",
      signUp: "Create account",
      email: "Email",
      password: "Password",
      fullName: "Full name",
      forgotPassword: "Forgot password",
      resetPassword: "Reset password",
      sendResetLink: "Send reset link",
      backToSignIn: "Back to sign in",
      setNewPassword: "Set new password",
      updatePassword: "Update password",
      resetLinkSent: "Reset link sent. Check your email."
    }
  }
} satisfies Record<Locale, Record<string, any>>;

function getByKeyPath(obj: any, keyPath: string) {
  return keyPath.split(".").reduce((acc, key) => (acc ? acc[key] : undefined), obj);
}

export function t(keyPath: string, locale: Locale): string {
  const value = getByKeyPath(messages[locale], keyPath);
  return typeof value === "string" ? value : keyPath;
}

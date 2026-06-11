import type { LucideIcon } from "lucide-react";

import {
  BarChart3,
  Bell,
  CalendarDays,
  ClipboardList,
  LifeBuoy,
  LayoutDashboard,
  LogOut,
  MessageCircle,
  Package,
  QrCode,
  Scissors,
  Settings,
  Star,
  Tag,
  Users,
  Video
} from "lucide-react";

export type BusinessNavItem = {
  key: string;
  label: string;
  href: string;
  icon: LucideIcon;
};

export const businessNav: BusinessNavItem[] = [
  { key: "dashboard", label: "Dashboard", href: "/business/dashboard", icon: LayoutDashboard },
  { key: "bookings", label: "Bookings", href: "/business/bookings", icon: ClipboardList },
  { key: "calendar", label: "Calendar", href: "/business/calendar", icon: CalendarDays },
  { key: "barbers", label: "Barbers", href: "/business/barbers", icon: Scissors },
  { key: "services", label: "Services", href: "/business/services", icon: Tag },
  { key: "products", label: "Products", href: "/business/products", icon: Package },
  { key: "offers", label: "Offers", href: "/business/offers", icon: Tag },
  { key: "reels", label: "Reels", href: "/business/reels", icon: Video },
  { key: "customers", label: "Customers", href: "/business/customers", icon: Users },
  { key: "reviews", label: "Reviews", href: "/business/reviews", icon: Star },
  { key: "messages", label: "Messages", href: "/business/messages", icon: MessageCircle },
  { key: "notifications", label: "Notifications", href: "/business/notifications", icon: Bell },
  { key: "reports", label: "Reports", href: "/business/reports", icon: BarChart3 },
  { key: "analytics", label: "Analytics", href: "/business/analytics", icon: BarChart3 },
  { key: "qr", label: "QR Center", href: "/business/qr", icon: QrCode },
  { key: "settings", label: "Settings", href: "/business/settings", icon: Settings },
  { key: "support", label: "Support", href: "/business/support", icon: LifeBuoy },
  { key: "logout", label: "Logout", href: "/auth/sign-out", icon: LogOut }
];

export type DemoKpis = {
  users: number;
  stores: number;
  barbers: number;
  bookings: number;
  revenueBhd: number;
  posts: number;
  reels: number;
  pendingApprovals: number;
};

export type DemoSeriesPoint = { label: string; value: number };

export type DemoDashboard = {
  kpis: DemoKpis;
  dailyBookings: DemoSeriesPoint[];
  monthlyGrowth: DemoSeriesPoint[];
  revenueGrowth: DemoSeriesPoint[];
  userGrowth: DemoSeriesPoint[];
  storeGrowth: DemoSeriesPoint[];
  recentActivity: Array<{
    id: string;
    type: string;
    title: string;
    subtitle: string;
    at: string;
  }>;
};

function mulberry32(seed: number) {
  return function () {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function pick<T>(rand: () => number, list: T[]) {
  return list[Math.floor(rand() * list.length)];
}

function clampInt(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, Math.round(value)));
}

const bahrainAreas = [
  "Manama",
  "Seef",
  "Juffair",
  "Adliya",
  "Saar",
  "Riffa",
  "Isa Town",
  "Muharraq",
  "Hamad Town",
  "Budaiya",
  "Sanabis",
  "Amwaj Islands"
];

const storeNames = [
  "Gold Fade Studio",
  "Black Velvet Barbers",
  "Seef Gentlemen Club",
  "Manama Signature Cuts",
  "The Royal Clippers",
  "Hallaq Elite Lounge",
  "Urban Gold Barbers",
  "Noble Beard Co.",
  "The Fade Atelier",
  "Midnight Grooming"
];

const barberNames = [
  "Ahmed",
  "Mohamed",
  "Ali",
  "Hassan",
  "Yousef",
  "Omar",
  "Khalid",
  "Salman",
  "Faisal",
  "Nasser",
  "Mahdi",
  "Saeed"
];

export function generateBahrainDemoDashboard(seed = 55): DemoDashboard {
  const rand = mulberry32(seed);

  const kpis: DemoKpis = {
    stores: 20,
    barbers: 50,
    users: 500,
    bookings: 1000,
    posts: 120,
    reels: 80,
    revenueBhd: 24850,
    pendingApprovals: 17
  };

  const dailyBookings: DemoSeriesPoint[] = Array.from({ length: 14 }).map((_, i) => {
    const base = 44 + i * 1.4;
    const noise = (rand() - 0.5) * 18;
    return { label: `D${i + 1}`, value: clampInt(base + noise, 18, 110) };
  });

  const monthlyGrowth: DemoSeriesPoint[] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"].map(
    (m, i) => {
      const base = 6 + i * 2.2;
      const noise = (rand() - 0.5) * 2;
      return { label: m, value: clampInt(base + noise, 2, 24) };
    }
  );

  const revenueGrowth: DemoSeriesPoint[] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"].map(
    (m, i) => {
      const base = 2600 + i * 540;
      const noise = (rand() - 0.5) * 620;
      return { label: m, value: clampInt(base + noise, 1200, 6900) };
    }
  );

  const userGrowth: DemoSeriesPoint[] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"].map((m, i) => {
    const base = 58 + i * 12;
    const noise = (rand() - 0.5) * 22;
    return { label: m, value: clampInt(base + noise, 28, 160) };
  });

  const storeGrowth: DemoSeriesPoint[] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"].map((m, i) => {
    const base = 2 + i * 0.8;
    const noise = (rand() - 0.5) * 1.2;
    return { label: m, value: clampInt(base + noise, 0, 8) };
  });

  const activityTypes = [
    "Store Registered",
    "New Barber Added",
    "New Reel Uploaded",
    "New Booking",
    "Verification Request"
  ];

  const recentActivity = Array.from({ length: 9 }).map((_, i) => {
    const type = pick(rand, activityTypes);
    const area = pick(rand, bahrainAreas);
    const store = pick(rand, storeNames);
    const barber = pick(rand, barberNames);
    const minutesAgo = clampInt(6 + rand() * 580 + i * 7, 2, 720);

    const title =
      type === "Store Registered"
        ? `${store} (${area})`
        : type === "New Barber Added"
          ? `${barber} joined ${store}`
          : type === "New Reel Uploaded"
            ? `${barber} posted a new reel`
            : type === "New Booking"
              ? `Booking confirmed • ${area}`
              : `${store} requested verification`;

    const subtitle =
      type === "New Booking"
        ? "Fade + Beard • 12.5 BHD"
        : type === "New Reel Uploaded"
          ? "Engagement spike in last hour"
          : type === "Verification Request"
            ? "Pending admin approval"
            : "Premium listing candidate";

    return {
      id: `demo-${seed}-${i}`,
      type,
      title,
      subtitle,
      at: `${minutesAgo}m ago`
    };
  });

  return { kpis, dailyBookings, monthlyGrowth, revenueGrowth, userGrowth, storeGrowth, recentActivity };
}


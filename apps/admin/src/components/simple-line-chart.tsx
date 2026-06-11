import { cn } from "@hallaq/ui/cn";

export type ChartPoint = { label: string; value: number };

function normalize(values: number[]) {
  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min || 1;
  return values.map((v) => (v - min) / range);
}

function makePath(points: Array<{ x: number; y: number }>) {
  if (!points.length) return "";
  return points.map((p, i) => `${i === 0 ? "M" : "L"} ${p.x} ${p.y}`).join(" ");
}

export function SimpleLineChart({
  id,
  title,
  subtitle,
  points,
  height = 120,
  className
}: {
  id: string;
  title: string;
  subtitle?: string;
  points: ChartPoint[];
  height?: number;
  className?: string;
}) {
  const values = points.map((p) => p.value);
  const normalized = normalize(values);

  const w = 540;
  const h = height;
  const padX = 18;
  const padY = 14;

  const coords = normalized.map((v, i) => {
    const x = padX + (i * (w - padX * 2)) / Math.max(1, normalized.length - 1);
    const y = padY + (1 - v) * (h - padY * 2);
    return { x, y };
  });

  const line = makePath(coords);
  const area = `${line} L ${coords[coords.length - 1]?.x ?? padX} ${h - padY} L ${
    coords[0]?.x ?? padX
  } ${h - padY} Z`;

  return (
    <div className={cn("flex flex-col gap-4", className)}>
      <div className="flex items-end justify-between gap-4">
        <div className="flex flex-col gap-1">
          <div className="text-sm font-semibold tracking-tight">{title}</div>
          {subtitle ? <div className="text-xs text-muted-foreground">{subtitle}</div> : null}
        </div>
        <div className="flex items-center gap-1 text-xs text-muted-foreground">
          <span className="h-1.5 w-1.5 rounded-full bg-primary shadow-glow" />
          <span>{points.at(-1)?.value ?? 0}</span>
        </div>
      </div>

      <svg viewBox={`0 0 ${w} ${h}`} className="w-full">
        <defs>
          <linearGradient id={`${id}-area`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="hsl(var(--gold) / 0.28)" />
            <stop offset="1" stopColor="hsl(var(--gold) / 0)" />
          </linearGradient>
        </defs>

        <path d={area} fill={`url(#${id}-area)`} />
        <path d={line} fill="none" stroke="hsl(var(--gold))" strokeWidth="3" strokeLinecap="round" />
        {coords.map((p, idx) => (
          <circle
            key={idx}
            cx={p.x}
            cy={p.y}
            r="3.2"
            fill="hsl(var(--gold))"
            opacity={idx === coords.length - 1 ? 1 : 0.55}
          />
        ))}
      </svg>

      <div className="grid grid-cols-6 gap-2 text-[11px] text-muted-foreground">
        {points.slice(-6).map((p) => (
          <div key={p.label} className="truncate">
            {p.label}
          </div>
        ))}
      </div>
    </div>
  );
}

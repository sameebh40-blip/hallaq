"use client";

import { useMemo, useState, useTransition } from "react";

import { Button } from "@hallaq/ui/button";
import { Input } from "@hallaq/ui/input";

type ShopRow = {
  id: string;
  name: string | null;
  area: string | null;
  status: string | null;
  is_active: boolean | null;
};

type BarberRow = {
  id: string;
  display_name: string | null;
  shop_id: string | null;
  is_independent: boolean | null;
  status: string | null;
  is_active: boolean | null;
};

export function ShopBarberMapClient(props: {
  shops: ShopRow[];
  barbers: BarberRow[];
  assignBarber: (formData: FormData) => Promise<void>;
  removeBarber: (formData: FormData) => Promise<void>;
  setIndependent: (formData: FormData) => Promise<void>;
}) {
  const shops = props.shops ?? [];
  const barbers = props.barbers ?? [];
  const [selectedShopId, setSelectedShopId] = useState<string>(() => shops[0]?.id ?? "");
  const [shopQuery, setShopQuery] = useState("");
  const [barberQuery, setBarberQuery] = useState("");
  const [showUnassignedOnly, setShowUnassignedOnly] = useState(true);
  const [isPending, startTransition] = useTransition();

  const shopCounts = useMemo(() => {
    const m = new Map<string, number>();
    for (const b of barbers) {
      if (!b.shop_id) continue;
      m.set(b.shop_id, (m.get(b.shop_id) ?? 0) + 1);
    }
    return m;
  }, [barbers]);

  const filteredShops = useMemo(() => {
    const q = shopQuery.trim().toLowerCase();
    if (!q) return shops;
    return shops.filter((s) => `${s.name ?? ""} ${s.area ?? ""}`.toLowerCase().includes(q));
  }, [shops, shopQuery]);

  const selectedShop = useMemo(() => shops.find((s) => s.id === selectedShopId) ?? null, [shops, selectedShopId]);

  const shopBarbers = useMemo(() => {
    if (!selectedShopId) return [];
    return barbers.filter((b) => b.shop_id === selectedShopId);
  }, [barbers, selectedShopId]);

  const filteredBarbers = useMemo(() => {
    const q = barberQuery.trim().toLowerCase();
    const list = showUnassignedOnly ? barbers.filter((b) => !b.shop_id) : barbers;
    if (!q) return list;
    return list.filter((b) => `${b.display_name ?? ""}`.toLowerCase().includes(q));
  }, [barbers, barberQuery, showUnassignedOnly]);

  const disabled = isPending;

  return (
    <div className="grid gap-4 lg:grid-cols-12">
      <div className="rounded-xl border border-border bg-card p-4 lg:col-span-4">
        <div className="text-sm font-semibold">Shops</div>
        <div className="pt-3">
          <Input value={shopQuery} onChange={(e) => setShopQuery(e.target.value)} placeholder="Search shops..." />
        </div>
        <div className="pt-3 grid gap-2 max-h-[520px] overflow-auto">
          {filteredShops.map((s) => {
            const active = s.id === selectedShopId;
            const count = shopCounts.get(s.id) ?? 0;
            return (
              <button
                key={s.id}
                type="button"
                onClick={() => setSelectedShopId(s.id)}
                className={[
                  "w-full rounded-lg border px-3 py-2 text-left text-sm transition-colors",
                  active ? "border-white/30 bg-white/5" : "border-border bg-transparent hover:bg-white/5"
                ].join(" ")}
              >
                <div className="font-semibold">{(s.name ?? "Shop").trim() || "Shop"}</div>
                <div className="pt-0.5 text-xs text-muted-foreground">
                  {(s.area ?? "").trim() ? `${s.area} • ` : ""}
                  {count} staff
                </div>
              </button>
            );
          })}
          {!filteredShops.length ? <div className="text-sm text-muted-foreground">No shops found.</div> : null}
        </div>
      </div>

      <div className="rounded-xl border border-border bg-card p-4 lg:col-span-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-sm font-semibold">Assigned barbers</div>
            <div className="pt-0.5 text-xs text-muted-foreground">{selectedShop ? (selectedShop.name ?? "Shop") : "Select a shop"}</div>
          </div>
          <div className="text-xs text-muted-foreground">{shopBarbers.length} total</div>
        </div>

        <div className="pt-3 grid gap-2 max-h-[520px] overflow-auto">
          {shopBarbers.map((b) => (
            <div key={b.id} className="rounded-lg border border-border bg-transparent p-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold">{(b.display_name ?? "Barber").trim() || "Barber"}</div>
                  <div className="pt-0.5 text-xs text-muted-foreground">
                    {(b.status ?? "").trim() || "unknown"} • {(b.is_active ?? true) ? "active" : "inactive"}
                  </div>
                </div>
                <form
                  action={(fd) => startTransition(() => props.removeBarber(fd))}
                  className="flex items-center gap-2"
                >
                  <input type="hidden" name="barber_id" value={b.id} />
                  <Button type="submit" size="sm" variant="secondary" disabled={disabled}>
                    Remove
                  </Button>
                </form>
              </div>

              <div className="pt-3">
                <form action={(fd) => startTransition(() => props.setIndependent(fd))}>
                  <input type="hidden" name="barber_id" value={b.id} />
                  <input type="hidden" name="is_independent" value="1" />
                  <Button type="submit" size="sm" variant="ghost" disabled={disabled}>
                    Mark independent
                  </Button>
                </form>
              </div>
            </div>
          ))}
          {!selectedShopId ? <div className="text-sm text-muted-foreground">Select a shop to see its barbers.</div> : null}
          {selectedShopId && shopBarbers.length === 0 ? <div className="text-sm text-muted-foreground">No barbers assigned.</div> : null}
        </div>
      </div>

      <div className="rounded-xl border border-border bg-card p-4 lg:col-span-4">
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-sm font-semibold">All barbers</div>
            <div className="pt-0.5 text-xs text-muted-foreground">Assign barbers to the selected shop.</div>
          </div>
          <label className="flex items-center gap-2 text-xs text-muted-foreground">
            <input
              type="checkbox"
              checked={showUnassignedOnly}
              onChange={(e) => setShowUnassignedOnly(e.target.checked)}
            />
            Unassigned only
          </label>
        </div>

        <div className="pt-3">
          <Input value={barberQuery} onChange={(e) => setBarberQuery(e.target.value)} placeholder="Search barbers..." />
        </div>

        <div className="pt-3 grid gap-2 max-h-[520px] overflow-auto">
          {filteredBarbers.map((b) => {
            const canAssign = Boolean(selectedShopId) && (!b.shop_id || b.shop_id !== selectedShopId);
            return (
              <div key={b.id} className="rounded-lg border border-border bg-transparent p-3">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-sm font-semibold">{(b.display_name ?? "Barber").trim() || "Barber"}</div>
                    <div className="pt-0.5 text-xs text-muted-foreground">
                      {(b.status ?? "").trim() || "unknown"} • {(b.is_active ?? true) ? "active" : "inactive"}{" "}
                      {b.shop_id ? "• assigned" : "• unassigned"}
                    </div>
                  </div>
                  <form action={(fd) => startTransition(() => props.assignBarber(fd))}>
                    <input type="hidden" name="barber_id" value={b.id} />
                    <input type="hidden" name="shop_id" value={selectedShopId} />
                    <Button type="submit" size="sm" disabled={disabled || !canAssign}>
                      Assign
                    </Button>
                  </form>
                </div>
              </div>
            );
          })}
          {!filteredBarbers.length ? <div className="text-sm text-muted-foreground">No barbers found.</div> : null}
        </div>
      </div>
    </div>
  );
}


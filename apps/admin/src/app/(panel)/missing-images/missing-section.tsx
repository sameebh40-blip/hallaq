"use client";

import Link from "next/link";
import { useMemo, useState } from "react";

import { Button } from "@hallaq/ui/button";
import { cn } from "@hallaq/ui/cn";
import { LuxuryCard } from "@hallaq/ui/luxury-card";

type Item = {
  id: string;
  title: string;
  subtitle?: string | null;
  href: string;
};

export function MissingSection({
  title,
  sectionId,
  entityType,
  field,
  items,
  applyOne,
  applyBulkSelected,
  applyBulkMissing
}: {
  title: string;
  sectionId: string;
  entityType: string;
  field: string;
  items: Item[];
  applyOne: (formData: FormData) => void;
  applyBulkSelected: (formData: FormData) => void;
  applyBulkMissing: (formData: FormData) => void;
}) {
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const allIds = useMemo(() => items.map((i) => i.id), [items]);
  const allSelected = selected.size > 0 && selected.size === items.length;

  function toggleAll() {
    setSelected((prev) => {
      if (items.length === 0) return prev;
      if (prev.size === items.length) return new Set();
      return new Set(allIds);
    });
  }

  function toggleOne(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  return (
    <LuxuryCard className="border border-white/10 bg-white/5 p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex flex-col gap-1">
          <div className="text-sm font-semibold">{title}</div>
          <div className="text-xs text-muted-foreground">{items.length} missing</div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Button type="button" variant="secondary" onClick={toggleAll} disabled={!items.length}>
            {allSelected ? "Unselect All" : "Select All"}
          </Button>

          <form
            action={applyBulkSelected}
            className={cn(!selected.size ? "pointer-events-none opacity-60" : "")}
            onSubmit={() => setSelected(new Set())}
          >
            <input type="hidden" name="entity_type" value={entityType} />
            <input type="hidden" name="field" value={field} />
            {Array.from(selected).map((id) => (
              <input key={id} type="hidden" name="entity_ids" value={id} />
            ))}
            <Button type="submit" disabled={!selected.size}>
              Bulk Apply Default
            </Button>
          </form>

          <form action={applyBulkMissing} onSubmit={() => setSelected(new Set())}>
            <input type="hidden" name="section_id" value={sectionId} />
            <Button type="submit" variant="ghost" disabled={!items.length}>
              Bulk Apply Missing
            </Button>
          </form>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-2">
        {items.map((item) => {
          const isChecked = selected.has(item.id);
          return (
            <div key={item.id} className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-white/10 bg-black/10 p-3">
              <label className="flex min-w-[260px] flex-1 cursor-pointer items-center gap-3">
                <input type="checkbox" checked={isChecked} onChange={() => toggleOne(item.id)} className="h-4 w-4 accent-[hsl(var(--gold))]" />
                <div className="flex flex-col">
                  <div className="text-xs font-semibold">{item.title}</div>
                  {item.subtitle ? <div className="text-[11px] text-muted-foreground">{item.subtitle}</div> : null}
                </div>
              </label>

              <div className="flex items-center gap-2">
                <Button asChild type="button" variant="ghost">
                  <Link href={item.href}>Open Record</Link>
                </Button>
                <form action={applyOne}>
                  <input type="hidden" name="entity_type" value={entityType} />
                  <input type="hidden" name="entity_id" value={item.id} />
                  <input type="hidden" name="field" value={field} />
                  <Button type="submit" variant="secondary">
                    Apply Default
                  </Button>
                </form>
              </div>
            </div>
          );
        })}
      </div>
    </LuxuryCard>
  );
}

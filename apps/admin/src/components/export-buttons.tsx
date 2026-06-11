"use client";

import { useMemo } from "react";

import { Button } from "@hallaq/ui/button";

function download(filename: string, content: string, mime: string) {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function ExportButtons({
  filenameBase,
  rows
}: {
  filenameBase: string;
  rows: Array<Record<string, string | number | null | undefined>>;
}) {
  const csv = useMemo(() => {
    const headers = Array.from(
      rows.reduce((acc, r) => {
        Object.keys(r).forEach((k) => acc.add(k));
        return acc;
      }, new Set<string>())
    );

    const esc = (v: unknown) => {
      const s = String(v ?? "");
      return `"${s.replaceAll('"', '""')}"`;
    };

    return [headers.join(","), ...rows.map((r) => headers.map((h) => esc(r[h])).join(","))].join("\n");
  }, [rows]);

  return (
    <div className="flex flex-wrap items-center gap-2">
      <Button
        type="button"
        variant="secondary"
        size="sm"
        onClick={() => download(`${filenameBase}.csv`, csv, "text/csv;charset=utf-8")}
      >
        Export CSV
      </Button>
    </div>
  );
}

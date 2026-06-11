import { LuxuryCard } from "@hallaq/ui/luxury-card";

export default function Loading() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-4xl flex-col justify-center gap-4 px-4 py-12">
      <LuxuryCard className="p-6">
        <div className="flex animate-pulse flex-col gap-4">
          <div className="h-6 w-44 rounded bg-white/10" />
          <div className="h-4 w-64 rounded bg-white/10" />
          <div className="grid grid-cols-1 gap-3 pt-2 md:grid-cols-2">
            <div className="h-28 rounded-lg bg-white/10" />
            <div className="h-28 rounded-lg bg-white/10" />
          </div>
        </div>
      </LuxuryCard>
    </main>
  );
}

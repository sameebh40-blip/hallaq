export default function Loading() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-5xl flex-col justify-center px-6 py-12">
      <div className="animate-pulse space-y-4">
        <div className="h-7 w-52 rounded bg-black/10" />
        <div className="h-4 w-80 rounded bg-black/10" />
        <div className="grid grid-cols-1 gap-3 pt-2 sm:grid-cols-2 lg:grid-cols-3">
          <div className="h-40 rounded-xl bg-black/10" />
          <div className="h-40 rounded-xl bg-black/10" />
          <div className="h-40 rounded-xl bg-black/10" />
        </div>
      </div>
    </main>
  );
}

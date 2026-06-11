export default function LoadingBarberProfile() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col bg-black px-4 py-4 pb-28">
      <div className="animate-pulse">
        <div className="h-[520px] rounded-[28px] border border-white/8 bg-white/[0.04]" />
        <div className="mt-4 flex gap-2">
          {Array.from({ length: 6 }).map((_, index) => (
            <div key={index} className="h-10 flex-1 rounded-full border border-white/8 bg-white/[0.04]" />
          ))}
        </div>
        <div className="mt-4 space-y-4">
          <div className="h-44 rounded-[28px] border border-white/8 bg-white/[0.04]" />
          <div className="h-64 rounded-[28px] border border-white/8 bg-white/[0.04]" />
          <div className="h-64 rounded-[28px] border border-white/8 bg-white/[0.04]" />
        </div>
      </div>
    </main>
  );
}

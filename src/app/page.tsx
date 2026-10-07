import { Button } from "@/components/ui/button";

export default function Home() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950 px-6 py-16 text-slate-50">
      <div className="w-full max-w-4xl rounded-2xl border border-slate-800 bg-slate-900/80 p-8 shadow-2xl shadow-slate-950/30 ring-1 ring-slate-700 backdrop-blur sm:p-12">
        <div className="mb-6 inline-flex items-center rounded-full border border-cyan-500/40 bg-cyan-500/10 px-3 py-1 text-xs font-medium uppercase tracking-[0.2em] text-cyan-300">
          Active development
        </div>

        <h1 className="text-4xl font-semibold tracking-tight text-white sm:text-5xl">
          V1.0 Foundation
        </h1>

        <p className="mt-6 max-w-2xl text-lg text-slate-300">
          Continental is establishing the repository, tooling, static deployment foundation,
          and app shell required before future product features are implemented.
        </p>

        <div className="mt-8 flex flex-wrap gap-3">
          <Button variant="default">Application foundation</Button>
          <Button variant="outline">Static hosting ready</Button>
        </div>

        <div className="mt-10 grid gap-4 border-t border-slate-800 pt-6 text-sm text-slate-300 sm:grid-cols-3">
          <div>
            <p className="font-medium text-slate-200">Stack</p>
            <p className="mt-2">Next.js • React • TypeScript • Tailwind</p>
          </div>
          <div>
            <p className="font-medium text-slate-200">Backend</p>
            <p className="mt-2">Supabase • PostgreSQL • RLS</p>
          </div>
          <div>
            <p className="font-medium text-slate-200">Platform</p>
            <p className="mt-2">Static Cloudflare Pages deployment</p>
          </div>
        </div>
      </div>
    </main>
  );
}

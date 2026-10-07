"use client";

import { useContext, useEffect } from "react";
import { AppRouterContext } from "next/dist/shared/lib/app-router-context.shared-runtime";

import { LoginForm } from "@/components/auth/login-form";
import { useSafeRouter } from "@/lib/navigation/safe-router";
import { useAuth } from "@/providers/auth-provider";

export function LoginPage() {
  const router = useSafeRouter();
  const hasRouter = useContext(AppRouterContext) !== null;
  const { status } = useAuth();

  useEffect(() => {
    if (hasRouter && status === "authenticated") router.replace("/app");
  }, [hasRouter, router, status]);

  if (status === "loading" || status === "authenticated") {
    return (
      <main className="flex min-h-screen items-center justify-center bg-slate-950 px-6 text-slate-200" aria-live="polite">
        <p>{status === "loading" ? "Restoring your session…" : "Opening your workspace…"}</p>
      </main>
    );
  }

  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-slate-950 px-5 py-12 text-slate-100">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_15%_15%,rgba(14,116,144,0.18),transparent_42%),radial-gradient(ellipse_at_85%_80%,rgba(34,197,94,0.10),transparent_38%)]" />
      <section className="relative w-full max-w-md rounded-xl border border-slate-800 bg-slate-900/95 p-7 shadow-2xl shadow-black/30 sm:p-9">
        <div className="mb-8">
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300">Continental</p>
          <h1 className="mt-3 text-2xl font-semibold text-white">Sign in to your workspace</h1>
          <p className="mt-2 text-sm text-slate-400">Use the account created for you by an administrator.</p>
        </div>
        <LoginForm />
      </section>
    </main>
  );
}

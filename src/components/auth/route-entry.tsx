"use client";

import { useContext, useEffect } from "react";
import { AppRouterContext } from "next/dist/shared/lib/app-router-context.shared-runtime";

import { useSafeRouter } from "@/lib/navigation/safe-router";
import { useAuth } from "@/providers/auth-provider";

export function RouteEntry() {
  const router = useSafeRouter();
  const hasRouter = useContext(AppRouterContext) !== null;
  const { status } = useAuth();

  useEffect(() => {
    if (!hasRouter) return;
    if (status === "authenticated") router.replace("/app");
    if (status === "unauthenticated" || status === "disabled" || status === "error") {
      router.replace("/login");
    }
  }, [hasRouter, router, status]);

  if (!hasRouter) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-slate-950 px-6 text-slate-200" aria-live="polite">
        <div className="space-y-3 text-center">
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300">Continental</p>
          <h1 className="text-2xl font-semibold text-white">V1.0 foundation</h1>
        </div>
      </main>
    );
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950 px-6 text-slate-200" aria-live="polite">
      <p>{status === "loading" ? "Restoring your session…" : "Opening your workspace…"}</p>
    </main>
  );
}

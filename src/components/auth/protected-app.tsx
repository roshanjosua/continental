"use client";

import { useContext, useEffect, type ReactNode } from "react";
import Link from "next/link";
import { AppRouterContext } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { LogOut, UserRound } from "lucide-react";

import { Button } from "@/components/ui/button";
import { useSafeRouter } from "@/lib/navigation/safe-router";
import { useAuth } from "@/providers/auth-provider";

export function ProtectedApp({ children }: { children: ReactNode }) {
  const router = useSafeRouter();
  const hasRouter = useContext(AppRouterContext) !== null;
  const { status, profile, error, refreshProfile, signOut } = useAuth();

  useEffect(() => {
    if (hasRouter && (status === "unauthenticated" || status === "disabled")) {
      router.replace("/login");
    }
  }, [hasRouter, router, status]);

  if (status === "loading" || status === "unauthenticated" || status === "disabled") {
    return (
      <main className="flex min-h-screen items-center justify-center bg-slate-950 px-6 text-slate-200" aria-live="polite">
        <p>{status === "loading" ? "Restoring your session…" : "Opening sign in…"}</p>
      </main>
    );
  }

  if (status === "error" || !profile) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-slate-950 px-6 text-slate-100">
        <section className="w-full max-w-md space-y-5 rounded-xl border border-slate-800 bg-slate-900 p-7">
          <h1 className="text-xl font-semibold">We couldn’t load your account</h1>
          <p className="text-sm text-slate-300">{error ?? "Your profile is temporarily unavailable."}</p>
          <div className="flex gap-3">
            <Button onClick={() => void refreshProfile()}>Try again</Button>
            <Button variant="outline" onClick={() => void signOut()}>Sign out</Button>
          </div>
        </section>
      </main>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <header className="border-b border-slate-800 bg-slate-950/95">
        <div className="mx-auto flex min-h-16 max-w-6xl items-center justify-between gap-4 px-5">
          <Link href="/app" className="font-semibold tracking-wide text-white">Continental</Link>
          <div className="flex items-center gap-3">
            <span className="hidden text-sm text-slate-300 sm:inline">{profile.display_name}</span>
            <span className="rounded-md border border-cyan-800 bg-cyan-950/60 px-2.5 py-1 text-xs font-medium text-cyan-200">
              {profile.role === "ADMIN" ? "Administrator" : "User"}
            </span>
            <Link
              href="/app/profile"
              aria-label="Profile"
              title="Profile"
              className="inline-flex size-10 items-center justify-center rounded-md border border-slate-700 text-slate-200 hover:bg-slate-800 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan-400"
            >
              <UserRound aria-hidden="true" className="size-4" />
            </Link>
            <Button
              variant="outline"
              size="icon"
              aria-label="Sign out"
              title="Sign out"
              onClick={() => void signOut().then(() => {
                if (hasRouter) {
                  router.replace("/login");
                }
              })}
            >
              <LogOut aria-hidden="true" />
            </Button>
          </div>
        </div>
      </header>
      <main className="mx-auto w-full max-w-6xl px-5 py-10">{children}</main>
    </div>
  );
}

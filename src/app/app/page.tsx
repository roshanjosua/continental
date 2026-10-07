"use client";

import { useAuth } from "@/providers/auth-provider";

export default function AppHomePage() {
  const { profile } = useAuth();

  return (
    <section className="space-y-3">
      <p className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan-300">Private workspace</p>
      <h1 className="text-3xl font-semibold text-white">Welcome, {profile?.display_name}</h1>
      <p className="max-w-2xl text-sm leading-6 text-slate-300">
        Your account is active. The Continental application foundation is ready for the next implementation version.
      </p>
    </section>
  );
}

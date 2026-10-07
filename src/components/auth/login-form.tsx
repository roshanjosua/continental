"use client";

import { useContext, useState, type FormEvent } from "react";
import { AppRouterContext } from "next/dist/shared/lib/app-router-context.shared-runtime";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useSafeRouter } from "@/lib/navigation/safe-router";
import { isSupabaseConfigured } from "@/lib/supabase/client";
import { useAuth } from "@/providers/auth-provider";

export function LoginForm() {
  const router = useSafeRouter();
  const hasRouter = useContext(AppRouterContext) !== null;
  const { status, signIn } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    const normalizedEmail = email.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
      setError("Enter a valid email address.");
      return;
    }
    if (!password) {
      setError("Enter your password.");
      return;
    }
    if (!isSupabaseConfigured) {
      setError("Authentication is not configured. Contact the application administrator.");
      return;
    }

    setSubmitting(true);
    try {
      await signIn(normalizedEmail, password);
      setPassword("");
      if (hasRouter) {
        router.replace("/app");
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "We couldn't sign you in. Try again.");
    } finally {
      setSubmitting(false);
    }
  }

  const disabledNotice = status === "disabled";

  return (
    <form className="space-y-5" onSubmit={handleSubmit} noValidate>
      {disabledNotice && (
        <p role="alert" className="rounded-md border border-amber-700/70 bg-amber-950/50 px-3 py-2 text-sm text-amber-200">
          This account is disabled. Contact an administrator.
        </p>
      )}
      {error && (
        <p role="alert" className="rounded-md border border-rose-800 bg-rose-950/50 px-3 py-2 text-sm text-rose-200">
          {error}
        </p>
      )}
      <div className="space-y-2">
        <label htmlFor="login-email" className="text-sm font-medium text-slate-200">Email</label>
        <Input
          autoComplete="username"
          id="login-email"
          name="email"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          autoCapitalize="none"
          required
        />
      </div>
      <div className="space-y-2">
        <label htmlFor="login-password" className="text-sm font-medium text-slate-200">Password</label>
        <Input
          autoComplete="current-password"
          id="login-password"
          name="password"
          type="password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          required
        />
      </div>
      <Button className="w-full" type="submit" disabled={submitting || !isSupabaseConfigured}>
        {submitting ? "Signing in…" : "Sign in"}
      </Button>
    </form>
  );
}

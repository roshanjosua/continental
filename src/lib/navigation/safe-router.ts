"use client";

import { useContext } from "react";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";

function createFallbackRouter(): AppRouterInstance {
  return {
    back: () => {
      if (typeof window !== "undefined") {
        window.history.back();
      }
    },
    forward: () => {
      if (typeof window !== "undefined") {
        window.history.forward();
      }
    },
    refresh: () => {
      if (typeof window !== "undefined") {
        window.location.reload();
      }
    },
    push: (href: string) => {
      if (typeof window !== "undefined") {
        window.location.assign(href);
      }
    },
    replace: (href: string) => {
      if (typeof window !== "undefined") {
        window.location.replace(href);
      }
    },
    prefetch: () => undefined,
    bfcacheId: "safe-router-fallback",
  };
}

export function useSafeRouter() {
  const appRouter = useContext(AppRouterContext);
  return appRouter ?? createFallbackRouter();
}

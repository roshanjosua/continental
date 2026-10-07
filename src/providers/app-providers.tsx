import type { ReactNode } from "react";

import { QueryProvider } from "@/providers/query-provider";

export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <QueryProvider>
      {/* Future Auth Provider */}
      {/* Future Theme Provider */}
      {children}
    </QueryProvider>
  );
}

import type { ReactNode } from "react";

import { ProtectedApp } from "@/components/auth/protected-app";

export default function Layout({ children }: Readonly<{ children: ReactNode }>) {
  return <ProtectedApp>{children}</ProtectedApp>;
}

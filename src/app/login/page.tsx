import type { Metadata } from "next";

import { LoginPage } from "@/components/auth/login-page";

export const metadata: Metadata = {
  title: "Sign in | Continental",
};

export default function Page() {
  return <LoginPage />;
}

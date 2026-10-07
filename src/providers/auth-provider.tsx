"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import type { Session, User } from "@supabase/supabase-js";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { formatAuthError } from "@/lib/auth/profile";
import { supabase } from "@/lib/supabase/client";
import type { AppProfile, EditableProfileInput } from "@/types/auth";

export type AuthStatus =
  | "loading"
  | "unauthenticated"
  | "authenticated"
  | "disabled"
  | "error";

interface AuthContextValue {
  status: AuthStatus;
  user: User | null;
  profile: AppProfile | null;
  error: string | null;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  updateProfile: (input: EditableProfileInput) => Promise<AppProfile>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);
const defaultAuthContext: AuthContextValue = {
  status: "unauthenticated",
  user: null,
  profile: null,
  error: null,
  signIn: async () => {
    throw new Error("Authentication is not available without an AuthProvider.");
  },
  signOut: async () => {
    throw new Error("Authentication is not available without an AuthProvider.");
  },
  updateProfile: async () => {
    throw new Error("Authentication is not available without an AuthProvider.");
  },
  refreshProfile: async () => undefined,
};
const profileFields =
  "id,auth_user_id,username,display_name,email,avatar_url,bio,academic_info,interests,role,is_active";

async function fetchProfile(authUserId: string): Promise<AppProfile> {
  const { data, error } = await supabase
    .from("profiles")
    .select(profileFields)
    .eq("auth_user_id", authUserId)
    .maybeSingle();

  if (error) {
    throw new Error("PROFILE_LOOKUP_FAILED");
  }
  if (!data) {
    throw new Error("PROFILE_NOT_FOUND");
  }

  return data as AppProfile;
}

function getProfileQueryKey(authUserId: string) {
  return ["auth-profile", authUserId] as const;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  const [session, setSession] = useState<Session | null>(null);
  const [sessionReady, setSessionReady] = useState(false);
  const [initializationError, setInitializationError] = useState<string | null>(null);
  const [disabledAccount, setDisabledAccount] = useState(false);
  const authEventReceived = useRef(false);
  const inactiveSessionHandled = useRef<string | null>(null);

  useEffect(() => {
    let mounted = true;
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, nextSession) => {
      authEventReceived.current = true;
      setSession(nextSession);
      setSessionReady(true);
      if (event === "SIGNED_OUT") {
        queryClient.clear();
      }
    });

    void supabase.auth
      .getSession()
      .then(({ data, error }) => {
        if (!mounted || authEventReceived.current) return;
        if (error) {
          setInitializationError(
            "Unable to restore your session. Please sign in again.",
          );
        }
        setSession(data.session);
        setSessionReady(true);
      })
      .catch(() => {
        if (!mounted || authEventReceived.current) return;
        setInitializationError(
          "Unable to restore your session. Check your connection and try again.",
        );
        setSessionReady(true);
      });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, [queryClient]);

  const profileQuery = useQuery({
    queryKey: getProfileQueryKey(session?.user.id ?? ""),
    queryFn: () => fetchProfile(session!.user.id),
    enabled: sessionReady && session !== null,
    retry: false,
    staleTime: 0,
  });

  const signOut = useCallback(async () => {
    setDisabledAccount(false);
    setInitializationError(null);
    queryClient.clear();
    const { error } = await supabase.auth.signOut({ scope: "local" });
    setSession(null);
    setSessionReady(true);
    if (error) {
      throw new Error("We couldn't complete sign out. Please try again.");
    }
  }, [queryClient]);

  useEffect(() => {
    if (
      session &&
      profileQuery.data &&
      !profileQuery.data.is_active &&
      inactiveSessionHandled.current !== session.user.id
    ) {
      inactiveSessionHandled.current = session.user.id;
      queryClient.clear();
      void supabase.auth.signOut({ scope: "local" }).then(() => {
        setSession(null);
        setDisabledAccount(true);
      });
    }
  }, [profileQuery.data, queryClient, session]);

  const signIn = useCallback(
    async (email: string, password: string) => {
      setDisabledAccount(false);
      setInitializationError(null);
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });

      if (error) {
        throw new Error(formatAuthError(error.message));
      }
      if (!data.session || !data.user) {
        throw new Error("Sign in did not return an active session. Please try again.");
      }

      setSession(data.session);
      setSessionReady(true);
      queryClient.clear();

      let profile: AppProfile;
      try {
        profile = await queryClient.fetchQuery({
          queryKey: getProfileQueryKey(data.user.id),
          queryFn: () => fetchProfile(data.user.id),
          retry: false,
          staleTime: 0,
        });
      } catch {
        await supabase.auth.signOut({ scope: "local" });
        queryClient.clear();
        setSession(null);
        throw new Error(
          "We couldn't load your application profile. Contact an administrator.",
        );
      }

      if (!profile.is_active) {
        setDisabledAccount(true);
        await supabase.auth.signOut({ scope: "local" });
        queryClient.clear();
        setSession(null);
        throw new Error("This account is disabled. Contact an administrator.");
      }
    },
    [queryClient],
  );

  const updateProfileMutation = useMutation({
    mutationFn: async (input: EditableProfileInput) => {
      if (!session?.user.id) {
        throw new Error("Sign in again to update your profile.");
      }

      const { data, error } = await supabase
        .from("profiles")
        .update(input)
        .eq("auth_user_id", session.user.id)
        .select(profileFields)
        .maybeSingle();

      if (error || !data) {
        throw new Error("We couldn't save your profile. Check your connection and try again.");
      }

      return data as AppProfile;
    },
    onSuccess: (profile) => {
      if (session?.user.id) {
        queryClient.setQueryData(getProfileQueryKey(session.user.id), profile);
      }
    },
  });

  const refreshProfile = useCallback(async () => {
    if (!session?.user.id) return;
    await profileQuery.refetch();
  }, [profileQuery, session?.user.id]);

  const status: AuthStatus = useMemo(() => {
    if (!sessionReady) return "loading";
    if (disabledAccount || (profileQuery.data && !profileQuery.data.is_active)) {
      return "disabled";
    }
    if (initializationError || (session && profileQuery.isError)) return "error";
    if (!session) return "unauthenticated";
    if (profileQuery.isPending || !profileQuery.data) return "loading";
    return "authenticated";
  }, [
    disabledAccount,
    initializationError,
    profileQuery.data,
    profileQuery.isError,
    profileQuery.isPending,
    session,
    sessionReady,
  ]);

  const contextValue = useMemo<AuthContextValue>(
    () => ({
      status,
      user: session?.user ?? null,
      profile: profileQuery.data ?? null,
      error:
        initializationError ??
        (profileQuery.isError
          ? "We couldn't load your profile. Check your connection or try again."
          : null),
      signIn,
      signOut,
      updateProfile: updateProfileMutation.mutateAsync,
      refreshProfile,
    }),
    [
      initializationError,
      profileQuery.data,
      profileQuery.isError,
      refreshProfile,
      session?.user,
      signIn,
      signOut,
      status,
      updateProfileMutation.mutateAsync,
    ],
  );

  return <AuthContext.Provider value={contextValue}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  return context ?? defaultAuthContext;
}

import type { AppRole } from "@/types";

export interface AppProfile {
  id: string;
  auth_user_id: string;
  username: string;
  display_name: string;
  email: string;
  avatar_url: string | null;
  bio: string | null;
  academic_info: string | null;
  interests: string | null;
  role: AppRole;
  is_active: boolean;
}

export interface EditableProfileInput {
  display_name: string;
  avatar_url: string | null;
  bio: string | null;
  academic_info: string | null;
  interests: string | null;
}

export type ProfileValidationResult =
  | { success: true; data: EditableProfileInput }
  | { success: false; errors: Partial<Record<keyof EditableProfileInput, string>> };

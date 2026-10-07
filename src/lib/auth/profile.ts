import type { EditableProfileInput, ProfileValidationResult } from "@/types/auth";

const MAX_TEXT_LENGTH = 500;

export function validateProfileInput(
  input: Record<keyof EditableProfileInput, string>,
): ProfileValidationResult {
  const displayName = input.display_name.trim();
  const bio = input.bio.trim();
  const academicInfo = input.academic_info.trim();
  const interests = input.interests.trim();
  const avatarInput = input.avatar_url.trim();
  const errors: Partial<Record<keyof EditableProfileInput, string>> = {};

  if (displayName.length < 2 || displayName.length > 80) {
    errors.display_name = "Display name must be between 2 and 80 characters.";
  }
  if (bio.length > MAX_TEXT_LENGTH) {
    errors.bio = "Bio must be 500 characters or fewer.";
  }
  if (academicInfo.length > MAX_TEXT_LENGTH) {
    errors.academic_info = "Academic information must be 500 characters or fewer.";
  }
  if (interests.length > MAX_TEXT_LENGTH) {
    errors.interests = "Interests must be 500 characters or fewer.";
  }

  let avatarUrl: string | null = null;
  if (avatarInput) {
    try {
      const parsedUrl = new URL(avatarInput);
      if (parsedUrl.protocol !== "https:" || parsedUrl.username || parsedUrl.password) {
        errors.avatar_url = "Avatar URL must be a valid HTTPS URL.";
      } else {
        avatarUrl = parsedUrl.toString();
      }
    } catch {
      errors.avatar_url = "Avatar URL must be a valid HTTPS URL.";
    }
  }

  if (Object.keys(errors).length > 0) {
    return { success: false, errors };
  }

  return {
    success: true,
    data: {
      display_name: displayName,
      avatar_url: avatarUrl,
      bio: bio || null,
      academic_info: academicInfo || null,
      interests: interests || null,
    },
  };
}

export function formatAuthError(message: string): string {
  const normalized = message.toLowerCase();

  if (normalized.includes("invalid login credentials")) {
    return "Email or password is incorrect.";
  }
  if (normalized.includes("network") || normalized.includes("fetch")) {
    return "Unable to reach the authentication service. Check your connection and try again.";
  }
  if (normalized.includes("too many requests")) {
    return "Too many sign-in attempts. Please wait a moment and try again.";
  }

  return "We couldn't sign you in. Check your details and try again.";
}

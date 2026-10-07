import { describe, expect, it } from "vitest";

import { formatAuthError, validateProfileInput } from "@/lib/auth/profile";

describe("profile input validation", () => {
  it("trims accepted values and converts empty optional fields to null", () => {
    const result = validateProfileInput({
      display_name: "  Ada Lovelace  ",
      avatar_url: "https://images.example.test/ada.png",
      bio: "  Mathematician  ",
      academic_info: "  Applied mathematics  ",
      interests: "   ",
    });

    expect(result).toEqual({
      success: true,
      data: {
        display_name: "Ada Lovelace",
        avatar_url: "https://images.example.test/ada.png",
        bio: "Mathematician",
        academic_info: "Applied mathematics",
        interests: null,
      },
    });
  });

  it("requires a reasonable display name", () => {
    const result = validateProfileInput({
      display_name: " ",
      avatar_url: "",
      bio: "",
      academic_info: "",
      interests: "",
    });

    expect(result.success).toBe(false);
    if (!result.success) expect(result.errors.display_name).toMatch(/2 and 80/);
  });

  it.each(["http://images.example.test/a.png", "javascript:alert(1)", "data:image/png;base64,abc", "not a URL"]) (
    "rejects unsafe or malformed avatar URL %s",
    (avatarUrl) => {
      const result = validateProfileInput({
        display_name: "Ada",
        avatar_url: avatarUrl,
        bio: "",
        academic_info: "",
        interests: "",
      });

      expect(result.success).toBe(false);
      if (!result.success) expect(result.errors.avatar_url).toMatch(/HTTPS/);
    },
  );

  it("maps authentication failures to safe user-facing text", () => {
    expect(formatAuthError("Invalid login credentials")).toBe("Email or password is incorrect.");
    expect(formatAuthError("fetch failed")).toMatch(/authentication service/);
    expect(formatAuthError("database internal stack trace")).toBe(
      "We couldn't sign you in. Check your details and try again.",
    );
  });
});

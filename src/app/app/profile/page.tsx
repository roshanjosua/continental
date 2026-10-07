"use client";

import { useState, type FormEvent } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { validateProfileInput } from "@/lib/auth/profile";
import { useAuth } from "@/providers/auth-provider";
import type { EditableProfileInput } from "@/types/auth";

interface ProfileFormValues {
  display_name: string;
  avatar_url: string;
  bio: string;
  academic_info: string;
  interests: string;
}

function formValuesFromProfile(profile: NonNullable<ReturnType<typeof useAuth>["profile"]>): ProfileFormValues {
  return {
    display_name: profile.display_name,
    avatar_url: profile.avatar_url ?? "",
    bio: profile.bio ?? "",
    academic_info: profile.academic_info ?? "",
    interests: profile.interests ?? "",
  };
}

export default function ProfilePage() {
  const { profile, user, updateProfile } = useAuth();
  const [values, setValues] = useState<ProfileFormValues>(() => {
    return profile ? formValuesFromProfile(profile) : {
      display_name: "",
      avatar_url: "",
      bio: "",
      academic_info: "",
      interests: "",
    };
  });
  const [fieldErrors, setFieldErrors] = useState<Partial<Record<keyof EditableProfileInput, string>>>({});
  const [message, setMessage] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function setField(name: keyof ProfileFormValues, value: string) {
    setValues((current) => ({ ...current, [name]: value }));
    setFieldErrors((current) => ({ ...current, [name]: undefined }));
    setMessage(null);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage(null);
    const validation = validateProfileInput(values);
    if (!validation.success) {
      setFieldErrors(validation.errors);
      return;
    }

    setSaving(true);
    setFieldErrors({});
    try {
      await updateProfile(validation.data);
      setValues({
        ...validation.data,
        avatar_url: validation.data.avatar_url ?? "",
        bio: validation.data.bio ?? "",
        academic_info: validation.data.academic_info ?? "",
        interests: validation.data.interests ?? "",
      });
      setMessage("Profile saved.");
    } catch (cause) {
      setMessage(cause instanceof Error ? cause.message : "We couldn't save your profile.");
    } finally {
      setSaving(false);
    }
  }

  if (!profile) return null;

  return (
    <section className="max-w-3xl space-y-8">
      <header className="space-y-2 border-b border-slate-800 pb-6">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan-300">Account</p>
        <h1 className="text-3xl font-semibold text-white">Profile</h1>
      </header>

      <div className="grid gap-4 border-b border-slate-800 pb-7 sm:grid-cols-2">
        <div>
          <p className="text-xs text-slate-400">Username</p>
          <p className="mt-1 font-medium text-slate-100">{profile.username}</p>
        </div>
        <div>
          <p className="text-xs text-slate-400">Email</p>
          <p className="mt-1 font-medium text-slate-100">{user?.email ?? profile.email}</p>
        </div>
        <div>
          <p className="text-xs text-slate-400">Role</p>
          <p className="mt-1 font-medium text-slate-100">{profile.role === "ADMIN" ? "Administrator" : "User"}</p>
        </div>
      </div>

      <form className="space-y-6" onSubmit={handleSubmit} noValidate>
        <div className="space-y-2">
          <label htmlFor="profile-display-name" className="text-sm font-medium text-slate-200">Display name</label>
          <Input id="profile-display-name" value={values.display_name} onChange={(event) => setField("display_name", event.target.value)} maxLength={80} required aria-invalid={Boolean(fieldErrors.display_name)} />
          {fieldErrors.display_name && <p className="text-sm text-rose-300">{fieldErrors.display_name}</p>}
        </div>
        <div className="space-y-2">
          <label htmlFor="profile-avatar-url" className="text-sm font-medium text-slate-200">Avatar URL</label>
          <Input id="profile-avatar-url" type="url" inputMode="url" value={values.avatar_url} onChange={(event) => setField("avatar_url", event.target.value)} placeholder="https://…" aria-invalid={Boolean(fieldErrors.avatar_url)} />
          {fieldErrors.avatar_url && <p className="text-sm text-rose-300">{fieldErrors.avatar_url}</p>}
        </div>
        <div className="space-y-2">
          <label htmlFor="profile-bio" className="text-sm font-medium text-slate-200">Bio</label>
          <Textarea id="profile-bio" value={values.bio} onChange={(event) => setField("bio", event.target.value)} maxLength={500} />
          {fieldErrors.bio && <p className="text-sm text-rose-300">{fieldErrors.bio}</p>}
        </div>
        <div className="space-y-2">
          <label htmlFor="profile-academic-info" className="text-sm font-medium text-slate-200">Academic information</label>
          <Textarea id="profile-academic-info" value={values.academic_info} onChange={(event) => setField("academic_info", event.target.value)} maxLength={500} />
          {fieldErrors.academic_info && <p className="text-sm text-rose-300">{fieldErrors.academic_info}</p>}
        </div>
        <div className="space-y-2">
          <label htmlFor="profile-interests" className="text-sm font-medium text-slate-200">Interests</label>
          <Textarea id="profile-interests" value={values.interests} onChange={(event) => setField("interests", event.target.value)} maxLength={500} />
          {fieldErrors.interests && <p className="text-sm text-rose-300">{fieldErrors.interests}</p>}
        </div>
        <div className="flex flex-wrap items-center gap-4">
          <Button type="submit" disabled={saving}>{saving ? "Saving…" : "Save profile"}</Button>
          {message && <p role="status" className="text-sm text-slate-300">{message}</p>}
        </div>
      </form>
    </section>
  );
}

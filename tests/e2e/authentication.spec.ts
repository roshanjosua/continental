import { expect, test } from "@playwright/test";

const adminEmail = process.env.E2E_ADMIN_EMAIL ?? "";
const adminPassword = process.env.E2E_ADMIN_PASSWORD ?? "";
const userEmail = process.env.E2E_USER_EMAIL ?? "";
const userPassword = process.env.E2E_USER_PASSWORD ?? "";
const disabledEmail = process.env.E2E_DISABLED_EMAIL ?? "";
const disabledPassword = process.env.E2E_DISABLED_PASSWORD ?? "";

async function signIn(page: import("@playwright/test").Page, email: string, password: string) {
  await page.goto("/login");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(password);
  await page.getByRole("button", { name: "Sign in" }).click();
}

test("unauthenticated direct navigation shows login without protected content", async ({ page }) => {
  await page.goto("/app");

  await expect(page).toHaveURL(/\/login\/?$/);
  await expect(page.getByRole("heading", { name: /sign in to your workspace/i })).toBeVisible();
  await expect(page.getByText(/private workspace/i)).toHaveCount(0);
  await expect(page.getByRole("link", { name: /sign up/i })).toHaveCount(0);
});

test("invalid credentials show a friendly error", async ({ page }) => {
  test.skip(!adminEmail, "Run npm run test:e2e:setup to create local auth users.");
  await signIn(page, adminEmail, "wrong-local-e2e-password");

  await expect(page.locator('p[role="alert"]')).toContainText("Email or password is incorrect");
  await expect(page).toHaveURL(/\/login\/?$/);
});

test("USER can sign in, retain session, edit allowed profile fields, and sign out", async ({ page }) => {
  test.skip(!userEmail, "Run npm run test:e2e:setup to create local auth users.");
  await signIn(page, userEmail, userPassword);

  await expect(page).toHaveURL(/\/app\/?$/);
  await expect(page.getByRole("heading", { name: "Welcome, E2E user" })).toBeVisible();
  await expect(page.getByRole("banner").getByText("User", { exact: true })).toBeVisible();

  await page.reload();
  await expect(page.getByRole("heading", { name: "Welcome, E2E user" })).toBeVisible();

  await page.getByRole("link", { name: "Profile" }).click();
  await expect(page).toHaveURL(/\/app\/profile\/?$/);
  await expect(page.getByText(userEmail)).toBeVisible();
  await expect(page.getByText(/e2e-user-[a-f0-9]{8}_[a-f0-9]{8}/i)).toBeVisible();
  await expect(page.getByRole("banner").getByText("User", { exact: true })).toBeVisible();

  await page.getByLabel("Display name").fill("E2E User Updated");
  await page.getByLabel("Avatar URL").fill("javascript:alert(1)");
  await page.getByRole("button", { name: "Save profile" }).click();
  await expect(page.getByText(/valid HTTPS URL/i)).toBeVisible();

  await page.getByLabel("Avatar URL").fill("https://images.example.test/avatar.png");
  await page.getByRole("button", { name: "Save profile" }).click();
  await expect(page.getByRole("status")).toHaveText("Profile saved.");
  await expect(page.getByRole("textbox", { name: "Username" })).toHaveCount(0);
  await expect(page.getByText(userEmail)).toBeVisible();

  await page.getByRole("button", { name: "Sign out" }).click();
  await expect(page).toHaveURL(/\/login\/?$/);
  await page.goto("/app");
  await expect(page).toHaveURL(/\/login\/?$/);
  await expect(page.getByText("E2E User Updated")).toHaveCount(0);
});

test("ADMIN role is displayed without exposing admin-only modules", async ({ page }) => {
  test.skip(!adminEmail, "Run npm run test:e2e:setup to create local auth users.");
  await signIn(page, adminEmail, adminPassword);

  await expect(page).toHaveURL(/\/app\/?$/);
  await expect(page.getByText("Administrator", { exact: true })).toBeVisible();
  await expect(page.getByRole("link", { name: /admin/i })).toHaveCount(0);
});

test("disabled accounts are signed out and denied application access", async ({ page }) => {
  test.skip(!disabledEmail, "Run npm run test:e2e:setup to create local auth users.");
  await signIn(page, disabledEmail, disabledPassword);

  await expect(page).toHaveURL(/\/login\/?$/);
  await expect(page.locator('p[role="alert"]')).toContainText("This account is disabled");
  await page.goto("/app");
  await expect(page).toHaveURL(/\/login\/?$/);
});

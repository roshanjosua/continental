import { expect, test } from "@playwright/test";

test("unauthenticated homepage routes to the login screen", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveTitle(/Continental/i);
  await expect(
    page.getByRole("heading", { name: /sign in to your workspace/i }),
  ).toBeVisible();
});

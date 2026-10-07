import { expect, test } from "@playwright/test";

test("homepage loads and renders the V1.0 foundation content", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveTitle(/Continential/i);
  await expect(
    page.getByRole("heading", { name: /v1\.0 foundation/i }),
  ).toBeVisible();
});

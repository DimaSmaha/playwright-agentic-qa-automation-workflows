import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Clicking product name navigates to dedicated product details page", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test(
    "clicking product name navigates to product details page",
    { tag: ["@tc-TEST-57041"] },
    async ({ pages }) => {
      await pages.inventory.assertLoaded();
      await pages.inventory.assertProductNameLinkVisible("Sauce Labs Backpack");
      await pages.inventory.clickProductName("Sauce Labs Backpack");
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertProductName("Sauce Labs Backpack");
    },
  );
});

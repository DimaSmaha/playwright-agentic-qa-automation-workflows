import { test } from "../fixtures/pages.fixture";

test.describe("[P2] ProductDetail: Clicking product image also navigates to the product details page", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test(
    "clicking product image navigates to product details page",
    { tag: ["@tc-TEST-6729"] },
    async ({ pages }) => {
      await pages.inventory.assertLoaded();
      await pages.inventory.clickProductImageLink("Sauce Labs Backpack");
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertProductName("Sauce Labs Backpack");
    },
  );
});

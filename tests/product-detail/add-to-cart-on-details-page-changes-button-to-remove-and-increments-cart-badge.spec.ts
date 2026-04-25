import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Add to cart on details page changes button to Remove and increments cart badge", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
    await pages.inventory.clickProductName("Sauce Labs Backpack");
  });

  test(
    "add to cart changes button to Remove and shows cart badge count 1",
    { tag: ["@tc-TEST-43072"] },
    async ({ pages }) => {
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertButtonIsAddToCart();
      await pages.productDetail.clickAddToCart();
      await pages.productDetail.assertButtonIsRemove();
      await pages.productDetail.assertCartBadge("1");
    },
  );
});

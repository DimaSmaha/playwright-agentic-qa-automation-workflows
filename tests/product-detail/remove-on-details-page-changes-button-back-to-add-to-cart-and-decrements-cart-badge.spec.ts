import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Remove on details page changes button back to Add to cart and decrements cart badge", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
    await pages.inventory.clickProductName("Sauce Labs Backpack");
    await pages.productDetail.clickAddToCart();
  });

  test(
    "remove changes button back to Add to cart and hides cart badge",
    { tag: ["@tc-TEST-83366"] },
    async ({ pages }) => {
      await pages.productDetail.assertButtonIsRemove();
      await pages.productDetail.assertCartBadge("1");
      await pages.productDetail.clickRemove();
      await pages.productDetail.assertButtonIsAddToCart();
      await pages.productDetail.assertCartBadgeHidden();
    },
  );
});

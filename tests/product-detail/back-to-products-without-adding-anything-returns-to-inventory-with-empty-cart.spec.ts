import { test } from "../fixtures/pages.fixture";

test.describe("[P2] ProductDetail: Back to products without adding anything returns to inventory with empty cart", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test(
    "back to products without adding returns to inventory with empty cart",
    { tag: ["@tc-TEST-52568"] },
    async ({ pages }) => {
      await pages.inventory.assertLoaded();
      await pages.inventory.clickProductName("Sauce Labs Backpack");
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertCartBadgeHidden();
      await pages.productDetail.clickBackToProducts();
      await pages.cart.assertCartBadgeHidden();
    },
  );
});

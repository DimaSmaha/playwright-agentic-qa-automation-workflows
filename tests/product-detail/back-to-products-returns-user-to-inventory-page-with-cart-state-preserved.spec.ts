import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Back to products returns user to inventory page with cart state preserved", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
    await pages.inventory.clickProductName("Sauce Labs Backpack");
  });

  test(
    "back to products preserves cart state on inventory",
    { tag: ["@tc-TEST-11142"] },
    async ({ pages }) => {
      await pages.productDetail.assertLoaded();
      await pages.productDetail.clickAddToCart();
      await pages.productDetail.assertCartBadge("1");
      await pages.productDetail.clickBackToProducts();
      await pages.inventory.assertLoaded();
      await pages.inventory.assertCartCount("1");
      await pages.inventory.assertItemButtonIsRemove("Sauce Labs Backpack");
    },
  );
});

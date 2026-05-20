import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Cart state synchronized — item added on details page shows Remove on inventory", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test(
    "item added on details page shows Remove button on inventory",
    { tag: ["@tc-TEST-34768"] },
    async ({ pages }) => {
      await pages.inventory.assertLoaded();
      await pages.inventory.clickProductName("Sauce Labs Backpack");
      await pages.productDetail.assertLoaded();
      await pages.productDetail.clickAddToCart();
      await pages.productDetail.assertCartBadge("1");
      await pages.productDetail.clickBackToProducts();
      await pages.inventory.assertItemButtonIsRemove("Sauce Labs Backpack");
    },
  );
});

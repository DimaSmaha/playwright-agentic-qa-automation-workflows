import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Cart state synchronized — item added on inventory shows Remove on details page", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test(
    "item added on inventory shows Remove button on details page",
    { tag: ["@tc-TEST-77905"] },
    async ({ pages }) => {
      await pages.inventory.assertLoaded();
      await pages.inventory.addFirstItemToCart();
      await pages.inventory.assertCartCount("1");
      await pages.inventory.clickProductName("Sauce Labs Backpack");
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertButtonIsRemove();
    },
  );
});

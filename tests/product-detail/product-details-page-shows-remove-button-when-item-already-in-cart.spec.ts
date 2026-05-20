import { test } from "../fixtures/pages.fixture";

test.describe("[P2] ProductDetail: Product details page shows Remove button when item already in cart", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test(
    "details page shows Remove button when item was added from inventory",
    { tag: ["@tc-TEST-62585"] },
    async ({ pages }) => {
      await pages.inventory.addFirstItemToCart();
      await pages.inventory.assertCartCount("1");
      await pages.inventory.clickProductName("Sauce Labs Backpack");
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertButtonIsRemove();
    },
  );
});

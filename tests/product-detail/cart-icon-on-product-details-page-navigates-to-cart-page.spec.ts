import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Cart icon on product details page navigates to cart page", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
    await pages.inventory.clickProductName("Sauce Labs Backpack");
    await pages.productDetail.clickAddToCart();
  });

  test(
    "cart icon navigates to cart page and shows added item",
    { tag: ["@tc-TEST-79962"] },
    async ({ pages }) => {
      await pages.productDetail.assertCartBadge("1");
      await pages.productDetail.assertCartBadge("1");
      await pages.productDetail.goToCart();
      await pages.cart.assertLoaded();
    },
  );
});

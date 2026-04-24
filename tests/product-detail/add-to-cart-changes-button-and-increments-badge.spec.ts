import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Add to Cart on product details page changes button to Remove and increments cart badge", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
    await pages.page.goto("https://www.saucedemo.com/inventory-item.html?id=4");
  });

  test(
    "add to cart changes button to Remove and shows cart badge",
    { tag: ["@TEST-45085"] },
    async ({ pages }) => {
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertAddToCartVisible();
      await pages.productDetail.clickAddToCart();
      await pages.productDetail.assertRemoveVisible();
      await pages.productDetail.assertCartCount("1");
    },
  );
});

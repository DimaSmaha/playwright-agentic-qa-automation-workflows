import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Product details page displays name, description, price, and image", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test(
    "product details page displays all required elements",
    { tag: ["@TEST-67124"] },
    async ({ pages }) => {
      await pages.inventory.assertLoaded();
      await pages.inventory.clickProductName("Sauce Labs Backpack");
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertProductName("Sauce Labs Backpack");
      await pages.productDetail.assertProductDescriptionVisible();
      await pages.productDetail.assertProductPrice("$29.99");
      await pages.productDetail.assertProductImageVisible();
    },
  );
});

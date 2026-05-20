import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Product details page displays name, description, price, and product image", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test(
    "product details page shows all required product information",
    { tag: ["@tc-TEST-42669"] },
    async ({ pages }) => {
      await pages.inventory.clickProductName("Sauce Labs Backpack");
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertProductName("Sauce Labs Backpack");
      await pages.productDetail.assertDescriptionVisible();
      await pages.productDetail.assertPrice("$29.99");
      await pages.productDetail.assertImageVisible();
    },
  );
});

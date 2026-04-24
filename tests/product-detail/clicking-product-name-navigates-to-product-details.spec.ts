import { test } from "../fixtures/pages.fixture";

test.describe("[P1] ProductDetail: Clicking product name on inventory navigates to product details page", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test(
    "clicking product name link navigates to product details page",
    { tag: ["@TEST-14456"] },
    async ({ pages }) => {
      await pages.inventory.assertLoaded();
      await pages.inventory.clickFirstProductName();
      await pages.productDetail.assertLoaded();
    },
  );
});

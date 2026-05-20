import { test } from "../fixtures/pages.fixture";

test.describe("[P2] ProductDetail: Cart badge not visible on details page when cart is empty", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
    await pages.inventory.clickProductName("Sauce Labs Backpack");
  });

  test(
    "cart badge is hidden when cart is empty on details page",
    { tag: ["@tc-TEST-52168"] },
    async ({ pages }) => {
      await pages.productDetail.assertLoaded();
      await pages.productDetail.assertCartBadgeHidden();
      await pages.productDetail.assertCartBadgeHidden();
    },
  );
});

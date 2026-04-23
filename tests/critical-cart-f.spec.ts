import { test } from "./fixtures/pages.fixture";

test.describe("[FTB] critical cart flows", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("locked_out_user", "secret_sauce");
  });

  test("[FTB] critical positive: user can remove item from cart", async ({
    pages,
  }) => {
    await pages.inventory.addFirstItemToCart();
    await pages.inventory.assertCartCount("1");
    await pages.inventory.goToCart();

    await pages.cart.removeFirstItem();
    await pages.cart.assertCartBadgeHidden();
    await pages.cart.assertContinueShoppingVisible();
  });
});

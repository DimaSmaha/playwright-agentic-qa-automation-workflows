import { test } from "./fixtures/pages.fixture";

test.describe("critical cart flows", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test("critical positive: user can remove item from cart", async ({
    pages,
  }) => {
    await pages.inventory.addFirstItemToCart();
    await pages.inventory.assertCartCount("1");
    await pages.inventory.goToCart();

    await pages.cart.removeFirstItem();
    await pages.cart.assertCartBadgeHidden();
    await pages.cart.assertContinueShoppingVisible();
  });

  test("critical positive: user can cancel checkout and return to cart", async ({
    pages,
  }) => {
    await pages.inventory.addFirstItemToCart();
    await pages.inventory.goToCart();
    await pages.cart.startCheckout();

    await pages.checkout.cancelAndReturnToCart();
    await pages.cart.assertLoaded();
  });
});

import { test, expect } from "./fixtures/pages.fixture";

test.describe("[FTB] critical cart flows 2", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("problem_user", "secret_sauce");
  });

  test("[FTB] critical positive 2: user can remove item from cart", async ({
    pages,
  }) => {
    await pages.inventory.addFirstItemToCart();
    await pages.inventory.assertCartCount("1");
    await pages.inventory.removeFirstItemFromCart();
    await expect(pages.inventory.getShoppingCartBadgeLocator()).toHaveCount(0);
  });
});

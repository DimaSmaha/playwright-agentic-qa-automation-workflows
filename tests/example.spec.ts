import { test } from "./fixtures/pages.fixture";

test("user can complete checkout flow on SauceDemo", async ({ pages }) => {
  await pages.login.goto();
  await pages.login.login("standard_user", "secret_sauce");

  await pages.inventory.assertLoaded();
  await pages.inventory.addFirstItemToCart();
  await pages.inventory.assertCartCount("1");
  await pages.inventory.goToCart();

  await pages.cart.assertLoaded();
  await pages.cart.startCheckout();

  await pages.checkout.fillInformation("E2E", "Tester", "10001");
  await pages.checkout.finishOrder();
  await pages.checkout.assertOrderSuccess();

  // Keeps direct browser page access available through the same fixture.
  await pages.page.screenshot({ path: "order-success.png", fullPage: true });
});

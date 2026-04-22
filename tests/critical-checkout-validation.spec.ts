import { test } from "./fixtures/pages.fixture";

test.describe("critical checkout validation flows", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test("critical negative: checkout requires first name", async ({ pages }) => {
    await pages.inventory.addFirstItemToCart();
    await pages.inventory.goToCart();
    await pages.cart.startCheckout();

    await pages.checkout.continueWithoutFirstName("Tester", "10001");
    await pages.checkout.assertFirstNameRequiredError();
  });
});

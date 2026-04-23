import { test } from "./fixtures/pages.fixture";

test.describe("[FTT] critical inventory flows", () => {
  test.beforeEach(async ({ pages }) => {
    await pages.login.goto();
    await pages.login.login("standard_user", "secret_sauce");
  });

  test("[FTT] critical positive: user can sort products by low to high", async ({
    pages,
  }) => {
    await pages.inventory.sortByLowToHigh();
    await pages.inventory.assertFirstItemPrice("$8.99");
  });
});

import { expect, Page } from "@playwright/test";

export class InventoryPage {
  constructor(private readonly page: Page) {}

  async assertLoaded() {
    await expect(
      this.page.locator('[data-test="inventory-container"]'),
    ).toBeVisible();
  }

  async addFirstItemToCart() {
    await this.page
      .getByRole("button", { name: "Add to cart" })
      .first()
      .click();
  }

  async assertCartCount(expectedCount: string) {
    await expect(
      this.page.locator('[data-test="shopping-cart-badge"]'),
    ).toHaveText(expectedCount);
  }

  async goToCart() {
    await this.page.locator('[data-test="shopping-cart-link"]').click();
    await expect(this.page).toHaveURL(/.*cart.html/);
  }

  async sortByLowToHigh() {
    await this.page
      .locator('[data-test="product-sort-container"]')
      .selectOption("lohi");
  }

  async assertFirstItemPrice(expectedPrice: string) {
    const firstItemPrice = await this.page
      .locator('[data-test="inventory-item-price"]')
      .first()
      .innerText();
    expect(firstItemPrice.trim()).toBe(expectedPrice);
  }
}

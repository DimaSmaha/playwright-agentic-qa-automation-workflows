import { expect, Page } from "@playwright/test";

export class ProductDetailPage {
  constructor(private readonly page: Page) {}

  async assertLoaded() {
    await expect(this.page).toHaveURL(/.*inventory-item\.html/);
    await expect(
      this.page.locator('[data-test="back-to-products"]'),
    ).toBeVisible();
  }

  async assertProductName(name: string) {
    await expect(
      this.page.locator('[data-test="inventory-item-name"]'),
    ).toHaveText(name);
  }

  async assertProductDescriptionVisible() {
    await expect(
      this.page.locator('[data-test="inventory-item-desc"]'),
    ).toBeVisible();
  }

  async assertProductPrice(price: string) {
    await expect(
      this.page.locator('[data-test="inventory-item-price"]'),
    ).toHaveText(price);
  }

  async assertProductImageVisible() {
    await expect(
      this.page.locator('[data-test="item-sauce-labs-backpack-img"]').or(
        this.page.locator('.inventory_details_img'),
      ),
    ).toBeVisible();
  }

  async clickAddToCart() {
    await this.page.locator('[data-test="add-to-cart"]').click();
  }

  async clickRemove() {
    await this.page.locator('[data-test="remove"]').click();
  }

  async assertAddToCartVisible() {
    await expect(
      this.page.locator('[data-test="add-to-cart"]'),
    ).toBeVisible();
  }

  async assertRemoveVisible() {
    await expect(
      this.page.locator('[data-test="remove"]'),
    ).toBeVisible();
  }

  async clickBackToProducts() {
    await this.page.locator('[data-test="back-to-products"]').click();
    await expect(this.page).toHaveURL(/.*inventory\.html/);
  }

  async assertCartCount(expectedCount: string) {
    await expect(
      this.page.locator('[data-test="shopping-cart-badge"]'),
    ).toHaveText(expectedCount);
  }

  async assertCartBadgeHidden() {
    await expect(
      this.page.locator('[data-test="shopping-cart-badge"]'),
    ).toHaveCount(0);
  }

  async goToCart() {
    await this.page.locator('[data-test="shopping-cart-link"]').click();
    await expect(this.page).toHaveURL(/.*cart\.html/);
  }
}

import { expect, Page } from "@playwright/test";

export class ProductDetailPage {
  constructor(private readonly page: Page) {}

  async assertLoaded() {
    await expect(this.page).toHaveURL(/.*inventory-item\.html/);
    await expect(
      this.page.locator('[data-test="inventory-item-name"]'),
    ).toBeVisible();
  }

  async assertProductName(name: string) {
    await expect(
      this.page.locator('[data-test="inventory-item-name"]'),
    ).toHaveText(name);
  }

  async assertDescriptionVisible() {
    await expect(
      this.page.locator('[data-test="inventory-item-desc"]'),
    ).toBeVisible();
  }

  async assertPrice(price: string) {
    await expect(
      this.page.locator('[data-test="inventory-item-price"]'),
    ).toHaveText(price);
  }

  async assertImageVisible() {
    await expect(
      this.page.locator('[data-test$="-img"]'),
    ).toBeVisible();
  }

  async clickAddToCart() {
    await this.page.locator('[data-test="add-to-cart"]').click();
  }

  async clickRemove() {
    await this.page.getByRole("button", { name: "Remove" }).click();
  }

  async assertButtonIsRemove() {
    await expect(
      this.page.getByRole("button", { name: "Remove" }),
    ).toBeVisible();
  }

  async assertButtonIsAddToCart() {
    await expect(
      this.page.locator('[data-test="add-to-cart"]'),
    ).toBeVisible();
  }

  async assertCartBadge(count: string) {
    await expect(
      this.page.locator('[data-test="shopping-cart-badge"]'),
    ).toHaveText(count);
  }

  async assertCartBadgeHidden() {
    await expect(
      this.page.locator('[data-test="shopping-cart-badge"]'),
    ).toHaveCount(0);
  }

  async clickBackToProducts() {
    await this.page.locator('[data-test="back-to-products"]').click();
    await expect(this.page).toHaveURL(/.*inventory\.html/);
  }

  async goToCart() {
    await this.page.locator('[data-test="shopping-cart-link"]').click();
    await expect(this.page).toHaveURL(/.*cart\.html/);
  }

  async gotoDirectUrl(id: number) {
    await this.page.goto(`https://www.saucedemo.com/inventory-item.html?id=${id}`);
  }
}

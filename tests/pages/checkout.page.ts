import { expect, Page } from "@playwright/test";

export class CheckoutPage {
  constructor(private readonly page: Page) {}

  async fillInformation(
    firstName: string,
    lastName: string,
    postalCode: string,
  ) {
    await this.page.getByPlaceholder("First Name").fill(firstName);
    await this.page.getByPlaceholder("Last Name").fill(lastName);
    await this.page.getByPlaceholder("Zip/Postal Code").fill(postalCode);
    await this.page.getByRole("button", { name: "Continue" }).click();
    await expect(this.page).toHaveURL(/.*checkout-step-two.html/);
  }

  async finishOrder() {
    await this.page.getByRole("button", { name: "Finish" }).click();
    await expect(this.page).toHaveURL(/.*checkout-complete.html/);
  }

  async assertOrderSuccess() {
    await expect(
      this.page.getByRole("heading", { name: "Thank you for your order!" }),
    ).toBeVisible();
  }

  async cancelAndReturnToCart() {
    await this.page.getByRole("button", { name: "Cancel" }).click();
    await expect(this.page).toHaveURL(/.*cart.html/);
  }

  async continueWithoutFirstName(lastName: string, postalCode: string) {
    await this.page.getByPlaceholder("Last Name").fill(lastName);
    await this.page.getByPlaceholder("Zip/Postal Code").fill(postalCode);
    await this.page.getByRole("button", { name: "Continue" }).click();
  }

  async assertFirstNameRequiredError() {
    await expect(this.page.locator('[data-test="error"]')).toContainText(
      "Error: First Name is required",
    );
    await expect(this.page).toHaveURL(/.*checkout-step-one.html/);
  }
}

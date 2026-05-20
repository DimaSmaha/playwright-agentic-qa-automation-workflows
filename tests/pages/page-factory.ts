import { Page } from "@playwright/test";
import { CartPage } from "./cart.page";
import { CheckoutPage } from "./checkout.page";
import { InventoryPage } from "./inventory.page";
import { LoginPage } from "./login.page";
import { ProductDetailPage } from "./product-detail.page";

export class PageFactory {
  readonly page: Page;
  readonly login: LoginPage;
  readonly inventory: InventoryPage;
  readonly cart: CartPage;
  readonly checkout: CheckoutPage;
  readonly productDetail: ProductDetailPage;

  constructor(page: Page) {
    this.page = page;
    this.login = new LoginPage(page);
    this.inventory = new InventoryPage(page);
    this.cart = new CartPage(page);
    this.checkout = new CheckoutPage(page);
    this.productDetail = new ProductDetailPage(page);
  }
}

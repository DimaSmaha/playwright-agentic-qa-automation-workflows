import { expect, test as base } from "@playwright/test";
import { PageFactory } from "../pages/page-factory";

type TestFixtures = {
  pages: PageFactory;
};

export const test = base.extend<TestFixtures>({
  pages: async ({ page }, use) => {
    await use(new PageFactory(page));
  },
});

export { expect };

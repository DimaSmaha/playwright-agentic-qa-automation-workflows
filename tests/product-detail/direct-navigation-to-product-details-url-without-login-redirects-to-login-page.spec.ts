import { test } from "../fixtures/pages.fixture";

test.describe("[P3] ProductDetail: Direct navigation to product details URL without login redirects to login page", () => {
  test(
    "direct URL access without login redirects to login page",
    { tag: ["@tc-TEST-56247"] },
    async ({ pages }) => {
      await pages.productDetail.gotoDirectUrl(4);
      await pages.login.assertAtLoginPage();
    },
  );
});

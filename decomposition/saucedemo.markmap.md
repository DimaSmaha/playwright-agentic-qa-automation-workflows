---
title: System Decomposition

markmap:
  colorFreezeLevel: 1
  color: #1971c2
  initialExpandLevel: 3
---

<!--
https://markmap.js.org/docs/markmap

Branch color = section (frozen at level 1, so each Sidebar child keeps its color all the way down)
Node text color = test coverage:
  green = fully covered
  orange = partially covered
  plain text = not covered

Formatting convention:
  green → wrap text in bold inside a green span
    e.g. <span style="color:green">**Text**</span>

  orange → wrap text in italics inside an orange span
    e.g. <span style="color:orange">_Text_</span>

  plain text → no markdown formatting
-->

- SauceDemo
  - <span style="color:green">**LoginPage**</span>
    - BrandHeader
    - <span style="color:green">**LoginForm**</span>
      - <span style="color:green">**UserName**</span>
      - <span style="color:green">**Password**</span>
      - <span style="color:green">**LoginButton**</span>
      - ErrorMessage
    - HelperPanels
      - AcceptedUsernames
      - PasswordHint
  - <span style="color:green">**InventoryPage**</span>
    - <span style="color:orange">_TopBar_</span>
      - MenuButton
      - Title
      - <span style="color:green">**SortDropdown**</span>
      - <span style="color:green">**CartLink**</span>
      - <span style="color:green">**CartBadge**</span>
    - <span style="color:orange">_ProductList_</span>
      - <span style="color:orange">_ProductCard_</span>
        - ProductImage
        - ProductTitle
        - ProductDescription
        - <span style="color:green">**ProductPrice**</span>
        - <span style="color:green">**AddToCartButton**</span>
    - Footer
      - SocialLinks
  - <span style="color:orange">_CartPage_</span>
    - CartItems
    - <span style="color:green">**RemoveButton**</span>
    - <span style="color:green">**ContinueShoppingButton**</span>
    - <span style="color:green">**CheckoutButton**</span>
  - <span style="color:orange">_CheckoutPage_</span>
    - <span style="color:orange">_StepOneForm_</span>
      - <span style="color:green">**FirstName**</span>
      - <span style="color:green">**LastName**</span>
      - <span style="color:green">**PostalCode**</span>
      - <span style="color:green">**ContinueButton**</span>
      - <span style="color:green">**CancelButton**</span>
      - <span style="color:green">**ErrorMessage**</span>
    - <span style="color:orange">_StepTwoOverview_</span>
      - ItemSummary
      - TotalSummary
      - <span style="color:green">**FinishButton**</span>
      - CancelButton

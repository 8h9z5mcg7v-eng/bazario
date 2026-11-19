# BAZARIO backend foundation

This folder contains the first PostgreSQL/Supabase schema migration for BAZARIO.

## What this migration provides
- Seller profiles created automatically when an Auth user signs up.
- Store records with unique, shareable slugs and an administrator-controlled approval state.
- Products owned by a store, with an image storage path (not a base64 image).
- A public `bazario-products` image bucket, limited to JPEG/PNG/WebP files up to 1 MB; only the owning seller can upload, replace, or delete files inside that store's UUID folder.
- Customer orders and immutable product-name/price snapshots.
- Row Level Security policies separating public storefront data, each seller's data, and administrators.
- A protected public checkout wrapper with a hidden honeypot field and a limit of three orders per store/phone number per hour; the underlying function still validates products and calculates prices on the server.
- A guarded seller order-status RPC: sellers can confirm, prepare, ship, complete, or cancel orders only through valid state transitions.
- A private administrator allow-list, a caller-only admin-role check, and a database-enforced approve/reject RPC for pending stores.
- A mobile-friendly `admin.html` page for reviewing pending store applications.

## Important boundaries
- This is a schema file only. It does not create a Supabase project, configure email delivery, create a Storage bucket, connect the website, or deploy a backend.
- The `main` branch remains the published browser-only demo. The open draft PR contains Supabase Auth, seller product/image management, public approved-store pages, seller order management, and the admin approval page. These features require the Supabase project, keys, and migrations before they can run against live data.
- Admin membership must be added manually from the Supabase SQL Editor after the administrator has registered. Never expose a service-role key in the browser.
- The migration is intended for a new, empty Supabase project. Do not run it twice on the same database.
- Before a public launch, add request throttling/anti-bot protection, email verification settings, and a backup/export routine.
- No paid service, domain, account, or production deployment is created by this work.

## Supabase Free plan check — 9 November 2026

The official documentation currently lists two active Free projects, 500 MB database size per project, 1 GB Storage, 5 GB egress, 50,000 monthly active users, and 500,000 Edge Function invocations. Free projects can be paused after seven days of low database activity, and automatic daily backups are not included. Quotas are subject to change; exceeding Free limits can lead to service restrictions.

Official references:
- https://supabase.com/docs/guides/platform/billing-on-supabase
- https://supabase.com/docs/guides/platform/free-project-pausing
- https://supabase.com/docs/guides/platform/backups

## Supabase Auth frontend connection

The draft frontend contains email/password Auth, seller-store creation, product/image management, public approved-store pages, seller order management, and the admin approval page. It remains in demo mode until a Supabase project has been created, all five migrations have been applied, and the public browser settings below are filled in.

1. In the Supabase dashboard, open the project's API settings and copy the **Project URL** and the public **anon/publishable key**.
2. Open `supabase/config.js` in GitHub and enter those two values in `url` and `anonKey`.
3. Save the file. The browser uses the Supabase JavaScript v2 library from jsDelivr.
4. Open the site after the frontend change has been reviewed and deployed. Select **Mağaza yarat**, register with email/password, confirm the email if required, and sign in.
5. The first store is created with status `pending`. After an admin account has registered, add that account to the private allow-list as described below.

The anon/publishable key is designed to be used in browser code; database access must remain protected by the included RLS policies. **Never paste a service_role/secret key into `config.js`, HTML, or any public repository.** Do not share a password or key in ChatGPT.

The frontend flows have only been statically checked. They have not been tested against a live Supabase project because no project exists yet. Customer checkout is intentionally not exposed yet: the database RPC exists, but public request throttling/anti-bot protection and real security tests are still required.

## Seller password recovery

The seller login dialog includes **Şifrəni unutdum**. It sends a Supabase Auth recovery email and, after the user opens the link, displays a new-password form. Before testing this flow, open **Authentication → URL Configuration** in Supabase and add the exact BAZARIO site URL (the current page origin and path) to the allowed Redirect URLs. The email provider must be enabled. The recovery email is not sent until a Supabase project and public browser configuration exist.

## Applying it later from an iPhone
1. Open the Supabase dashboard in Safari and create/select a project only after explicitly deciding to use Supabase Free.
2. Open **SQL Editor** and create a new query.
3. Run the five migration files in timestamp order, each in a separate SQL Editor query: `20261109000000_initial_schema.sql`, `20261110000000_product_image_storage.sql`, `20261111000000_seller_order_status_workflow.sql`, `20261115000000_admin_approval_api.sql`, then `20261115100000_public_checkout_protection.sql`.
4. Review each SQL file before running it. These migrations have not been applied to a live database yet.
5. Register the administrator account through the BAZARIO sign-up flow. In SQL Editor, replace the example email below with that account's exact email and run this statement once:

   ```sql
   insert into public.admin_users (user_id)
   select id from auth.users where lower(email) = lower('admin@example.com')
   on conflict (user_id) do nothing;
   ```

6. Open `admin.html` on the same site and sign in with that administrator account. Only accounts in `admin_users` can review stores; the database RPC and RLS policies enforce this independently of the page.
7. Product image paths must use the store UUID as the first folder, for example `STORE_UUID/PRODUCT_UUID.webp`.
8. The image bucket is public for storefront display, so anyone who obtains an image URL can view that image. Do not upload private documents or personal photos.
9. Sellers change order status only through `seller_update_order_status` RPC; direct table updates are revoked.
10. Keep all secret/service-role keys out of the BAZARIO website and GitHub.

## Verify the installation
After all five migrations have completed, open a new SQL Editor query and run `verify_installation.sql`. It is a read-only check for the six tables, RLS policies, image bucket, Auth trigger, protected checkout and rate-limit index, seller order-status, and administrator approval function privileges. A successful run ends with a `BAZARIO verification passed` notice. It does not create or modify anything.

The verification script is not a substitute for a real two-account security test. Before launch, test that one seller cannot read or change another seller's products, orders, or images, and that an unapproved store is not publicly visible.

Supabase Free is not a production uptime guarantee: free projects may pause after one week of inactivity and do not include automatic backups. Check current limits before relying on it for customer orders.


## Frontend integration status — 15 November 2026

The draft frontend branch now includes these Supabase-backed flows (they require a configured project and applied migrations before they can run against real data):

- Seller sign-up/sign-in and session restoration.
- Store creation with the default `pending` approval state.
- Seller product listing, creation, image upload to `bazario-products`, and deletion.
- Public read-only storefronts at the same site URL with `?shop=STORE_SLUG`; only approved stores and active products are returned by the database policies.
- Seller order listing and guarded status changes through `seller_update_order_status`.
- A separate responsive `admin.html` page that checks the current user's admin role and approves or rejects pending stores through `admin_review_store`.

Customer checkout is now present in the draft storefront: a customer can order one product with name, phone, and quantity. The page calls `create_order_protected`; the database rejects a filled honeypot, normalizes phone formatting to digits, and limits a store/normalized-phone pair to three orders per hour. The underlying `create_order` function is no longer directly executable by `anon` or `authenticated` users. This is a basic spam barrier, not full CAPTCHA or IP-based throttling. Before production, add a provider such as Cloudflare Turnstile, review abuse limits, and test against an approved store.

The frontend has passed a JavaScript syntax parse and static element-reference checks in the repository branch. This is not a browser/device integration test: no Supabase project, keys, database migrations, Storage bucket, or real user accounts have been configured. The draft branch has not been merged and no deployment was triggered.

## Product availability and order-history protection

The seller product list now supports hiding and re-publishing a product by changing `is_active`. Checkout normalizes a valid phone number to digits before applying its per-store hourly limit, so spaces, dashes, and parentheses do not create separate rate-limit entries. Hidden products disappear from the public storefront but remain in the database and in existing order snapshots. This is the preferred way to stop selling an item.

A product referenced by an existing order cannot be deleted because `order_items.product_id` uses `ON DELETE RESTRICT`. The frontend therefore attempts the database deletion before removing its image file; if the database refuses deletion, the image is left intact and the seller is told to hide the product instead. This preserves historical order details.

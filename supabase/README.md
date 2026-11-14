# BAZARIO backend foundation

This folder contains the first PostgreSQL/Supabase schema migration for BAZARIO.

## What this migration provides
- Seller profiles created automatically when an Auth user signs up.
- Store records with unique, shareable slugs and an administrator-controlled approval state.
- Products owned by a store, with an image storage path (not a base64 image).
- A public `bazario-products` image bucket, limited to JPEG/PNG/WebP files up to 1 MB; only the owning seller can upload, replace, or delete files inside that store's UUID folder.
- Customer orders and immutable product-name/price snapshots.
- Row Level Security policies separating public storefront data, each seller's data, and administrators.
- A public checkout function that validates products and calculates prices on the server.
- A guarded seller order-status RPC: sellers can confirm, prepare, ship, complete, or cancel orders only through valid state transitions; administrators can override statuses.

## Important boundaries
- This is a schema file only. It does not create a Supabase project, configure email delivery, create a Storage bucket, connect the website, or deploy a backend.
- The current BAZARIO website is still a browser-only demo using localStorage. Real sign-in, image upload, public shop routes, and server-backed orders are not connected yet.
- Admin membership must be added from trusted SQL/service-role access after that person has signed up. Never expose a service-role key in the browser.
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

The website now contains an optional email/password Auth flow and seller-store creation flow. It remains in demo mode until a Supabase project has been created, all three migrations have been applied, and the public browser settings below are filled in.

1. In the Supabase dashboard, open the project's API settings and copy the **Project URL** and the public **anon/publishable key**.
2. Open `supabase/config.js` in GitHub and enter those two values in `url` and `anonKey`.
3. Save the file. The browser uses the Supabase JavaScript v2 library from jsDelivr.
4. Open the site after the frontend change has been reviewed and deployed. Select **Mağaza yarat**, register with email/password, confirm the email if required, and sign in.
5. The first store is created with status `pending`; the admin approval process is not yet connected to the website.

The anon/publishable key is designed to be used in browser code; database access must remain protected by the included RLS policies. **Never paste a service_role/secret key into `config.js`, HTML, or any public repository.** Do not share a password or key in ChatGPT.

The Auth flow and store creation have only been statically checked. They have not been tested against a live Supabase project because no project exists yet. Product CRUD, image uploads, public storefront routes, customer checkout, seller order management, and admin approval UI remain future integration work.

## Applying it later from an iPhone
1. Open the Supabase dashboard in Safari and create/select a project only after explicitly deciding to use Supabase Free.
2. Open **SQL Editor** and create a new query.
3. Run the three migration files in timestamp order, each in a separate SQL Editor query: `20261109000000_initial_schema.sql`, `20261110000000_product_image_storage.sql`, then `20261111000000_seller_order_status_workflow.sql`.
4. Review each SQL file before running it. These migrations have not been applied to a live database yet.
5. Product image paths must use the store UUID as the first folder, for example `STORE_UUID/PRODUCT_UUID.webp`.
6. The image bucket is public for storefront display, so anyone who obtains an image URL can view that image. Do not upload private documents or personal photos.
7. Sellers change order status only through `seller_update_order_status` RPC; direct table updates are revoked.
8. Keep all secret/service-role keys out of the BAZARIO website and GitHub.

## Verify the installation
After all three migrations have completed, open a new SQL Editor query and run `verify_installation.sql`. It is a read-only check for the six tables, RLS policies, image bucket, Auth trigger, and function/table privileges. A successful run ends with a `BAZARIO verification passed` notice. It does not create or modify anything.

The verification script is not a substitute for a real two-account security test. Before launch, test that one seller cannot read or change another seller's products, orders, or images, and that an unapproved store is not publicly visible.

Supabase Free is not a production uptime guarantee: free projects may pause after one week of inactivity and do not include automatic backups. Check current limits before relying on it for customer orders.


## Frontend integration status — 14 November 2026

The draft frontend branch now includes these Supabase-backed flows (they require a configured project and applied migrations before they can run against real data):

- Seller sign-up/sign-in and session restoration.
- Store creation with the default `pending` approval state.
- Seller product listing, creation, image upload to `bazario-products`, and deletion.
- Public read-only storefronts at the same site URL with `?shop=STORE_SLUG`; only approved stores and active products are returned by the database policies.
- Seller order listing and guarded status changes through `seller_update_order_status`.

Customer checkout is intentionally not enabled yet. The public `create_order` RPC exists in the schema, but before exposing it from a public form, add request throttling/anti-bot protection and test it against an approved store. The admin approval interface is also not implemented yet.

The frontend has passed a JavaScript syntax parse and static element-reference checks in the repository branch. This is not a browser/device integration test: no Supabase project, keys, database migrations, Storage bucket, or real user accounts have been configured. The draft branch has not been merged and no deployment was triggered.

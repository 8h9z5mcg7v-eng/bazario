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

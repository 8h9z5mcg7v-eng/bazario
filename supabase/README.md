# BAZARIO backend foundation

This folder contains the first PostgreSQL/Supabase schema migration for BAZARIO.

## What this migration provides
- Seller profiles created automatically when an Auth user signs up.
- Store records with unique, shareable slugs and an administrator-controlled approval state.
- Products owned by a store, with an image storage path (not a base64 image).
- Customer orders and immutable product-name/price snapshots.
- Row Level Security policies separating public storefront data, each seller's data, and administrators.
- A public checkout function that validates products and calculates prices on the server.

## Important boundaries
- This is a schema file only. It does not create a Supabase project, configure email delivery, create a Storage bucket, connect the website, or deploy a backend.
- The current BAZARIO website is still a browser-only demo using localStorage. Real sign-in, image upload, public shop routes, and server-backed orders are not connected yet.
- Admin membership must be added from trusted SQL/service-role access after the administrator has signed up. Never expose a service-role key in the browser.
- The migration is intended for a new, empty Supabase project. Do not run it twice on the same database.
- Before a public launch, add request throttling/anti-bot protection, storage upload policies, order-status workflows, email verification settings, and a backup/export routine.
- No paid service, domain, account, or production deployment is created by this commit.

## Applying it later from an iPhone
1. Open the Supabase dashboard in Safari and create/select a project only after explicitly deciding to use Supabase Free.
2. Open **SQL Editor** and create a new query.
3. Open the migration file in GitHub, copy the full file, and paste it into SQL Editor.
4. Review the SQL, then run it once on the new project.
5. Keep all secret/service-role keys out of the BAZARIO website and GitHub.

Supabase Free is not a production uptime guarantee: free projects may pause after one week of inactivity and do not include automatic backups. Check current limits before relying on it for customer orders.

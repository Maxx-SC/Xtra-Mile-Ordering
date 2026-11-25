# Xtra-Mile Wholesale Ordering

React/Vite storefront using the existing Supabase schema: customers, products, pricing_tiers, orders, order_items, deliveries, admin_users.

## Required before launch

1. Apply `supabase/002_checkout.sql` using Supabase SQL Editor **after** the initial database schema, RLS policies, admin setup and product/pricing import. Test in a staging project first.
2. Verify admin and retailer authentication, email confirmation, signup trigger, and approval process using actual sessions.
3. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` as Vercel environment variables. NEVER put service_role/secret keys in the frontend.
4. Import this repository into Vercel with framework **Vite**, root `./`, build command `npm run build`, output directory `dist`.
5. Add the deployed domain to Supabase Authentication URL Configuration (Site URL and redirect allowlist). Test signup, email confirmation and login.
6. Test brand-wide tier pricing, custom quote handling, duplicate lines, missing prices, and unapproved customer rejection. Review and harden database policies before production.
7. Link your deployed Vercel URL from your Wix site's **Order Wholesale** navigation/button. Optional custom subdomain later.

## Local development

```sh
npm install
cp .env.example .env.local
# edit .env.local with your project URL and publishable key
npm run dev
```

## Security and limitations

- Product prices are displayed for approved users only through RLS. The UI's cart estimate is informational; the server RPC computes the authoritative total.
- If any brand exceeds 15 cases, the whole order is a custom quote and no final line prices or subtotal are stored.
- The SQL RPC accepts only authenticated approved retailers and validates input, active products and tier pricing.
- Admin customer approvals and order status changes use the existing admin-only RLS policies.
- This starter does not send order notification emails, process payments, create delivery route records, or manage inventory. Requested delivery dates are not guaranteed.
- Never expose database admin credentials, and do not disable RLS to resolve permission errors.

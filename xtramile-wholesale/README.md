# Xtra-Mile Wholesale Ordering — compatibility update

React/Vite frontend for the existing Supabase database. Do not reinstall the old checkout SQL. This package assumes the current four-argument place_wholesale_order RPC and confirm_wholesale_delivery RPC are already installed.

## Deploy to a preview first
- Preserve your existing GitHub branch and Vercel environment settings.
- Copy these files into a new branch; remove the obsolete supabase/002_checkout.sql from that branch.
- Use Vite, npm run build, output dist. Set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY only. Never expose a service-role key or Square token.
- Test approved and pending retailer sign-in, catalog, cart, order history, customer approval, and administrator delivery confirmation in Sandbox. Confirm invoice is draft only.
- Test duplicate retry with identical payload. A failed or ambiguous submission retains its request ID in session storage; check order history before clearing that storage or starting another submission. Restore the original cart/date/notes to retry. Do not clear an uncertain request until reconciled.
- Cart pricing is a standard-tier estimate; negotiated prices are authoritative only after submission. Live preview is not implemented. Direct order status editing is removed; other admin transitions remain pending.
- Column grants are not installed by this package. Test revised permissions separately before production. No production Square calls or publishing are added.

Local: npm install; copy .env.example to .env.local and configure publishable credentials; npm run dev.

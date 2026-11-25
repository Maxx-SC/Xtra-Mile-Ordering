-- Run after the seven-table schema and RLS policies have been installed.
-- Server-side order creation. No browser-supplied prices are accepted.
create or replace function public.place_wholesale_order(
  p_items jsonb,
  p_requested_delivery_date date default null,
  p_customer_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid;
  v_order_id uuid;
  v_subtotal numeric(12,2);
  v_quote boolean;
  v_item_count integer;
  v_input_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  select c.id into v_customer_id
  from public.customers c
  where c.user_id = auth.uid() and c.approval_status = 'approved';
  if v_customer_id is null then
    raise exception 'Approved retailer account required';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 100 then
    raise exception 'Provide between 1 and 100 order lines';
  end if;
  if p_requested_delivery_date is not null
     and p_requested_delivery_date < current_date then
    raise exception 'Delivery date cannot be in the past';
  end if;
  if length(coalesce(p_customer_notes, '')) > 2000 then
    raise exception 'Customer notes exceed 2000 characters';
  end if;
  -- Strictly validate each input line; reject unknown keys and malformed quantities.
  if exists (
    select 1 from jsonb_array_elements(p_items) e(value)
    where jsonb_typeof(e.value) <> 'object'
       or not (e.value ? 'product_id' and e.value ? 'quantity_cases')
       or (select count(*) from jsonb_object_keys(e.value)) <> 2
       or coalesce(e.value->>'product_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or coalesce(e.value->>'quantity_cases','') !~ '^[1-9][0-9]{0,3}$'
       or (e.value->>'quantity_cases')::integer > 999
  ) then
    raise exception 'Invalid order line';
  end if;
  create temporary table if not exists pg_temp.xm_checkout_lines (
    product_id uuid primary key,
    quantity_cases integer not null,
    brand text,
    tier_number integer,
    unit_price numeric(10,2)
  ) on commit drop;
  truncate pg_temp.xm_checkout_lines;
  select count(*) into v_input_count from jsonb_array_elements(p_items);
  insert into pg_temp.xm_checkout_lines(product_id,quantity_cases)
  select (e.value->>'product_id')::uuid,
         (e.value->>'quantity_cases')::integer
  from jsonb_array_elements(p_items) e(value);
  get diagnostics v_item_count = row_count;
  if v_item_count <> v_input_count then
    raise exception 'Duplicate product lines are not allowed';
  end if;
  if exists (
    select 1 from pg_temp.xm_checkout_lines l
    left join public.products p on p.id = l.product_id and p.active
    where p.id is null
  ) then
    raise exception 'An item is unavailable';
  end if;
  update pg_temp.xm_checkout_lines l
  set brand = p.brand
  from public.products p where p.id = l.product_id;
  -- Tiers are based on the combined case count of every SKU in each brand.
  with brand_totals as (
    select brand, sum(quantity_cases) as cases
    from pg_temp.xm_checkout_lines group by brand
  )
  update pg_temp.xm_checkout_lines l
  set tier_number = case
    when b.cases between 1 and 5 then 1
    when b.cases between 6 and 10 then 2
    when b.cases between 11 and 15 then 3
    else null end
  from brand_totals b where b.brand = l.brand;
  select exists (
    select 1 from pg_temp.xm_checkout_lines where tier_number is null
  ) into v_quote;
  if not v_quote then
    update pg_temp.xm_checkout_lines l
    set unit_price = t.price_per_case
    from public.pricing_tiers t
    where t.product_id = l.product_id and t.tier_number = l.tier_number
      and t.min_cases <= (select sum(x.quantity_cases) from pg_temp.xm_checkout_lines x where x.brand=l.brand)
      and t.max_cases >= (select sum(x.quantity_cases) from pg_temp.xm_checkout_lines x where x.brand=l.brand);
    if exists (select 1 from pg_temp.xm_checkout_lines where unit_price is null) then
      raise exception 'A product is missing valid tier pricing';
    end if;
    select sum(quantity_cases * unit_price)::numeric(12,2)
    into v_subtotal from pg_temp.xm_checkout_lines;
  else
    v_subtotal := null;
  end if;
  insert into public.orders(customer_id, requested_delivery_date, subtotal, requires_quote, customer_notes)
  values(v_customer_id, p_requested_delivery_date, v_subtotal, v_quote, p_customer_notes)
  returning id into v_order_id;
  insert into public.order_items(order_id,product_id,quantity_cases,unit_price,line_total)
  select v_order_id,product_id,quantity_cases,
         case when v_quote then null else unit_price end,
         case when v_quote then null else quantity_cases * unit_price end
  from pg_temp.xm_checkout_lines;
  return jsonb_build_object('order_id',v_order_id,'requires_quote',v_quote,'subtotal',v_subtotal);
end;
$$;
revoke all on function public.place_wholesale_order(jsonb,date,text) from public,anon;
grant execute on function public.place_wholesale_order(jsonb,date,text) to authenticated;

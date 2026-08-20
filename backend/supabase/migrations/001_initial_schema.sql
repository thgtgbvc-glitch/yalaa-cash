-- Yalla Cash initial PostgreSQL/Supabase schema.
-- Review in a staging project before production use.

create extension if not exists pgcrypto;

create type public.auth_method as enum ('facebook', 'gmail', 'phone');
create type public.cash_request_status as enum ('pending', 'settled', 'rejected');
create type public.redemption_status as enum ('pending', 'fulfilled', 'rejected');
create type public.settlement_status as enum ('open', 'settled');
create type public.points_entry_type as enum (
  'invoice_earn',
  'cash_reserve',
  'cash_release',
  'cash_settle',
  'product_redeem',
  'admin_grant',
  'admin_deduct'
);

create table public.customers (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) >= 2),
  phone text,
  auth_method public.auth_method not null,
  governorate text not null,
  points_balance bigint not null default 0 check (points_balance >= 0),
  created_at timestamptz not null default now()
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  city text not null,
  commission_rate numeric(5,2) not null check (commission_rate >= 0 and commission_rate <= 100),
  description text not null default '',
  location text not null default '',
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- One active exclusive merchant for each category in each city.
create unique index stores_one_active_category_per_city
  on public.stores (lower(city), lower(category))
  where is_active;

create table public.merchant_accounts (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  display_label text not null default 'الحساب الرئيسي',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.merchant_devices (
  id uuid primary key default gen_random_uuid(),
  merchant_account_id uuid not null references public.merchant_accounts(id) on delete cascade,
  device_label text not null,
  device_fingerprint_hash text not null,
  last_login_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (merchant_account_id, device_fingerprint_hash)
);

create table public.admin_users (
  auth_user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now()
);

create table public.platform_settings (
  singleton boolean primary key default true check (singleton),
  point_value_syp integer not null check (point_value_syp > 0),
  updated_at timestamptz not null default now()
);

insert into public.platform_settings (singleton, point_value_syp)
values (true, 5)
on conflict (singleton) do nothing;

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  customer_id uuid not null references public.customers(id),
  merchant_account_id uuid not null references public.merchant_accounts(id),
  amount_syp bigint not null check (amount_syp > 0),
  commission_rate_snapshot numeric(5,2) not null,
  commission_amount_syp bigint not null check (commission_amount_syp >= 0),
  platform_revenue_syp bigint not null check (platform_revenue_syp >= 0),
  customer_share_syp bigint not null check (customer_share_syp >= 0),
  point_value_syp_snapshot integer not null check (point_value_syp_snapshot > 0),
  customer_points_earned bigint not null check (customer_points_earned >= 0),
  idempotency_key uuid not null unique,
  created_at timestamptz not null default now(),
  check (platform_revenue_syp + customer_share_syp = commission_amount_syp)
);

create index transactions_customer_created_idx
  on public.transactions (customer_id, created_at desc);
create index transactions_store_created_idx
  on public.transactions (store_id, created_at desc);

create table public.points_ledger (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  entry_type public.points_entry_type not null,
  points_delta bigint not null,
  balance_after bigint not null check (balance_after >= 0),
  transaction_id uuid references public.transactions(id),
  reference_id uuid,
  note text,
  created_at timestamptz not null default now()
);

create index points_ledger_customer_created_idx
  on public.points_ledger (customer_id, created_at desc);

create table public.digital_products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  cost_in_points bigint not null check (cost_in_points > 0),
  image_url text,
  requires_phone_number boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.product_redemptions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  product_id uuid not null references public.digital_products(id),
  points_cost_snapshot bigint not null check (points_cost_snapshot > 0),
  phone_number text,
  status public.redemption_status not null default 'pending',
  fulfilled_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.cash_redemption_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers(id),
  points_requested bigint not null check (points_requested > 0),
  point_value_syp_snapshot integer not null check (point_value_syp_snapshot > 0),
  cash_value_syp bigint not null check (cash_value_syp > 0),
  status public.cash_request_status not null default 'pending',
  settled_by uuid references public.admin_users(auth_user_id),
  settled_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index one_pending_cash_request_per_customer
  on public.cash_redemption_requests (customer_id)
  where status = 'pending';

create table public.merchant_settlements (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id),
  period_start date not null,
  period_end date not null,
  transaction_count integer not null default 0,
  total_sales_syp bigint not null default 0,
  commission_due_syp bigint not null default 0,
  status public.settlement_status not null default 'open',
  settled_by uuid references public.admin_users(auth_user_id),
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  unique (store_id, period_start, period_end),
  check (period_end >= period_start)
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users where auth_user_id = auth.uid()
  );
$$;

create or replace function public.available_customer_points(p_customer_id uuid)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select c.points_balance - coalesce((
    select sum(r.points_requested)
    from public.cash_redemption_requests r
    where r.customer_id = c.id and r.status = 'pending'
  ), 0)
  from public.customers c
  where c.id = p_customer_id
    and (p_customer_id = auth.uid() or public.is_admin());
$$;

create or replace function public.register_invoice(
  p_customer_id uuid,
  p_amount_syp bigint,
  p_idempotency_key uuid
)
returns public.transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_account public.merchant_accounts;
  v_store public.stores;
  v_point_value integer;
  v_commission bigint;
  v_customer_share bigint;
  v_platform_share bigint;
  v_points bigint;
  v_transaction public.transactions;
  v_balance bigint;
begin
  if p_amount_syp <= 0 then
    raise exception 'invoice_amount_invalid';
  end if;

  select * into v_account
  from public.merchant_accounts
  where auth_user_id = auth.uid() and is_active
  limit 1;

  if v_account.id is null then
    raise exception 'merchant_not_authorized';
  end if;

  select * into v_store from public.stores where id = v_account.store_id and is_active;
  if v_store.id is null then
    raise exception 'store_not_active';
  end if;

  perform 1 from public.customers where id = p_customer_id for update;
  if not found then
    raise exception 'customer_not_found';
  end if;

  select point_value_syp into v_point_value from public.platform_settings where singleton;
  v_commission := round(p_amount_syp * v_store.commission_rate / 100.0);
  v_customer_share := round(v_commission / 2.0);
  v_platform_share := v_commission - v_customer_share;
  v_points := round(v_customer_share::numeric / v_point_value);

  insert into public.transactions (
    store_id,
    customer_id,
    merchant_account_id,
    amount_syp,
    commission_rate_snapshot,
    commission_amount_syp,
    platform_revenue_syp,
    customer_share_syp,
    point_value_syp_snapshot,
    customer_points_earned,
    idempotency_key
  ) values (
    v_store.id,
    p_customer_id,
    v_account.id,
    p_amount_syp,
    v_store.commission_rate,
    v_commission,
    v_platform_share,
    v_customer_share,
    v_point_value,
    v_points,
    p_idempotency_key
  )
  returning * into v_transaction;

  update public.customers
  set points_balance = points_balance + v_points
  where id = p_customer_id
  returning points_balance into v_balance;

  insert into public.points_ledger (
    customer_id, entry_type, points_delta, balance_after, transaction_id, note
  ) values (
    p_customer_id,
    'invoice_earn',
    v_points,
    v_balance,
    v_transaction.id,
    'نقاط مكتسبة من فاتورة'
  );

  return v_transaction;
exception
  when unique_violation then
    select * into v_transaction
    from public.transactions
    where idempotency_key = p_idempotency_key;
    return v_transaction;
end;
$$;

create or replace function public.update_customer_profile(
  p_name text,
  p_governorate text,
  p_phone text default null
)
returns public.customers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer public.customers;
begin
  if char_length(trim(p_name)) < 2 or char_length(trim(p_governorate)) < 2 then
    raise exception 'profile_data_invalid';
  end if;

  update public.customers
  set name = trim(p_name), governorate = trim(p_governorate), phone = nullif(trim(p_phone), '')
  where id = auth.uid()
  returning * into v_customer;

  if v_customer.id is null then
    raise exception 'customer_not_found';
  end if;
  return v_customer;
end;
$$;

create or replace function public.request_cash_redemption(p_points bigint)
returns public.cash_redemption_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer public.customers;
  v_point_value integer;
  v_available bigint;
  v_request public.cash_redemption_requests;
begin
  if p_points <= 0 then
    raise exception 'points_invalid';
  end if;

  select * into v_customer
  from public.customers
  where id = auth.uid()
  for update;

  if v_customer.id is null then
    raise exception 'customer_not_found';
  end if;

  select public.available_customer_points(v_customer.id) into v_available;
  if p_points > v_available then
    raise exception 'insufficient_points';
  end if;

  select point_value_syp into v_point_value
  from public.platform_settings
  where singleton;

  insert into public.cash_redemption_requests (
    customer_id,
    points_requested,
    point_value_syp_snapshot,
    cash_value_syp
  ) values (
    v_customer.id,
    p_points,
    v_point_value,
    p_points * v_point_value
  )
  returning * into v_request;

  insert into public.points_ledger (
    customer_id, entry_type, points_delta, balance_after, reference_id, note
  ) values (
    v_customer.id,
    'cash_reserve',
    0,
    v_customer.points_balance,
    v_request.id,
    'حجز نقاط لطلب استبدال كاش'
  );

  return v_request;
end;
$$;

create or replace function public.resolve_cash_redemption(
  p_request_id uuid,
  p_approve boolean
)
returns public.cash_redemption_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.cash_redemption_requests;
  v_balance bigint;
begin
  if not public.is_admin() then
    raise exception 'admin_not_authorized';
  end if;

  select * into v_request
  from public.cash_redemption_requests
  where id = p_request_id
  for update;

  if v_request.id is null or v_request.status <> 'pending' then
    raise exception 'cash_request_not_pending';
  end if;

  perform 1 from public.customers where id = v_request.customer_id for update;

  if p_approve then
    update public.customers
    set points_balance = points_balance - v_request.points_requested
    where id = v_request.customer_id
      and points_balance >= v_request.points_requested
    returning points_balance into v_balance;

    if v_balance is null then
      raise exception 'insufficient_points';
    end if;

    update public.cash_redemption_requests
    set status = 'settled', settled_by = auth.uid(), settled_at = now()
    where id = v_request.id
    returning * into v_request;

    insert into public.points_ledger (
      customer_id, entry_type, points_delta, balance_after, reference_id, note
    ) values (
      v_request.customer_id,
      'cash_settle',
      -v_request.points_requested,
      v_balance,
      v_request.id,
      'تسوية طلب استبدال كاش'
    );
  else
    select points_balance into v_balance
    from public.customers
    where id = v_request.customer_id;

    update public.cash_redemption_requests
    set status = 'rejected', settled_by = auth.uid(), settled_at = now()
    where id = v_request.id
    returning * into v_request;

    insert into public.points_ledger (
      customer_id, entry_type, points_delta, balance_after, reference_id, note
    ) values (
      v_request.customer_id,
      'cash_release',
      0,
      v_balance,
      v_request.id,
      'إلغاء طلب استبدال كاش'
    );
  end if;

  return v_request;
end;
$$;

create or replace function public.redeem_digital_product(
  p_product_id uuid,
  p_phone_number text default null
)
returns public.product_redemptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.digital_products;
  v_customer public.customers;
  v_available bigint;
  v_redemption public.product_redemptions;
  v_balance bigint;
begin
  select * into v_product
  from public.digital_products
  where id = p_product_id and is_active;

  if v_product.id is null then
    raise exception 'product_not_available';
  end if;
  if v_product.requires_phone_number and char_length(trim(coalesce(p_phone_number, ''))) < 8 then
    raise exception 'phone_number_required';
  end if;

  select * into v_customer
  from public.customers
  where id = auth.uid()
  for update;

  if v_customer.id is null then
    raise exception 'customer_not_found';
  end if;

  select public.available_customer_points(v_customer.id) into v_available;
  if v_product.cost_in_points > v_available then
    raise exception 'insufficient_points';
  end if;

  update public.customers
  set points_balance = points_balance - v_product.cost_in_points
  where id = v_customer.id
  returning points_balance into v_balance;

  insert into public.product_redemptions (
    customer_id, product_id, points_cost_snapshot, phone_number
  ) values (
    v_customer.id,
    v_product.id,
    v_product.cost_in_points,
    nullif(trim(p_phone_number), '')
  )
  returning * into v_redemption;

  insert into public.points_ledger (
    customer_id, entry_type, points_delta, balance_after, reference_id, note
  ) values (
    v_customer.id,
    'product_redeem',
    -v_product.cost_in_points,
    v_balance,
    v_redemption.id,
    'استبدال منتج رقمي'
  );

  return v_redemption;
end;
$$;

alter table public.customers enable row level security;
alter table public.stores enable row level security;
alter table public.merchant_accounts enable row level security;
alter table public.merchant_devices enable row level security;
alter table public.admin_users enable row level security;
alter table public.platform_settings enable row level security;
alter table public.transactions enable row level security;
alter table public.points_ledger enable row level security;
alter table public.digital_products enable row level security;
alter table public.product_redemptions enable row level security;
alter table public.cash_redemption_requests enable row level security;
alter table public.merchant_settlements enable row level security;

create policy customers_read_self on public.customers
  for select using (id = auth.uid() or public.is_admin());
create policy customers_insert_self on public.customers
  for insert with check (id = auth.uid() and points_balance = 0);
create policy customers_admin_all on public.customers
  for all using (public.is_admin()) with check (public.is_admin());

create policy stores_read_active on public.stores
  for select using (is_active or public.is_admin());
create policy stores_admin_all on public.stores
  for all using (public.is_admin()) with check (public.is_admin());

create policy merchant_accounts_read_self on public.merchant_accounts
  for select using (auth_user_id = auth.uid() or public.is_admin());
create policy merchant_accounts_admin_all on public.merchant_accounts
  for all using (public.is_admin()) with check (public.is_admin());

create policy transactions_customer_or_merchant_read on public.transactions
  for select using (
    customer_id = auth.uid()
    or exists (
      select 1 from public.merchant_accounts ma
      where ma.id = merchant_account_id and ma.auth_user_id = auth.uid()
    )
    or public.is_admin()
  );

create policy ledger_customer_read on public.points_ledger
  for select using (customer_id = auth.uid() or public.is_admin());

create policy products_read_active on public.digital_products
  for select using (is_active or public.is_admin());
create policy products_admin_all on public.digital_products
  for all using (public.is_admin()) with check (public.is_admin());

create policy product_redemptions_customer_read on public.product_redemptions
  for select using (customer_id = auth.uid() or public.is_admin());
create policy product_redemptions_admin_all on public.product_redemptions
  for all using (public.is_admin()) with check (public.is_admin());

create policy cash_requests_customer_read on public.cash_redemption_requests
  for select using (customer_id = auth.uid() or public.is_admin());
create policy cash_requests_admin_update on public.cash_redemption_requests
  for update using (public.is_admin()) with check (public.is_admin());

create policy settings_authenticated_read on public.platform_settings
  for select to authenticated using (true);
create policy settings_admin_update on public.platform_settings
  for update using (public.is_admin()) with check (public.is_admin());

create policy settlements_merchant_or_admin_read on public.merchant_settlements
  for select using (
    exists (
      select 1 from public.merchant_accounts ma
      where ma.store_id = merchant_settlements.store_id and ma.auth_user_id = auth.uid()
    )
    or public.is_admin()
  );
create policy settlements_admin_all on public.merchant_settlements
  for all using (public.is_admin()) with check (public.is_admin());

grant execute on function public.register_invoice(uuid, bigint, uuid) to authenticated;
grant execute on function public.available_customer_points(uuid) to authenticated;
grant execute on function public.update_customer_profile(text, text, text) to authenticated;
grant execute on function public.request_cash_redemption(bigint) to authenticated;
grant execute on function public.resolve_cash_redemption(uuid, boolean) to authenticated;
grant execute on function public.redeem_digital_product(uuid, text) to authenticated;

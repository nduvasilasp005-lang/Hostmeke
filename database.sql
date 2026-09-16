-- ════════════════════════════════════════════════════════════
-- HOST ME KE — Supabase Database Setup
-- Run this entire file in: Supabase → SQL Editor → Run
-- ════════════════════════════════════════════════════════════

-- ── 1. PROFILES ──────────────────────────────────────────────
-- Extends Supabase's built-in auth.users table
create table if not exists profiles (
  id          uuid references auth.users(id) on delete cascade primary key,
  full_name   text,
  phone       text,
  avatar_url  text,
  role        text default 'guest' check (role in ('guest', 'host', 'admin')),
  created_at  timestamptz default now()
);

-- Auto-create a profile row whenever someone signs up
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, full_name)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();


-- ── 2. PROPERTIES ─────────────────────────────────────────────
create table if not exists properties (
  id               bigint generated always as identity primary key,
  account_number   text unique not null,
  name             text not null,
  location         text not null,
  type             text not null check (type in ('bnb', 'rent', 'sale')),
  price            numeric not null check (price > 0),
  unit             text default '/night',
  beds             int default 1,
  rating           numeric default 0,
  image_url        text,
  description      text,
  host_id          uuid references profiles(id) on delete set null,
  is_available     boolean default true,
  created_at       timestamptz default now()
);


-- ── 3. BOOKINGS ───────────────────────────────────────────────
create table if not exists bookings (
  id                   bigint generated always as identity primary key,
  property_id          bigint references properties(id) on delete set null,
  user_id              uuid references profiles(id) on delete set null,
  phone                text,
  amount               numeric not null,
  account_reference    text,
  checkout_request_id  text unique,
  mpesa_receipt        text,
  status               text default 'pending' check (status in ('pending', 'confirmed', 'failed')),
  created_at           timestamptz default now()
);


-- ── 4. WISHLIST ───────────────────────────────────────────────
create table if not exists wishlist (
  id           bigint generated always as identity primary key,
  user_id      uuid references profiles(id) on delete cascade,
  property_id  bigint references properties(id) on delete cascade,
  created_at   timestamptz default now(),
  unique(user_id, property_id)
);


-- ── 5. MESSAGES ───────────────────────────────────────────────
create table if not exists messages (
  id           bigint generated always as identity primary key,
  sender_id    uuid references profiles(id) on delete set null,
  receiver_id  uuid references profiles(id) on delete set null,
  property_id  bigint references properties(id) on delete set null,
  content      text not null,
  is_read      boolean default false,
  created_at   timestamptz default now()
);


-- ════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- Controls who can read/write each table
-- ════════════════════════════════════════════════════════════

-- Enable RLS on all tables
alter table profiles   enable row level security;
alter table properties enable row level security;
alter table bookings   enable row level security;
alter table wishlist   enable row level security;
alter table messages   enable row level security;


-- PROFILES policies
create policy "Public profiles are viewable by everyone"
  on profiles for select using (true);

create policy "Users can update their own profile"
  on profiles for update using (auth.uid() = id);


-- PROPERTIES policies
create policy "Properties are viewable by everyone"
  on properties for select using (true);

create policy "Authenticated users can insert properties"
  on properties for insert with check (auth.uid() = host_id);

create policy "Hosts can update their own properties"
  on properties for update using (auth.uid() = host_id);

create policy "Hosts can delete their own properties"
  on properties for delete using (auth.uid() = host_id);


-- BOOKINGS policies
create policy "Users can view their own bookings"
  on bookings for select using (auth.uid() = user_id);

create policy "Authenticated users can create bookings"
  on bookings for insert with check (auth.uid() = user_id);

-- Server (service role) can update bookings — no RLS restriction needed for service role


-- WISHLIST policies
create policy "Users can view their own wishlist"
  on wishlist for select using (auth.uid() = user_id);

create policy "Users can add to their wishlist"
  on wishlist for insert with check (auth.uid() = user_id);

create policy "Users can remove from their wishlist"
  on wishlist for delete using (auth.uid() = user_id);


-- MESSAGES policies
create policy "Users can view their own messages"
  on messages for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Authenticated users can send messages"
  on messages for insert with check (auth.uid() = sender_id);


-- ════════════════════════════════════════════════════════════
-- SEED DATA — 8 demo properties (optional, safe to skip)
-- Remove this section once you have real listings
-- ════════════════════════════════════════════════════════════
insert into properties (account_number, name, location, type, price, unit, beds, rating, image_url, is_available) values
  ('HM0012026', 'Villa Sol y Luna',  'Diani Beach, Mombasa',   'bnb',  9400,     '/night',  3, 8.5, 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400&q=80', true),
  ('HM0022026', 'Castaway Villa',    'Watamu, Kilifi',          'bnb',  9548,     '/night',  4, 8.9, 'https://images.unsplash.com/photo-1464983953574-0892a716854b?w=400&q=80', true),
  ('HM0032026', 'Falcon Nest',       'Karen, Nairobi',          'rent', 8570,     '/month',  2, 7.4, 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=400&q=80',  true),
  ('HM0042026', 'Orlando Resort',    'Kisumu, Nyanza',          'bnb',  8700,     '/night',  5, 7.9, 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=400&q=80', true),
  ('HM0052026', 'Savanna Heights',   'Ngong Road, Nairobi',     'sale', 12500000, ' KES',    4, 9.1, 'https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=400&q=80', true),
  ('HM0062026', 'Coral Bay Cottage', 'Malindi, Kilifi',         'rent', 35000,    '/month',  2, 8.2, 'https://images.unsplash.com/photo-1505691938895-1758d7feb511?w=400&q=80', true),
  ('HM0072026', 'Lakeside Manor',    'Naivasha, Rift Valley',   'sale', 8900000,  ' KES',    5, 8.7, 'https://images.unsplash.com/photo-1493809842364-78817add7ffb?w=400&q=80', true),
  ('HM0082026', 'Uhuru Apartments',  'Westlands, Nairobi',      'rent', 55000,    '/month',  1, 7.8, 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=400&q=80', true)
on conflict (account_number) do nothing;

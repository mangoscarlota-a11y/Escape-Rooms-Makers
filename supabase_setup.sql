-- Pega todo este archivo en Supabase: SQL Editor -> New query -> Run.
-- Se puede ejecutar varias veces sin problema (también si ya lo habías ejecutado antes:
-- así se actualizan las reglas para escape rooms de varias salas).
--
-- Crea la tabla de salas y las reglas: cualquiera puede LEER y PUBLICAR,
-- pero nadie puede editarlas ni borrarlas desde el juego.

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 40),
  author text not null check (char_length(author) between 1 and 30),
  data jsonb not null,
  created_at timestamptz not null default now()
);

-- Un escape room tiene entre 1 y 6 salas y pesa menos de 200 KB.
-- "not valid" = la regla vale para las salas nuevas y no revisa las ya publicadas (formato antiguo).
alter table public.rooms drop constraint if exists rooms_data_check;
alter table public.rooms add constraint rooms_data_check check (
  case
    when jsonb_typeof(data -> 'rooms') = 'array'
      then jsonb_array_length(data -> 'rooms') between 1 and 6
    else false
  end
  and octet_length(data::text) < 200000
) not valid;

create index if not exists rooms_created_at_idx on public.rooms (created_at desc);

alter table public.rooms enable row level security;

drop policy if exists "Cualquiera puede ver las salas" on public.rooms;
create policy "Cualquiera puede ver las salas"
  on public.rooms for select to anon, authenticated using (true);

drop policy if exists "Cualquiera puede publicar salas" on public.rooms;
create policy "Cualquiera puede publicar salas"
  on public.rooms for insert to anon, authenticated with check (true);

grant usage on schema public to anon, authenticated;
grant select, insert on public.rooms to anon, authenticated;

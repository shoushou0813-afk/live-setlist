-- ライブ演奏曲アーカイブ スキーマ
-- Supabase ダッシュボードの SQL Editor に貼って一度だけ実行する

-- ========== テーブル ==========

create table public.lives (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title         text not null check (char_length(title) between 1 and 100),
  performed_on  date not null,
  venue         text check (char_length(venue) <= 100),
  created_at    timestamptz not null default now()
);

create table public.songs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 200),
  -- 同じ曲かどうかの判定用（前後空白除去＋小文字化）
  title_key   text generated always as (lower(btrim(title))) stored,
  created_at  timestamptz not null default now(),
  unique (user_id, title_key)
);

-- ライブと曲の中間テーブル（曲順つき）
create table public.setlist_items (
  live_id   uuid not null references public.lives(id) on delete cascade,
  position  int  not null check (position >= 1),
  song_id   uuid not null references public.songs(id) on delete restrict,
  user_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  primary key (live_id, position)
);

create index lives_user_date_idx on public.lives (user_id, performed_on desc);
create index setlist_items_song_idx on public.setlist_items (song_id);

-- ========== RLS ==========

alter table public.lives         enable row level security;
alter table public.songs         enable row level security;
alter table public.setlist_items enable row level security;

create policy "自分のライブのみ" on public.lives
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "自分の曲のみ" on public.songs
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 外部キーのチェックは RLS を通らないため、
-- 他人のライブ・曲の ID を指定して紐づけられないよう明示的に確認する
create policy "自分のセトリ項目のみ" on public.setlist_items
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.lives l
                where l.id = live_id and l.user_id = (select auth.uid()))
    and exists (select 1 from public.songs s
                where s.id = song_id and s.user_id = (select auth.uid()))
  );

-- ========== 集計ビュー ==========
-- security_invoker = true で、呼び出した人の RLS がそのまま効く

create view public.song_stats
with (security_invoker = true) as
select
  s.id,
  s.title,
  count(distinct si.live_id)::int as play_count,
  max(l.performed_on)             as last_played_on
from public.songs s
join public.setlist_items si on si.song_id = s.id
join public.lives l          on l.id = si.live_id
group by s.id, s.title;

-- ========== 保存用 RPC ==========
-- ライブ本体・曲・曲順を 1 トランザクションで保存する
-- p_live_id が null なら新規作成、あれば更新（曲順は作り直し）

create or replace function public.save_live(
  p_live_id      uuid,
  p_title        text,
  p_performed_on date,
  p_venue        text,
  p_songs        text[]
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_live_id uuid;
  v_title   text;
  v_song_id uuid;
  v_pos     int := 0;
begin
  if auth.uid() is null then
    raise exception 'ログインが必要です';
  end if;

  if p_live_id is null then
    insert into public.lives (title, performed_on, venue)
    values (btrim(p_title), p_performed_on, nullif(btrim(p_venue), ''))
    returning id into v_live_id;
  else
    update public.lives
       set title = btrim(p_title),
           performed_on = p_performed_on,
           venue = nullif(btrim(p_venue), '')
     where id = p_live_id
    returning id into v_live_id;

    if v_live_id is null then
      raise exception 'ライブが見つかりません';
    end if;

    delete from public.setlist_items where live_id = v_live_id;
  end if;

  foreach v_title in array coalesce(p_songs, '{}'::text[]) loop
    v_title := btrim(v_title);
    continue when v_title = '';

    insert into public.songs (title) values (v_title)
    on conflict (user_id, title_key) do nothing;

    select id into v_song_id
      from public.songs
     where user_id = auth.uid() and title_key = lower(v_title);

    v_pos := v_pos + 1;
    insert into public.setlist_items (live_id, position, song_id)
    values (v_live_id, v_pos, v_song_id);
  end loop;

  return v_live_id;
end;
$$;

revoke execute on function public.save_live(uuid, text, date, text, text[]) from public, anon;
grant  execute on function public.save_live(uuid, text, date, text, text[]) to authenticated;

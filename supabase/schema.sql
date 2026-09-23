-- サークル ライブ演奏曲アーカイブ スキーマ
-- Supabase ダッシュボードの SQL Editor に貼って一度だけ実行する
--
-- 方針：データの持ち主は「個人」ではなく「サークル」。
-- 同じサークルの部員なら全員が同じライブ・曲・集計を見て、追加・編集できる。
-- 誰が見られるかの判定はすべて RLS（行レベルセキュリティ）で DB 側に持たせ、
-- フロントの条件分岐には頼らない。

-- ========== サークルと所属 ==========

create table public.circles (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (char_length(name) between 1 and 50),
  -- 部員が参加するときに入力する合言葉。大文字で保存して大小の打ち間違いを吸収する
  invite_code  text not null unique check (invite_code ~ '^[A-Z0-9]{6,12}$'),
  created_at   timestamptz not null default now()
);

create table public.circle_members (
  circle_id     uuid not null references public.circles(id) on delete cascade,
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  display_name  text not null check (char_length(display_name) between 1 and 30),
  -- admin はサークル名の変更と部員の削除ができる。作成者が自動的に admin になる
  role          text not null default 'member' check (role in ('admin', 'member')),
  joined_at     timestamptz not null default now(),
  primary key (circle_id, user_id)
);

create index circle_members_user_idx on public.circle_members (user_id);

-- ========== ライブ・曲 ==========

create table public.lives (
  id            uuid primary key default gen_random_uuid(),
  circle_id     uuid not null references public.circles(id) on delete cascade,
  -- 登録した人。表示用で、編集権限には使わない（部員なら誰でも直せる運用のため）。
  -- 退部して auth.users から消えても記録は残したいので on delete set null
  created_by    uuid references auth.users(id) on delete set null,
  title         text not null check (char_length(title) between 1 and 100),
  performed_on  date not null,
  venue         text check (char_length(venue) <= 100),
  -- そのライブに出たバンド名。サークルは複数バンドが出るので、どのバンドの曲かを残す
  band          text check (char_length(band) <= 100),
  created_at    timestamptz not null default now()
);

create table public.songs (
  id          uuid primary key default gen_random_uuid(),
  circle_id   uuid not null references public.circles(id) on delete cascade,
  title       text not null check (char_length(title) between 1 and 200),
  -- 同じ曲かどうかの判定用（前後空白除去＋小文字化）
  title_key   text generated always as (lower(btrim(title))) stored,
  created_at  timestamptz not null default now(),
  -- 曲マスタはサークル単位。部員が別々に登録しても 1 曲にまとまる
  unique (circle_id, title_key)
);

-- ライブと曲の中間テーブル（曲順つき）
create table public.setlist_items (
  live_id        uuid not null references public.lives(id) on delete cascade,
  position       int  not null check (position >= 1),
  song_id        uuid not null references public.songs(id) on delete restrict,
  circle_id      uuid not null references public.circles(id) on delete cascade,
  -- PA・照明の設定メモ。同じ曲でもライブごとに会場や機材で設定が変わるため、
  -- 曲マスタ（songs）ではなく「このライブのこの曲」の単位（setlist_items）で持つ
  pa_note        text check (char_length(pa_note) <= 300),
  lighting_note  text check (char_length(lighting_note) <= 300),
  primary key (live_id, position)
);

create index lives_circle_date_idx    on public.lives (circle_id, performed_on desc);
create index songs_circle_idx         on public.songs (circle_id);
create index setlist_items_song_idx   on public.setlist_items (song_id);
create index setlist_items_circle_idx on public.setlist_items (circle_id);

-- ========== 所属判定の関数 ==========
-- circle_members のポリシーの中で circle_members を読むと無限再帰になるため、
-- security definer（作成者権限で動く＝RLS を通らない）の関数に切り出す。
-- 返すのは「呼んだ本人が所属しているか」の真偽値だけなので、他人の情報は漏れない。

create or replace function public.is_circle_member(p_circle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.circle_members m
     where m.circle_id = p_circle_id
       and m.user_id = (select auth.uid())
  );
$$;

create or replace function public.is_circle_admin(p_circle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.circle_members m
     where m.circle_id = p_circle_id
       and m.user_id = (select auth.uid())
       and m.role = 'admin'
  );
$$;

-- ========== RLS ==========

alter table public.circles        enable row level security;
alter table public.circle_members enable row level security;
alter table public.lives          enable row level security;
alter table public.songs          enable row level security;
alter table public.setlist_items  enable row level security;

-- サークル本体：所属している人だけが読める。作成は RPC（create_circle）経由だけにしたいので
-- insert のポリシーは作らない（ポリシーが無い操作は全部拒否される）
create policy "所属サークルのみ参照" on public.circles
  for select to authenticated
  using (public.is_circle_member(id));

create policy "サークル名の変更は管理者のみ" on public.circles
  for update to authenticated
  using (public.is_circle_admin(id))
  with check (public.is_circle_admin(id));

-- 所属：同じサークルの部員名簿は部員全員が見られる（ライブの登録者名を出すため）
create policy "同じサークルの部員のみ参照" on public.circle_members
  for select to authenticated
  using (public.is_circle_member(circle_id));

-- 自分の表示名だけ変えられる。role の書き換えは下のトリガーで防ぐ
create policy "自分の所属情報のみ更新" on public.circle_members
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- 退部（自分の行の削除）と、管理者による部員の削除
create policy "退部または管理者による削除" on public.circle_members
  for delete to authenticated
  using (user_id = (select auth.uid()) or public.is_circle_admin(circle_id));

-- 自分で自分を admin に昇格させられないようにする。
-- RLS のポリシーからは変更前の値（OLD）が見えないので、トリガーで比べる
create or replace function public.guard_member_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role and not public.is_circle_admin(old.circle_id) then
    raise exception '役割を変更できるのは管理者だけです';
  end if;
  return new;
end;
$$;

create trigger circle_members_guard_role
  before update on public.circle_members
  for each row execute function public.guard_member_role_change();

-- ライブ・曲：所属しているサークルのものなら、部員は誰でも読み書きできる
create policy "所属サークルのライブ" on public.lives
  for all to authenticated
  using (public.is_circle_member(circle_id))
  with check (public.is_circle_member(circle_id));

create policy "所属サークルの曲" on public.songs
  for all to authenticated
  using (public.is_circle_member(circle_id))
  with check (public.is_circle_member(circle_id));

-- 外部キーの検証は RLS を通らないため、別サークルの live_id / song_id を
-- 紐づけられないよう with check で明示的に確認する
create policy "所属サークルのセトリ項目" on public.setlist_items
  for all to authenticated
  using (public.is_circle_member(circle_id))
  with check (
    public.is_circle_member(circle_id)
    and exists (select 1 from public.lives l
                 where l.id = live_id and l.circle_id = setlist_items.circle_id)
    and exists (select 1 from public.songs s
                 where s.id = song_id and s.circle_id = setlist_items.circle_id)
  );

-- ========== 集計ビュー ==========
-- security_invoker = true で、呼び出した人の RLS がそのまま効く（付けないと作成者権限で
-- 動いてしまい、他サークルの集計まで見えてしまう）

create view public.song_stats
with (security_invoker = true) as
select
  s.id,
  s.circle_id,
  s.title,
  count(distinct si.live_id)::int as play_count,
  max(l.performed_on)             as last_played_on
from public.songs s
join public.setlist_items si on si.song_id = s.id
join public.lives l          on l.id = si.live_id
group by s.id, s.circle_id, s.title;

-- ========== サークル作成・参加の RPC ==========

-- 招待コードの生成。0/O、1/I のような紛らわしい文字は使わない
create or replace function public.generate_invite_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  i int;
begin
  for attempt in 1..20 loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    if not exists (select 1 from public.circles c where c.invite_code = v_code) then
      return v_code;
    end if;
  end loop;
  raise exception '招待コードを発行できませんでした。もう一度お試しください';
end;
$$;

-- サークルを作り、作った人を管理者として登録する。
-- circles には insert のポリシーが無いので、この関数（security definer）だけが作成経路になる
create or replace function public.create_circle(p_name text, p_display_name text)
returns table (circle_id uuid, invite_code text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_id   uuid;
  v_code text;
begin
  if v_uid is null then
    raise exception 'ログインが必要です';
  end if;
  if btrim(coalesce(p_name, '')) = '' then
    raise exception 'サークル名を入力してください';
  end if;
  if btrim(coalesce(p_display_name, '')) = '' then
    raise exception '自分の表示名を入力してください';
  end if;

  v_code := public.generate_invite_code();

  insert into public.circles (name, invite_code)
  values (btrim(p_name), v_code)
  returning id into v_id;

  insert into public.circle_members (circle_id, user_id, display_name, role)
  values (v_id, v_uid, btrim(p_display_name), 'admin');

  return query select v_id, v_code;
end;
$$;

-- 招待コードでサークルに参加する。
-- 参加前は circles を select できない（RLS で弾かれる）ので、コードの照合も definer 側で行う
create or replace function public.join_circle(p_invite_code text, p_display_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
begin
  if v_uid is null then
    raise exception 'ログインが必要です';
  end if;
  if btrim(coalesce(p_display_name, '')) = '' then
    raise exception '自分の表示名を入力してください';
  end if;

  select c.id into v_id
    from public.circles c
   where c.invite_code = upper(btrim(coalesce(p_invite_code, '')));

  if v_id is null then
    raise exception '招待コードが違います';
  end if;

  insert into public.circle_members (circle_id, user_id, display_name)
  values (v_id, v_uid, btrim(p_display_name))
  on conflict (circle_id, user_id) do nothing;

  return v_id;
end;
$$;

-- ========== 保存用 RPC ==========
-- ライブ本体・曲・曲順・PA/照明メモを 1 トランザクションで保存する
-- p_live_id が null なら新規作成、あれば更新（曲順は作り直し）
-- security invoker なので、他サークルの ID を渡しても RLS で弾かれる
--
-- p_songs は jsonb の配列。曲名だけでなく PA・照明の設定メモも一緒に運ぶ必要があり、
-- text[] では 1 曲につき 1 つの値しか持てないため jsonb に変更した：
--   [{"title": "曲名", "pa_note": "EQ低音+2…", "lighting_note": "赤主体…"}, ...]

create or replace function public.save_live(
  p_live_id      uuid,
  p_circle_id    uuid,
  p_title        text,
  p_performed_on date,
  p_venue        text,
  p_band         text,
  p_songs        jsonb
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_live_id uuid;
  v_song    jsonb;
  v_title   text;
  v_pa      text;
  v_light   text;
  v_song_id uuid;
  v_pos     int := 0;
begin
  if auth.uid() is null then
    raise exception 'ログインが必要です';
  end if;
  if not public.is_circle_member(p_circle_id) then
    raise exception 'このサークルの部員ではありません';
  end if;

  if p_live_id is null then
    insert into public.lives (circle_id, created_by, title, performed_on, venue, band)
    values (
      p_circle_id,
      auth.uid(),
      btrim(p_title),
      p_performed_on,
      nullif(btrim(p_venue), ''),
      nullif(btrim(p_band), '')
    )
    returning id into v_live_id;
  else
    -- created_by は最初に登録した人のまま残す（編集で書き換えない）
    update public.lives
       set title = btrim(p_title),
           performed_on = p_performed_on,
           venue = nullif(btrim(p_venue), ''),
           band  = nullif(btrim(p_band), '')
     where id = p_live_id
       and circle_id = p_circle_id
    returning id into v_live_id;

    if v_live_id is null then
      raise exception 'ライブが見つかりません';
    end if;

    delete from public.setlist_items where live_id = v_live_id;
  end if;

  for v_song in select jsonb_array_elements(coalesce(p_songs, '[]'::jsonb)) loop
    v_title := btrim(coalesce(v_song->>'title', ''));
    continue when v_title = '';
    v_pa    := nullif(btrim(coalesce(v_song->>'pa_note', '')), '');
    v_light := nullif(btrim(coalesce(v_song->>'lighting_note', '')), '');

    insert into public.songs (circle_id, title) values (p_circle_id, v_title)
    on conflict (circle_id, title_key) do nothing;

    select id into v_song_id
      from public.songs
     where circle_id = p_circle_id and title_key = lower(v_title);

    v_pos := v_pos + 1;
    insert into public.setlist_items (live_id, position, song_id, circle_id, pa_note, lighting_note)
    values (v_live_id, v_pos, v_song_id, p_circle_id, v_pa, v_light);
  end loop;

  return v_live_id;
end;
$$;

-- ========== 実行権限 ==========
-- 未ログイン（anon）からは呼べないようにする

revoke execute on function public.generate_invite_code() from public, anon;
revoke execute on function public.create_circle(text, text) from public, anon;
revoke execute on function public.join_circle(text, text) from public, anon;
revoke execute on function public.save_live(uuid, uuid, text, date, text, text, jsonb) from public, anon;

grant execute on function public.is_circle_member(uuid) to authenticated;
grant execute on function public.is_circle_admin(uuid) to authenticated;
grant execute on function public.create_circle(text, text) to authenticated;
grant execute on function public.join_circle(text, text) to authenticated;
grant execute on function public.save_live(uuid, uuid, text, date, text, text, jsonb) to authenticated;

-- 追加マイグレーション：セキュリティの強化（2026-11）
--
-- すでに supabase/schema.sql を実行済みの Supabase プロジェクト向け。
-- 20261012_lighting_and_procedure.sql のあとに、SQL Editor に貼って実行する
-- （何度実行しても同じ結果になる）。
-- これから新しくプロジェクトを作る場合は schema.sql に同じ内容が入っているので、これは不要。
--
-- 内容
--   1. 招待コードを管理者が作り直せるようにする（外した部員の入り直し・コード漏れ対策）
--   2. 招待コードを暗号用の乱数で作る。直接の書き換えは禁止する
--   3. ライブの登録者（created_by）を偽れないようにする
--   4. 管理者が 1 人もいなくなる退部・降格を止める
--   5. 管理者が他の部員を管理者にできるようにする（引き継ぎ用）。書き換えられる列は絞る

-- 招待コードの生成。0/O、1/I のような紛らわしい文字は使わない。
-- 合言葉は推測されると困るので、random()（予測できる疑似乱数）ではなく
-- gen_random_uuid()（暗号用の乱数）のバイトから作る。文字は 32 種類で 256 を割り切れるので偏らない
create or replace function public.generate_invite_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes bytea;
  v_code  text;
begin
  for attempt in 1..20 loop
    v_bytes := uuid_send(gen_random_uuid());
    v_code := '';
    -- UUID の後ろ 6 バイト（10〜15 番目）は全ビットが乱数
    for i in 10..15 loop
      v_code := v_code || substr(v_alphabet, 1 + get_byte(v_bytes, i) % 32, 1);
    end loop;
    if not exists (select 1 from public.circles c where c.invite_code = v_code) then
      return v_code;
    end if;
  end loop;
  raise exception '招待コードを発行できませんでした。もう一度お試しください';
end;
$$;

-- 招待コードを作り直す（管理者だけ）。コードが部外に漏れたときや、外した部員に
-- 同じコードで入り直されたくないときに使う。古いコードはその場で使えなくなる
create or replace function public.regenerate_invite_code(p_circle_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if not public.is_circle_admin(p_circle_id) then
    raise exception '招待コードを作り直せるのは管理者だけです';
  end if;

  v_code := public.generate_invite_code();
  update public.circles set invite_code = v_code where id = p_circle_id;
  return v_code;
end;
$$;

-- 自分で自分を admin に昇格させられないようにする。
-- RLS のポリシーからは変更前の値（OLD）が見えないので、トリガーで比べる。
-- あわせて、管理者が 1 人もいなくなる変更（最後の管理者の降格）も止める
create or replace function public.guard_member_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role then
    if not public.is_circle_admin(old.circle_id) then
      raise exception '役割を変更できるのは管理者だけです';
    end if;
    if old.role = 'admin' and not exists (
      select 1 from public.circle_members m
       where m.circle_id = old.circle_id and m.role = 'admin' and m.user_id <> old.user_id
    ) then
      raise exception '管理者が 1 人だけのときは役割を外せません。先に他の部員を管理者にしてください';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists circle_members_guard_role on public.circle_members;
create trigger circle_members_guard_role
  before update on public.circle_members
  for each row execute function public.guard_member_role_change();

-- 最後の管理者が、他の部員を残したまま退部するのを止める（管理者不在になると
-- サークル名の変更・部員の削除・招待コードの作り直しが誰にもできなくなるため）。
-- 本人の退部だけが対象。ダッシュボードからのユーザー削除（auth.uid() が null）は止めない
create or replace function public.guard_last_admin_leave()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'admin'
     and old.user_id = (select auth.uid())
     and exists (select 1 from public.circle_members m
                  where m.circle_id = old.circle_id and m.user_id <> old.user_id)
     and not exists (select 1 from public.circle_members m
                      where m.circle_id = old.circle_id and m.role = 'admin'
                        and m.user_id <> old.user_id)
  then
    raise exception '管理者が自分だけのときは退部できません。先に他の部員を管理者にしてください';
  end if;
  return old;
end;
$$;

drop trigger if exists circle_members_guard_last_admin on public.circle_members;
create trigger circle_members_guard_last_admin
  before delete on public.circle_members
  for each row execute function public.guard_last_admin_leave();

-- ライブの登録者（created_by）を偽れないようにする。
-- 部員は lives を直接 insert / update できる（RLS は所属しか見ない）ので、そのままだと
-- 他人の名前で登録したり、登録者を書き換えたりできてしまう。
-- 新規は必ず「いまログインしている人」、更新では元の値のまま、に DB 側で固定する。
-- auth.uid() が null（SQL Editor・seed・退会時の set null）のときは何もしない
create or replace function public.guard_live_created_by()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.created_by := (select auth.uid());
  else
    new.created_by := old.created_by;
  end if;
  return new;
end;
$$;

drop trigger if exists lives_guard_created_by on public.lives;
create trigger lives_guard_created_by
  before insert or update on public.lives
  for each row execute function public.guard_live_created_by();

-- 管理者は部員の役割を変えられる（管理者の引き継ぎ用）。これが無いと管理者を増やせず、
-- 最後の管理者が退部できなくなる。変えられる列は下の「実行権限」で表示名と役割だけに絞る
drop policy if exists "管理者による部員の役割変更" on public.circle_members;
create policy "管理者による部員の役割変更" on public.circle_members
  for update to authenticated
  using (public.is_circle_admin(circle_id))
  with check (public.is_circle_admin(circle_id));

revoke execute on function public.generate_invite_code() from public, anon, authenticated;
revoke execute on function public.regenerate_invite_code(uuid) from public, anon;
grant execute on function public.regenerate_invite_code(uuid) to authenticated;

revoke update on public.circles from authenticated, anon;
grant update (name) on public.circles to authenticated;

-- circle_members で書き換えられる列を表示名と役割だけにする。
-- user_id / circle_id を書き換えて、本人の同意なく誰かを所属させることを防ぐ
revoke update on public.circle_members from authenticated, anon;
grant update (display_name, role) on public.circle_members to authenticated;

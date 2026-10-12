-- 追加マイグレーション：照明の色・明るさ、手順の欄を追加する（2026-10）
--
-- すでに supabase/schema.sql を実行済みの Supabase プロジェクト向け。
-- SQL Editor に貼って 1 回だけ実行する（2 回実行しても壊れないよう if not exists を付けてある）。
-- これから新しくプロジェクトを作る場合は schema.sql に同じ内容が入っているので、これは不要。

alter table public.setlist_items
  add column if not exists lighting_color text
    check (char_length(lighting_color) <= 50),
  add column if not exists lighting_brightness smallint
    check (lighting_brightness between 0 and 100),
  add column if not exists procedure_note text
    check (char_length(procedure_note) <= 500);

-- save_live を新しい列も保存する版に差し替える。
-- 引数の型は変えていないので create or replace で上書きされ、実行権限（grant）もそのまま残る
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
  v_color   text;
  v_bright  smallint;
  v_proc    text;
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
    v_pa     := nullif(btrim(coalesce(v_song->>'pa_note', '')), '');
    v_light  := nullif(btrim(coalesce(v_song->>'lighting_note', '')), '');
    v_color  := nullif(btrim(coalesce(v_song->>'lighting_color', '')), '');
    v_bright := nullif(btrim(coalesce(v_song->>'lighting_brightness', '')), '')::smallint;
    v_proc   := nullif(btrim(coalesce(v_song->>'procedure_note', '')), '');

    insert into public.songs (circle_id, title) values (p_circle_id, v_title)
    on conflict (circle_id, title_key) do nothing;

    select id into v_song_id
      from public.songs
     where circle_id = p_circle_id and title_key = lower(v_title);

    v_pos := v_pos + 1;
    insert into public.setlist_items (
      live_id, position, song_id, circle_id,
      pa_note, lighting_note, lighting_color, lighting_brightness, procedure_note
    )
    values (
      v_live_id, v_pos, v_song_id, p_circle_id,
      v_pa, v_light, v_color, v_bright, v_proc
    );
  end loop;

  return v_live_id;
end;
$$;

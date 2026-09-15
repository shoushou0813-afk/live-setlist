-- デモアカウント用のサンプルデータ
-- 1. ダッシュボードの Authentication > Users でデモユーザーを作成（Auto Confirm にチェック）
-- 2. 下の v_email をそのメールアドレスに書き換えて SQL Editor で実行
-- 何度実行しても同じ状態になるよう、最初にデモユーザーのデータを消してから入れる

do $$
declare
  v_email text := 'demo@example.com';
  v_uid   uuid;
  v_live  uuid;
  v_song  uuid;
  v_pos   int;
  v_title text;
  r       record;
begin
  select id into v_uid from auth.users where email = v_email;
  if v_uid is null then
    raise exception 'ユーザー % が見つかりません', v_email;
  end if;

  delete from public.lives where user_id = v_uid;
  delete from public.songs where user_id = v_uid;

  for r in
    select * from (values
      ('新歓ライブ',          date '2025-04-18', '学生会館ホール', array['Opening Jam','夜明けのバス','Blue Line','アンコール前']),
      ('学園祭ステージ',      date '2025-11-02', '中庭特設ステージ', array['夜明けのバス','Coffee & Rain','Blue Line','小さな灯','Opening Jam']),
      ('定期ライブ vol.1',    date '2026-02-14', '下北沢〇〇',     array['Coffee & Rain','夜明けのバス','ねじれ坂','Blue Line']),
      ('定期ライブ vol.2',    date '2026-06-20', '下北沢〇〇',     array['ねじれ坂','小さな灯','夜明けのバス','Summer Static','Blue Line'])
    ) as t(title, performed_on, venue, songs)
  loop
    insert into public.lives (user_id, title, performed_on, venue)
    values (v_uid, r.title, r.performed_on, r.venue)
    returning id into v_live;

    v_pos := 0;
    foreach v_title in array r.songs loop
      insert into public.songs (user_id, title) values (v_uid, v_title)
      on conflict (user_id, title_key) do nothing;
      select id into v_song from public.songs
       where user_id = v_uid and title_key = lower(btrim(v_title));
      v_pos := v_pos + 1;
      insert into public.setlist_items (live_id, position, song_id, user_id)
      values (v_live, v_pos, v_song, v_uid);
    end loop;
  end loop;
end $$;

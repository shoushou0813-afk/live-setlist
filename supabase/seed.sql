-- デモ用サークルのサンプルデータ
-- 1. ダッシュボードの Authentication > Users でデモユーザーを作成（Auto Confirm にチェック）
--    審査員用に 2 人作ると「共同編集」が伝わりやすい（1 人でも動く）
-- 2. 下の v_email1 / v_email2 を実際のメールアドレスに書き換えて SQL Editor で実行
-- 何度実行しても同じ状態になるよう、最初にデモサークルを消してから入れ直す

do $$
declare
  v_email1 text := 'demo@example.com';       -- デモ用の管理者
  v_email2 text := 'demo2@example.com';      -- 2 人目（存在しなければ黙って飛ばす）
  v_code   text := 'DEMO01';                 -- デモ用の固定招待コード
  v_uid1   uuid;
  v_uid2   uuid;
  v_circle uuid;
  v_live   uuid;
  v_song   uuid;
  v_pos    int;
  v_title  text;
  r        record;
begin
  select id into v_uid1 from auth.users where email = v_email1;
  if v_uid1 is null then
    raise exception 'ユーザー % が見つかりません。先に Authentication > Users で作成してください', v_email1;
  end if;
  select id into v_uid2 from auth.users where email = v_email2;

  -- 作り直し（lives と songs は circle の削除に追随して消える）
  delete from public.circles where invite_code = v_code;

  insert into public.circles (name, invite_code) values ('デモ軽音サークル', v_code)
  returning id into v_circle;

  insert into public.circle_members (circle_id, user_id, display_name, role)
  values (v_circle, v_uid1, 'デモ太郎', 'admin');

  if v_uid2 is not null then
    insert into public.circle_members (circle_id, user_id, display_name, role)
    values (v_circle, v_uid2, 'デモ花子', 'member');
  end if;

  for r in
    select * from (values
      ('新歓ライブ',       date '2025-04-18', '学生会館ホール',   'ゆうやけシグナル',
        array['Opening Jam','夜明けのバス','Blue Line','アンコール前']),
      ('学園祭ステージ',   date '2025-11-02', '中庭特設ステージ', 'ゆうやけシグナル',
        array['夜明けのバス','Coffee & Rain','Blue Line','小さな灯','Opening Jam']),
      ('定期ライブ vol.1', date '2026-02-14', '下北沢〇〇',       'ねむれない放課後',
        array['Coffee & Rain','夜明けのバス','ねじれ坂','Blue Line']),
      ('定期ライブ vol.2', date '2026-06-20', '下北沢〇〇',       'ねむれない放課後',
        array['ねじれ坂','小さな灯','夜明けのバス','Summer Static','Blue Line'])
    ) as t(title, performed_on, venue, band, songs)
  loop
    insert into public.lives (circle_id, created_by, title, performed_on, venue, band)
    values (
      v_circle,
      -- 2 人目がいれば交互に登録者を変えて、複数人で書き込んでいる様子を見せる
      case when v_uid2 is not null and r.band = 'ねむれない放課後' then v_uid2 else v_uid1 end,
      r.title, r.performed_on, r.venue, r.band
    )
    returning id into v_live;

    v_pos := 0;
    foreach v_title in array r.songs loop
      insert into public.songs (circle_id, title) values (v_circle, v_title)
      on conflict (circle_id, title_key) do nothing;

      select id into v_song
        from public.songs
       where circle_id = v_circle and title_key = lower(btrim(v_title));

      v_pos := v_pos + 1;
      insert into public.setlist_items (live_id, position, song_id, circle_id)
      values (v_live, v_pos, v_song, v_circle);
    end loop;
  end loop;

  raise notice 'デモサークルを作成しました（招待コード: %）', v_code;
end $$;

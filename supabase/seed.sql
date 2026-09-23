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
  v_pa     text;
  v_light  text;
  s        jsonb;
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

  -- songs は曲名・PA メモ・照明メモをまとめた jsonb 配列。
  -- 同じ曲でもライブごとに設定が違う想定なので、メモは曲ではなく各ライブの行に持たせている
  for r in
    select * from (values
      ('新歓ライブ', date '2025-04-18', '学生会館ホール', 'ゆうやけシグナル',
        '[
          {"title": "Opening Jam"},
          {"title": "夜明けのバス", "pa_note": "ボーカルは会場が狭いので控えめに", "lighting_note": "暖色系、間奏で暗転"},
          {"title": "Blue Line",    "pa_note": "EQ低音+2、コーラスに薄くディレイ", "lighting_note": "赤主体、サビで白フラッシュ"},
          {"title": "アンコール前"}
        ]'::jsonb),
      ('学園祭ステージ', date '2025-11-02', '中庭特設ステージ', 'ゆうやけシグナル',
        '[
          {"title": "夜明けのバス", "pa_note": "屋外なので低音を+3、モニター多めに返す"},
          {"title": "Coffee & Rain", "lighting_note": "青系でゆっくりフェード"},
          {"title": "Blue Line",    "pa_note": "屋外仕様。低音+2は変えず、全体を+3dB"},
          {"title": "小さな灯"},
          {"title": "Opening Jam"}
        ]'::jsonb),
      ('定期ライブ vol.1', date '2026-02-14', '下北沢〇〇', 'ねむれない放課後',
        '[
          {"title": "Coffee & Rain"},
          {"title": "夜明けのバス"},
          {"title": "ねじれ坂",     "pa_note": "ギターソロでディレイを深めに切り替え", "lighting_note": "ソロ中はスポット単色"},
          {"title": "Blue Line"}
        ]'::jsonb),
      ('定期ライブ vol.2', date '2026-06-20', '下北沢〇〇', 'ねむれない放課後',
        '[
          {"title": "ねじれ坂",     "pa_note": "前回と同じ設定。ソロ前にディレイ深め"},
          {"title": "小さな灯"},
          {"title": "夜明けのバス"},
          {"title": "Summer Static", "lighting_note": "夏らしく白と水色を交互に"},
          {"title": "Blue Line"}
        ]'::jsonb)
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
    for s in select jsonb_array_elements(r.songs) loop
      v_title := btrim(s->>'title');
      v_pa    := nullif(btrim(coalesce(s->>'pa_note', '')), '');
      v_light := nullif(btrim(coalesce(s->>'lighting_note', '')), '');

      insert into public.songs (circle_id, title) values (v_circle, v_title)
      on conflict (circle_id, title_key) do nothing;

      select id into v_song
        from public.songs
       where circle_id = v_circle and title_key = lower(v_title);

      v_pos := v_pos + 1;
      insert into public.setlist_items (live_id, position, song_id, circle_id, pa_note, lighting_note)
      values (v_live, v_pos, v_song, v_circle, v_pa, v_light);
    end loop;
  end loop;

  raise notice 'デモサークルを作成しました（招待コード: %）', v_code;
end $$;

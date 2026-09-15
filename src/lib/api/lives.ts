import { supabase } from '../supabase';
import { normalizeSongTitles } from '../setlist';

export type Live = {
  id: string;
  title: string;
  performedOn: string;
  venue: string | null;
  /** 曲順（position）どおりに並べ直した曲名 */
  songs: string[];
};

/**
 * ライブ一覧を日付の新しい順で取得する。
 * setlist_items と songs を同時に引いて、往復を 1 回で済ませる。
 * position の並びは返ってくる保証がないので、こちら側で並べ直してから返す。
 */
export async function fetchLives(): Promise<Live[]> {
  const { data, error } = await supabase
    .from('lives')
    .select('id, title, performed_on, venue, setlist_items(position, songs(title))')
    .order('performed_on', { ascending: false })
    .order('created_at', { ascending: false });

  if (error) throw error;

  return (data ?? []).map((live) => ({
    id: live.id,
    title: live.title,
    performedOn: live.performed_on,
    venue: live.venue,
    songs: [...live.setlist_items]
      .sort((a, b) => a.position - b.position)
      .map((item) => item.songs?.title ?? '')
      .filter((title) => title !== ''),
  }));
}

export type SaveLiveInput = {
  /** 新規なら null、更新なら対象のライブ ID */
  id: string | null;
  title: string;
  performedOn: string;
  venue: string;
  songs: string[];
};

/**
 * ライブ本体・曲・曲順をまとめて保存する。
 * setlist_items を個別に insert すると途中で失敗したときに半端なデータが残るため、
 * DB 側の関数 save_live（1 トランザクション）だけを呼ぶ。
 */
export async function saveLive(input: SaveLiveInput): Promise<string> {
  const { data, error } = await supabase.rpc('save_live', {
    p_live_id: input.id,
    p_title: input.title.trim(),
    p_performed_on: input.performedOn,
    p_venue: input.venue.trim(),
    p_songs: normalizeSongTitles(input.songs),
  });

  if (error) throw error;
  return data;
}

export async function deleteLive(id: string): Promise<void> {
  // setlist_items は on delete cascade で一緒に消える。曲（songs）は残す。
  const { error } = await supabase.from('lives').delete().eq('id', id);
  if (error) throw error;
}

import { supabase } from '../supabase';
import type { SongStat } from '../setlist';

/**
 * サークルの曲ごとの演奏回数・最終演奏日を取得する。
 * 集計はビュー song_stats（security_invoker = true）に任せ、
 * 全ライブを取ってきてブラウザで数える形にはしない。
 * サークル全員の記録がまとまるので「サークルで一番やっている曲」が出せる。
 */
export async function fetchSongStats(circleId: string): Promise<SongStat[]> {
  const { data, error } = await supabase
    .from('song_stats')
    .select('id, title, play_count, last_played_on')
    .eq('circle_id', circleId);

  if (error) throw error;

  return (data ?? [])
    .filter(
      (row): row is { id: string; title: string; play_count: number; last_played_on: string } =>
        row.id !== null &&
        row.title !== null &&
        row.play_count !== null &&
        row.last_played_on !== null,
    )
    .map((row) => ({
      id: row.id,
      title: row.title,
      playCount: row.play_count,
      lastPlayedOn: row.last_played_on,
    }));
}

export type LiveOfSong = {
  id: string;
  title: string;
  performedOn: string;
  venue: string | null;
};

/** ある曲を演奏したライブを新しい順で返す（曲一覧のタップで開く部分）。 */
export async function fetchLivesForSong(songId: string): Promise<LiveOfSong[]> {
  const { data, error } = await supabase
    .from('setlist_items')
    .select('lives(id, title, performed_on, venue)')
    .eq('song_id', songId);

  if (error) throw error;

  // 同じライブで同じ曲を 2 回演奏している場合は 2 行返るので、ライブ単位にまとめる
  const byLiveId = new Map<string, LiveOfSong>();
  for (const item of data ?? []) {
    const live = item.lives;
    if (!live) continue;
    byLiveId.set(live.id, {
      id: live.id,
      title: live.title,
      performedOn: live.performed_on,
      venue: live.venue,
    });
  }

  return [...byLiveId.values()].sort((a, b) => b.performedOn.localeCompare(a.performedOn));
}

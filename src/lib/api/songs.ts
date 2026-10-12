import { supabase } from '../supabase';
import { sortNewestFirst, type SongStat } from '../setlist';

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

/** ある曲を 1 回演奏した記録。そのときの PA・照明の設定と手順も持つ。 */
export type SongPerformance = {
  liveId: string;
  /** そのライブで何曲目だったか（同じライブで 2 回やった曲を区別する） */
  position: number;
  liveTitle: string;
  performedOn: string;
  venue: string | null;
  band: string | null;
  paNote: string | null;
  lightingColor: string | null;
  lightingBrightness: number | null;
  lightingNote: string | null;
  procedureNote: string | null;
};

/**
 * ある曲を演奏した記録を新しい順で返す（曲一覧のタップで開く部分）。
 * 「この曲、前はどうやった？」に答えられるよう、各回の PA・照明の設定と手順も一緒に取る。
 * 同じライブで 2 回演奏した場合は設定が別なので、ライブ単位にまとめず 1 回ずつ返す。
 */
export async function fetchSongHistory(songId: string): Promise<SongPerformance[]> {
  const { data, error } = await supabase
    .from('setlist_items')
    .select('position, pa_note, lighting_note, lighting_color, lighting_brightness, procedure_note, lives(id, title, performed_on, venue, band)')
    .eq('song_id', songId);

  if (error) throw error;

  const performances: SongPerformance[] = [];
  for (const item of data ?? []) {
    const live = item.lives;
    if (!live) continue;
    performances.push({
      liveId: live.id,
      position: item.position,
      liveTitle: live.title,
      performedOn: live.performed_on,
      venue: live.venue,
      band: live.band,
      paNote: item.pa_note,
      lightingColor: item.lighting_color,
      lightingBrightness: item.lighting_brightness,
      lightingNote: item.lighting_note,
      procedureNote: item.procedure_note,
    });
  }
  return sortNewestFirst(performances);
}

/**
 * セットリスト入力の整形と、曲一覧の絞り込み・並び替え。
 * Supabase にも React にも依存しない純粋関数だけを置き、Vitest で直接テストする。
 */

/** 曲名の配列を保存できる形に整える：前後の空白を除き、空行は捨てる。 */
export function normalizeSongTitles(titles: readonly string[]): string[] {
  return titles.map((title) => title.trim()).filter((title) => title !== '');
}

/** 「まとめて貼り付け」のテキストを 1 行 1 曲として配列にする。改行コードの違いも吸収する。 */
export function parseSongTitlesFromText(text: string): string[] {
  return normalizeSongTitles(text.split(/\r?\n/));
}

/** 曲名の配列を「まとめて貼り付け」のテキストに戻す（入力モードの切り替え用）。 */
export function songTitlesToText(titles: readonly string[]): string {
  return normalizeSongTitles(titles).join('\n');
}

/**
 * 同じ曲とみなすためのキー。前後の空白を除き、英字の大小を無視する。
 * DB 側の生成列 `songs.title_key`（lower(btrim(title))）と同じ規則にそろえてある。
 */
export function songTitleKey(title: string): string {
  return title.trim().toLowerCase();
}

export type LiveInput = {
  title: string;
  performedOn: string;
  venue: string;
  songs: string[];
};

export type ValidationError = { field: 'title' | 'performedOn'; message: string };

/** 保存前の入力チェック。DB の check 制約と同じ条件を画面側でも先に見て、往復を減らす。 */
export function validateLiveInput(input: LiveInput): ValidationError | null {
  const title = input.title.trim();
  if (title === '') {
    return { field: 'title', message: 'ライブ名を入力してください。' };
  }
  if (title.length > 100) {
    return { field: 'title', message: 'ライブ名は100文字までです。' };
  }
  if (input.performedOn === '') {
    return { field: 'performedOn', message: '日付を入力してください。' };
  }
  return null;
}

export type SongStat = {
  id: string;
  title: string;
  playCount: number;
  lastPlayedOn: string;
};

export type SongSort = 'count' | 'last' | 'name';

/** 曲名での絞り込み。大小文字は無視する。 */
export function filterSongs(songs: readonly SongStat[], query: string): SongStat[] {
  const keyword = query.trim().toLowerCase();
  if (keyword === '') return [...songs];
  return songs.filter((song) => song.title.toLowerCase().includes(keyword));
}

/** 並び替え。同点のときは曲名順にして、並びが毎回変わらないようにする。 */
export function sortSongs(songs: readonly SongStat[], sort: SongSort): SongStat[] {
  const byName = (a: SongStat, b: SongStat) => a.title.localeCompare(b.title, 'ja');
  const sorted = [...songs];
  switch (sort) {
    case 'count':
      return sorted.sort((a, b) => b.playCount - a.playCount || byName(a, b));
    case 'last':
      return sorted.sort((a, b) => b.lastPlayedOn.localeCompare(a.lastPlayedOn) || byName(a, b));
    case 'name':
      return sorted.sort(byName);
  }
}

/** 演奏回数バーの基準になる最大値。0 で割らないよう最低 1 を返す。 */
export function maxPlayCount(songs: readonly SongStat[]): number {
  return Math.max(1, ...songs.map((song) => song.playCount));
}

/** 日付（YYYY-MM-DD）を画面表示用の「2026/02/14」にする。 */
export function formatDate(isoDate: string): string {
  return isoDate.split('-').join('/');
}

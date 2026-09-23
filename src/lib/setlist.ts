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

/**
 * 「1曲ずつ」モードで扱う 1 曲分の入力。
 * PA・照明の設定メモは、同じ曲でも会場や機材でやり方が変わるため曲マスタではなく
 * 「このライブのこの曲」単位（＝この入力）で持つ。
 */
export type SetlistSongInput = {
  title: string;
  /** PA 班向けの音響設定メモ（任意） */
  paNote: string;
  /** 照明班向けの設定メモ（任意） */
  lightingNote: string;
};

/** 空欄の曲入力を 1 件作る（「＋ 曲を追加」ボタン用）。 */
export function emptySetlistSong(): SetlistSongInput {
  return { title: '', paNote: '', lightingNote: '' };
}

/** 「まとめて貼り付け」で取り込んだ曲名から、メモが空の曲入力を作る。 */
export function setlistSongsFromTitles(titles: readonly string[]): SetlistSongInput[] {
  return normalizeSongTitles(titles).map((title) => ({ title, paNote: '', lightingNote: '' }));
}

/**
 * 曲の配列を保存できる形に整える：前後の空白を除き、曲名が空の行は捨てる。
 * 曲名の重複除去はしない（同じライブで同じ曲を 2 回演奏することがあるため）。
 */
export function normalizeSetlistSongs(songs: readonly SetlistSongInput[]): SetlistSongInput[] {
  return songs
    .map((song) => ({
      title: song.title.trim(),
      paNote: song.paNote.trim(),
      lightingNote: song.lightingNote.trim(),
    }))
    .filter((song) => song.title !== '');
}

export type SongValidationError = { message: string };

/** 曲ごとの PA・照明メモのチェック。DB の check 制約（300 文字まで）と同じ条件を画面側でも先に見る。 */
export function validateSetlistSongs(
  songs: readonly SetlistSongInput[],
): SongValidationError | null {
  for (const song of normalizeSetlistSongs(songs)) {
    if (song.paNote.length > 300) {
      return { message: `「${song.title}」のPAメモは300文字までです。` };
    }
    if (song.lightingNote.length > 300) {
      return { message: `「${song.title}」の照明メモは300文字までです。` };
    }
  }
  return null;
}

export type LiveInput = {
  title: string;
  performedOn: string;
  venue: string;
  /** 出演バンド名（任意） */
  band: string;
  songs: SetlistSongInput[];
};

export type ValidationError = {
  field: 'title' | 'performedOn' | 'band' | 'songs';
  message: string;
};

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
  if (input.band.trim().length > 100) {
    return { field: 'band', message: 'バンド名は100文字までです。' };
  }
  const songError = validateSetlistSongs(input.songs);
  if (songError) {
    return { field: 'songs', message: songError.message };
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

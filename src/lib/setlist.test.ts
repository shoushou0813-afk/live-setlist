import { describe, expect, it } from 'vitest';
import {
  emptySetlistSong,
  filterSongs,
  formatDate,
  maxPlayCount,
  normalizeSetlistSongs,
  normalizeSongTitles,
  parseSongTitlesFromText,
  setlistSongsFromTitles,
  songTitleKey,
  songTitlesToText,
  sortSongs,
  validateLiveInput,
  validateSetlistSongs,
  type SetlistSongInput,
  type SongStat,
} from './setlist';

describe('normalizeSongTitles', () => {
  it('前後の空白を除き、空文字を捨てる', () => {
    expect(normalizeSongTitles(['  夜明けのバス ', '', '   ', 'Blue Line'])).toEqual([
      '夜明けのバス',
      'Blue Line',
    ]);
  });

  it('同じ曲を 2 回演奏した場合は重複を残す（1 ライブで 2 回やる曲があるため）', () => {
    expect(normalizeSongTitles(['Blue Line', 'Blue Line'])).toEqual(['Blue Line', 'Blue Line']);
  });
});

describe('parseSongTitlesFromText', () => {
  it('1 行 1 曲として読み、空行を無視する', () => {
    expect(parseSongTitlesFromText('曲A\n\n  曲B  \n')).toEqual(['曲A', '曲B']);
  });

  it('CRLF の改行でも同じ結果になる', () => {
    expect(parseSongTitlesFromText('曲A\r\n曲B')).toEqual(['曲A', '曲B']);
  });

  it('空文字なら空配列', () => {
    expect(parseSongTitlesFromText('')).toEqual([]);
  });
});

describe('songTitlesToText', () => {
  it('入力モードを往復しても中身が変わらない', () => {
    const text = songTitlesToText(['曲A', '', ' 曲B ']);
    expect(text).toBe('曲A\n曲B');
    expect(parseSongTitlesFromText(text)).toEqual(['曲A', '曲B']);
  });
});

describe('songTitleKey', () => {
  it('前後の空白と英字の大小を無視する（DB の title_key と同じ規則）', () => {
    expect(songTitleKey('  Blue Line ')).toBe('blue line');
    expect(songTitleKey('BLUE LINE')).toBe(songTitleKey('blue line'));
  });

  it('表記ゆれは別の曲として扱う', () => {
    expect(songTitleKey('Blue Line')).not.toBe(songTitleKey('Blue Line ver.2'));
  });
});

describe('emptySetlistSong', () => {
  it('曲名・PAメモ・照明メモがすべて空の曲を作る', () => {
    expect(emptySetlistSong()).toEqual({ title: '', paNote: '', lightingNote: '' });
  });
});

describe('setlistSongsFromTitles', () => {
  it('曲名からメモが空の曲入力を作る（空行・前後空白は除く）', () => {
    expect(setlistSongsFromTitles(['  Blue Line ', '', '夜明けのバス'])).toEqual([
      { title: 'Blue Line', paNote: '', lightingNote: '' },
      { title: '夜明けのバス', paNote: '', lightingNote: '' },
    ]);
  });
});

describe('normalizeSetlistSongs', () => {
  it('前後の空白を除き、曲名が空の行は捨てる（メモが入っていても捨てる）', () => {
    const songs: SetlistSongInput[] = [
      { title: '  Blue Line ', paNote: ' EQ低音+2 ', lightingNote: '' },
      { title: '   ', paNote: '曲名が無いので消えるはず', lightingNote: '' },
    ];
    expect(normalizeSetlistSongs(songs)).toEqual([
      { title: 'Blue Line', paNote: 'EQ低音+2', lightingNote: '' },
    ]);
  });

  it('同じ曲を 2 回演奏した場合は重複を残す', () => {
    const songs: SetlistSongInput[] = [
      { title: 'Blue Line', paNote: '1回目', lightingNote: '' },
      { title: 'Blue Line', paNote: '2回目', lightingNote: '' },
    ];
    expect(normalizeSetlistSongs(songs)).toHaveLength(2);
  });
});

describe('validateSetlistSongs', () => {
  it('メモが 300 文字以内なら null', () => {
    const songs: SetlistSongInput[] = [
      { title: '曲A', paNote: 'あ'.repeat(300), lightingNote: 'い'.repeat(300) },
    ];
    expect(validateSetlistSongs(songs)).toBeNull();
  });

  it('PAメモが 300 文字を超えるとエラー（DB の check 制約と同じ）', () => {
    const songs: SetlistSongInput[] = [
      { title: '曲A', paNote: 'あ'.repeat(301), lightingNote: '' },
    ];
    expect(validateSetlistSongs(songs)?.message).toContain('曲A');
  });

  it('照明メモが 300 文字を超えるとエラー', () => {
    const songs: SetlistSongInput[] = [
      { title: '曲A', paNote: '', lightingNote: 'い'.repeat(301) },
    ];
    expect(validateSetlistSongs(songs)?.message).toContain('照明メモ');
  });

  it('曲名が空の行はチェックしない（保存時に捨てられるため）', () => {
    const songs: SetlistSongInput[] = [{ title: '', paNote: 'あ'.repeat(301), lightingNote: '' }];
    expect(validateSetlistSongs(songs)).toBeNull();
  });
});

describe('validateLiveInput', () => {
  const base = { title: '定期ライブ', performedOn: '2026-02-14', venue: '', band: '', songs: [] };

  it('必須が埋まっていれば null', () => {
    expect(validateLiveInput(base)).toBeNull();
  });

  it('ライブ名が空白だけならエラー', () => {
    expect(validateLiveInput({ ...base, title: '   ' })).toEqual({
      field: 'title',
      message: 'ライブ名を入力してください。',
    });
  });

  it('ライブ名が 100 文字を超えるとエラー（DB の check 制約と同じ）', () => {
    expect(validateLiveInput({ ...base, title: 'あ'.repeat(101) })?.field).toBe('title');
    expect(validateLiveInput({ ...base, title: 'あ'.repeat(100) })).toBeNull();
  });

  it('日付が空ならエラー', () => {
    expect(validateLiveInput({ ...base, performedOn: '' })?.field).toBe('performedOn');
  });

  it('バンド名が 100 文字を超えるとエラー（DB の check 制約と同じ）', () => {
    expect(validateLiveInput({ ...base, band: 'あ'.repeat(101) })?.field).toBe('band');
    expect(validateLiveInput({ ...base, band: 'あ'.repeat(100) })).toBeNull();
  });

  it('曲の PA メモが 300 文字を超えるとエラー（songs フィールドとして返る）', () => {
    const songs: SetlistSongInput[] = [
      { title: '曲A', paNote: 'あ'.repeat(301), lightingNote: '' },
    ];
    expect(validateLiveInput({ ...base, songs })?.field).toBe('songs');
  });
});

const songs: SongStat[] = [
  { id: '1', title: '夜明けのバス', playCount: 4, lastPlayedOn: '2026-06-20' },
  { id: '2', title: 'Blue Line', playCount: 4, lastPlayedOn: '2026-06-20' },
  { id: '3', title: 'Coffee & Rain', playCount: 2, lastPlayedOn: '2026-02-14' },
  { id: '4', title: 'Summer Static', playCount: 1, lastPlayedOn: '2026-06-20' },
];

describe('filterSongs', () => {
  it('空の検索語なら全件', () => {
    expect(filterSongs(songs, '   ')).toHaveLength(4);
  });

  it('大小文字を無視して部分一致する', () => {
    expect(filterSongs(songs, 'blue').map((s) => s.title)).toEqual(['Blue Line']);
  });

  it('日本語でも部分一致する', () => {
    expect(filterSongs(songs, 'バス').map((s) => s.title)).toEqual(['夜明けのバス']);
  });

  it('元の配列を書き換えない', () => {
    const before = [...songs];
    filterSongs(songs, 'blue');
    expect(songs).toEqual(before);
  });
});

describe('sortSongs', () => {
  it('演奏回数順。同数なら曲名順で安定させる', () => {
    expect(sortSongs(songs, 'count').map((s) => s.title)).toEqual([
      'Blue Line',
      '夜明けのバス',
      'Coffee & Rain',
      'Summer Static',
    ]);
  });

  it('最近やった順', () => {
    expect(sortSongs(songs, 'last')[3].title).toBe('Coffee & Rain');
  });

  it('曲名順', () => {
    expect(sortSongs(songs, 'name').map((s) => s.title)).toEqual([
      'Blue Line',
      'Coffee & Rain',
      'Summer Static',
      '夜明けのバス',
    ]);
  });

  it('元の配列を書き換えない', () => {
    const before = [...songs];
    sortSongs(songs, 'name');
    expect(songs).toEqual(before);
  });
});

describe('maxPlayCount', () => {
  it('最大の演奏回数を返す', () => {
    expect(maxPlayCount(songs)).toBe(4);
  });

  it('曲が 0 件でも 1 を返す（バーの幅計算で 0 除算しないため）', () => {
    expect(maxPlayCount([])).toBe(1);
  });
});

describe('formatDate', () => {
  it('YYYY-MM-DD を YYYY/MM/DD にする', () => {
    expect(formatDate('2026-02-14')).toBe('2026/02/14');
  });
});

import { useState, useEffect, useMemo } from "react";
import { Plus, Trash2, X, Search } from "lucide-react";

const KEY = "live-setlist-data";
const uid = () => Math.random().toString(36).slice(2, 10);

export default function App() {
  const [lives, setLives] = useState([]);
  const [loaded, setLoaded] = useState(false);
  const [tab, setTab] = useState("songs");
  const [editing, setEditing] = useState(null);
  const [openLive, setOpenLive] = useState(null);
  const [q, setQ] = useState("");
  const [sort, setSort] = useState("count");
  const [openSong, setOpenSong] = useState(null);

  useEffect(() => {
    (async () => {
      try {
        const r = await window.storage.get(KEY, false);
        if (r) setLives(JSON.parse(r.value));
      } catch (e) {}
      setLoaded(true);
    })();
  }, []);

  const save = async (next) => {
    setLives(next);
    try { await window.storage.set(KEY, JSON.stringify(next), false); } catch (e) { console.error(e); }
  };

  const sortedLives = useMemo(() => [...lives].sort((a, b) => b.date.localeCompare(a.date)), [lives]);

  const songs = useMemo(() => {
    const map = {};
    for (const l of lives) {
      for (const s of l.songs) {
        const k = s.trim().toLowerCase();
        if (!k) continue;
        if (!map[k]) map[k] = { name: s.trim(), lives: [] };
        map[k].lives.push(l);
      }
    }
    let arr = Object.values(map).map((x) => ({
      ...x,
      count: x.lives.length,
      last: x.lives.map((l) => l.date).sort().at(-1),
    }));
    if (q) arr = arr.filter((x) => x.name.toLowerCase().includes(q.toLowerCase()));
    if (sort === "count") arr.sort((a, b) => b.count - a.count || a.name.localeCompare(b.name, "ja"));
    if (sort === "name") arr.sort((a, b) => a.name.localeCompare(b.name, "ja"));
    if (sort === "last") arr.sort((a, b) => b.last.localeCompare(a.last));
    return arr;
  }, [lives, q, sort]);

  const saveLive = (live) => {
    const exists = lives.some((l) => l.id === live.id);
    save(exists ? lives.map((l) => (l.id === live.id ? live : l)) : [...lives, live]);
    setEditing(null);
  };

  const removeLive = (id) => {
    if (!confirm("このライブを削除しますか？")) return;
    save(lives.filter((l) => l.id !== id));
    setOpenLive(null);
  };

  const maxCount = Math.max(1, ...songs.map((s) => s.count));

  return (
    <div className="app">
      <style>{css}</style>
      <header>
        <h1>演奏した曲</h1>
        <p className="sub">{lives.length}本のライブ ／ {Object.keys(Object.fromEntries(lives.flatMap(l => l.songs.map(s => [s.trim().toLowerCase(), 1])))).length}曲</p>
        <nav>
          <button className={tab === "songs" ? "on" : ""} onClick={() => setTab("songs")}>曲一覧</button>
          <button className={tab === "lives" ? "on" : ""} onClick={() => setTab("lives")}>ライブ</button>
        </nav>
      </header>

      {!loaded && <p className="empty">読み込み中…</p>}

      {loaded && tab === "songs" && (
        <section>
          <div className="tools">
            <label className="search">
              <Search size={16} />
              <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="曲名で探す" />
            </label>
            <select value={sort} onChange={(e) => setSort(e.target.value)}>
              <option value="count">演奏回数順</option>
              <option value="last">最近やった順</option>
              <option value="name">曲名順</option>
            </select>
          </div>
          {songs.length === 0 ? (
            <p className="empty">まだ曲がありません。「ライブ」タブからセットリストを追加してください。</p>
          ) : (
            <ul className="songs">
              {songs.map((s) => (
                <li key={s.name}>
                  <button className="songrow" onClick={() => setOpenSong(openSong === s.name ? null : s.name)}>
                    <span className="sname">{s.name}</span>
                    <span className="bar"><span style={{ width: `${(s.count / maxCount) * 100}%` }} /></span>
                    <span className="cnt">{s.count}回</span>
                  </button>
                  {openSong === s.name && (
                    <ul className="where">
                      {[...s.lives].sort((a, b) => b.date.localeCompare(a.date)).map((l) => (
                        <li key={l.id}><span className="d">{l.date}</span>{l.title}{l.venue && `（${l.venue}）`}</li>
                      ))}
                    </ul>
                  )}
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      {loaded && tab === "lives" && (
        <section>
          <button className="add" onClick={() => setEditing({ id: uid(), title: "", date: new Date().toISOString().slice(0, 10), venue: "", songs: [""] })}>
            <Plus size={18} /> ライブを追加
          </button>
          {sortedLives.length === 0 && <p className="empty">最初のライブを追加すると、ここに並びます。</p>}
          <div className="sheets">
            {sortedLives.map((l) => (
              <article key={l.id} className="sheet" onClick={() => setOpenLive(openLive === l.id ? null : l.id)}>
                <div className="tape" />
                <div className="d">{l.date}</div>
                <h2>{l.title || "無題のライブ"}</h2>
                {l.venue && <div className="venue">{l.venue}</div>}
                {openLive === l.id ? (
                  <>
                    <ol>{l.songs.filter(Boolean).map((s, i) => <li key={i}>{s}</li>)}</ol>
                    <div className="row" onClick={(e) => e.stopPropagation()}>
                      <button onClick={() => setEditing({ ...l, songs: [...l.songs] })}>編集</button>
                      <button className="danger" onClick={() => removeLive(l.id)}><Trash2 size={14} /> 削除</button>
                    </div>
                  </>
                ) : (
                  <div className="venue">{l.songs.filter(Boolean).length}曲 ・ タップで開く</div>
                )}
              </article>
            ))}
          </div>
        </section>
      )}

      {editing && <Editor live={editing} onCancel={() => setEditing(null)} onSave={saveLive} />}
    </div>
  );
}

function Editor({ live, onCancel, onSave }) {
  const [l, setL] = useState(live);
  const [bulk, setBulk] = useState(false);
  const [text, setText] = useState(live.songs.filter(Boolean).join("\n"));
  const setSong = (i, v) => setL({ ...l, songs: l.songs.map((s, j) => (j === i ? v : s)) });
  const move = (i, d) => {
    const s = [...l.songs]; const j = i + d;
    if (j < 0 || j >= s.length) return;
    [s[i], s[j]] = [s[j], s[i]]; setL({ ...l, songs: s });
  };
  const done = () => {
    const songs = (bulk ? text.split("\n") : l.songs).map((s) => s.trim()).filter(Boolean);
    onSave({ ...l, songs });
  };
  return (
    <div className="modal">
      <div className="panel">
        <div className="phead"><h3>セットリスト</h3><button onClick={onCancel} aria-label="閉じる"><X size={20} /></button></div>
        <label>ライブ名<input value={l.title} onChange={(e) => setL({ ...l, title: e.target.value })} placeholder="例：定期ライブ vol.3" /></label>
        <div className="two">
          <label>日付<input type="date" value={l.date} onChange={(e) => setL({ ...l, date: e.target.value })} /></label>
          <label>会場<input value={l.venue} onChange={(e) => setL({ ...l, venue: e.target.value })} placeholder="例：下北沢〇〇" /></label>
        </div>
        <div className="mode">
          <button className={!bulk ? "on" : ""} onClick={() => { setL({ ...l, songs: text.split("\n").concat(text ? [] : [""]) }); setBulk(false); }}>1曲ずつ</button>
          <button className={bulk ? "on" : ""} onClick={() => { setText(l.songs.filter(Boolean).join("\n")); setBulk(true); }}>まとめて貼り付け</button>
        </div>
        {bulk ? (
          <textarea rows={8} value={text} onChange={(e) => setText(e.target.value)} placeholder={"1行に1曲\n曲名A\n曲名B"} />
        ) : (
          <ol className="edit">
            {l.songs.map((s, i) => (
              <li key={i}>
                <input value={s} onChange={(e) => setSong(i, e.target.value)} placeholder={`${i + 1}曲目`} />
                <button onClick={() => move(i, -1)} aria-label="上へ">↑</button>
                <button onClick={() => move(i, 1)} aria-label="下へ">↓</button>
                <button onClick={() => setL({ ...l, songs: l.songs.filter((_, j) => j !== i) })} aria-label="削除"><X size={14} /></button>
              </li>
            ))}
            <button className="more" onClick={() => setL({ ...l, songs: [...l.songs, ""] })}><Plus size={14} /> 曲を追加</button>
          </ol>
        )}
        <button className="savebtn" onClick={done}>保存する</button>
      </div>
    </div>
  );
}

const css = `
@import url('https://fonts.googleapis.com/css2?family=Zen+Kaku+Gothic+New:wght@400;700;900&family=Klee+One:wght@600&display=swap');
.app{--stage:#1f2a44;--stage2:#2b3a5c;--paper:#f3f5f8;--ink:#1c2233;--tape:#e8c547;--mute:#8d9ab5;--warn:#c8553d;
  min-height:100vh;background:var(--stage);color:var(--paper);font-family:'Zen Kaku Gothic New',sans-serif;padding:24px 16px 60px;}
.app *{box-sizing:border-box}
header{max-width:720px;margin:0 auto 20px}
h1{font-size:40px;font-weight:900;margin:0;letter-spacing:.02em;line-height:1.1}
.sub{color:var(--mute);margin:6px 0 16px;font-size:14px}
nav{display:flex;gap:4px;border-bottom:2px solid var(--stage2)}
nav button{background:none;border:0;color:var(--mute);font:inherit;font-weight:700;padding:10px 14px;cursor:pointer;border-bottom:3px solid transparent;margin-bottom:-2px}
nav button.on{color:var(--paper);border-color:var(--tape)}
section{max-width:720px;margin:0 auto}
button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{outline:2px solid var(--tape);outline-offset:2px}
.tools{display:flex;gap:8px;margin-bottom:14px}
.search{flex:1;display:flex;align-items:center;gap:6px;background:var(--stage2);border-radius:8px;padding:0 10px;color:var(--mute)}
.search input{flex:1;background:none;border:0;color:var(--paper);font:inherit;padding:10px 0;outline:none}
select{background:var(--stage2);color:var(--paper);border:0;border-radius:8px;padding:0 10px;font:inherit}
.empty{color:var(--mute);padding:30px 0;text-align:center}
.songs{list-style:none;margin:0;padding:0}
.songs>li{border-bottom:1px solid var(--stage2)}
.songrow{width:100%;display:grid;grid-template-columns:1fr 80px 44px;gap:12px;align-items:center;background:none;border:0;color:inherit;font:inherit;padding:12px 2px;cursor:pointer;text-align:left}
.sname{font-weight:700;font-size:17px}
.bar{height:6px;background:var(--stage2);border-radius:3px;overflow:hidden}
.bar span{display:block;height:100%;background:var(--tape)}
.cnt{text-align:right;color:var(--mute);font-size:14px}
.where{list-style:none;padding:0 0 12px 12px;margin:0;font-size:14px;color:#c5cde0}
.where li{padding:3px 0}
.d{color:var(--mute);font-size:13px;margin-right:8px;font-variant-numeric:tabular-nums}
.add{display:flex;align-items:center;gap:6px;background:var(--tape);color:var(--ink);border:0;border-radius:8px;padding:10px 16px;font:inherit;font-weight:700;cursor:pointer;margin-bottom:20px}
.sheets{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:22px}
.sheet{position:relative;background:var(--paper);color:var(--ink);padding:24px 18px 16px;cursor:pointer;transform:rotate(-.6deg)}
.sheet:nth-child(even){transform:rotate(.7deg)}
.tape{position:absolute;top:-9px;left:50%;width:70px;height:20px;margin-left:-35px;background:var(--tape);opacity:.9}
.sheet h2{font-family:'Klee One',cursive;font-size:22px;margin:2px 0 4px;line-height:1.3}
.sheet .venue{font-size:13px;color:#5b6479}
.sheet ol{font-family:'Klee One',cursive;font-size:18px;margin:12px 0;padding-left:26px;line-height:1.7}
.row{display:flex;gap:8px;margin-top:8px}
.row button{flex:1;display:flex;align-items:center;justify-content:center;gap:4px;border:1.5px solid var(--ink);background:none;border-radius:6px;padding:6px;font:inherit;font-size:13px;cursor:pointer;color:var(--ink)}
.row .danger{border-color:var(--warn);color:var(--warn)}
.modal{position:fixed;inset:0;background:rgba(10,15,28,.7);display:flex;align-items:flex-end;justify-content:center;z-index:10}
.panel{background:var(--paper);color:var(--ink);width:100%;max-width:560px;max-height:92vh;overflow:auto;border-radius:14px 14px 0 0;padding:18px}
@media(min-width:600px){.modal{align-items:center}.panel{border-radius:14px}}
.phead{display:flex;justify-content:space-between;align-items:center}
.phead h3{margin:0;font-size:20px}
.phead button{background:none;border:0;cursor:pointer;color:var(--ink)}
.panel label{display:block;font-size:13px;font-weight:700;margin-top:12px}
.panel input,.panel textarea{display:block;width:100%;margin-top:4px;border:1.5px solid #c9cfdb;border-radius:6px;padding:8px;font:inherit;font-weight:400;background:#fff;color:var(--ink)}
.two{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.mode{display:flex;margin:16px 0 8px;border:1.5px solid var(--ink);border-radius:6px;overflow:hidden}
.mode button{flex:1;background:none;border:0;padding:7px;font:inherit;font-size:13px;cursor:pointer;color:var(--ink)}
.mode button.on{background:var(--ink);color:var(--paper)}
.edit{padding-left:22px;margin:0}
.edit li{margin-bottom:6px}
.edit li{display:list-item}
.edit li>*{vertical-align:middle}
.edit input{display:inline-block;width:calc(100% - 96px);margin:0}
.edit li button{width:28px;height:32px;margin-left:4px;border:0;background:#e2e6ee;border-radius:5px;cursor:pointer;color:var(--ink)}
.more{display:flex;align-items:center;gap:4px;background:none;border:1.5px dashed #9aa3b5;border-radius:6px;padding:6px 10px;font:inherit;font-size:13px;cursor:pointer;margin:6px 0 0 -22px;color:var(--ink)}
.savebtn{width:100%;margin-top:18px;background:var(--stage);color:var(--paper);border:0;border-radius:8px;padding:12px;font:inherit;font-weight:700;cursor:pointer}
@media(prefers-reduced-motion:reduce){*{transition:none!important}}
`;

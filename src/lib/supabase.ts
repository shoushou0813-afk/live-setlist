import { createClient } from '@supabase/supabase-js';
import type { Database } from '../types/database';

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

// 環境変数の設定漏れは「画面が真っ白で原因不明」になりがちなので、
// 起動時点で何をどうすればいいかまで書いた例外にして落とす。
if (!url || !anonKey) {
  throw new Error(
    '環境変数が設定されていません。.env.example をコピーして .env.local を作り、' +
      'Supabase の Project Settings > API にある URL と anon key を ' +
      'VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY に設定してから開発サーバーを起動し直してください。',
  );
}

export const supabase = createClient<Database>(url, anonKey);

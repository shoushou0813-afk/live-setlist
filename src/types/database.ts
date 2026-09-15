/**
 * Supabase の型定義。
 *
 * 本来は自動生成する（Supabase プロジェクトを作ったら必ず生成し直してこのファイルを置き換える）:
 *   npx supabase gen types typescript --project-id <project-id> > src/types/database.ts
 *
 * まだプロジェクトが無い段階では開発を止めないよう、supabase/schema.sql と同じ形を
 * 生成結果と同じ書式で手書きしてある。スキーマを変えたら生成し直すこと。
 */

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  public: {
    Tables: {
      lives: {
        Row: {
          id: string;
          user_id: string;
          title: string;
          performed_on: string;
          venue: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id?: string;
          title: string;
          performed_on: string;
          venue?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          title?: string;
          performed_on?: string;
          venue?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      songs: {
        Row: {
          id: string;
          user_id: string;
          title: string;
          title_key: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          user_id?: string;
          title: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          title?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      setlist_items: {
        Row: {
          live_id: string;
          position: number;
          song_id: string;
          user_id: string;
        };
        Insert: {
          live_id: string;
          position: number;
          song_id: string;
          user_id?: string;
        };
        Update: {
          live_id?: string;
          position?: number;
          song_id?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'setlist_items_live_id_fkey';
            columns: ['live_id'];
            isOneToOne: false;
            referencedRelation: 'lives';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'setlist_items_song_id_fkey';
            columns: ['song_id'];
            isOneToOne: false;
            referencedRelation: 'songs';
            referencedColumns: ['id'];
          },
        ];
      };
    };
    Views: {
      song_stats: {
        Row: {
          id: string | null;
          title: string | null;
          play_count: number | null;
          last_played_on: string | null;
        };
        Relationships: [];
      };
    };
    Functions: {
      save_live: {
        Args: {
          p_live_id: string | null;
          p_title: string;
          p_performed_on: string;
          p_venue: string | null;
          p_songs: string[];
        };
        Returns: string;
      };
    };
    Enums: Record<never, never>;
    CompositeTypes: Record<never, never>;
  };
};

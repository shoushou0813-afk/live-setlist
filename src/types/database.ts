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
      circles: {
        Row: {
          id: string;
          name: string;
          invite_code: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          invite_code: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          invite_code?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      circle_members: {
        Row: {
          circle_id: string;
          user_id: string;
          display_name: string;
          role: string;
          joined_at: string;
        };
        Insert: {
          circle_id: string;
          user_id?: string;
          display_name: string;
          role?: string;
          joined_at?: string;
        };
        Update: {
          circle_id?: string;
          user_id?: string;
          display_name?: string;
          role?: string;
          joined_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'circle_members_circle_id_fkey';
            columns: ['circle_id'];
            isOneToOne: false;
            referencedRelation: 'circles';
            referencedColumns: ['id'];
          },
        ];
      };
      lives: {
        Row: {
          id: string;
          circle_id: string;
          created_by: string | null;
          title: string;
          performed_on: string;
          venue: string | null;
          band: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          circle_id: string;
          created_by?: string | null;
          title: string;
          performed_on: string;
          venue?: string | null;
          band?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          circle_id?: string;
          created_by?: string | null;
          title?: string;
          performed_on?: string;
          venue?: string | null;
          band?: string | null;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'lives_circle_id_fkey';
            columns: ['circle_id'];
            isOneToOne: false;
            referencedRelation: 'circles';
            referencedColumns: ['id'];
          },
        ];
      };
      songs: {
        Row: {
          id: string;
          circle_id: string;
          title: string;
          title_key: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          circle_id: string;
          title: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          circle_id?: string;
          title?: string;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'songs_circle_id_fkey';
            columns: ['circle_id'];
            isOneToOne: false;
            referencedRelation: 'circles';
            referencedColumns: ['id'];
          },
        ];
      };
      setlist_items: {
        Row: {
          live_id: string;
          position: number;
          song_id: string;
          circle_id: string;
          pa_note: string | null;
          lighting_note: string | null;
        };
        Insert: {
          live_id: string;
          position: number;
          song_id: string;
          circle_id: string;
          pa_note?: string | null;
          lighting_note?: string | null;
        };
        Update: {
          live_id?: string;
          position?: number;
          song_id?: string;
          circle_id?: string;
          pa_note?: string | null;
          lighting_note?: string | null;
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
          circle_id: string | null;
          title: string | null;
          play_count: number | null;
          last_played_on: string | null;
        };
        Relationships: [];
      };
    };
    Functions: {
      create_circle: {
        Args: {
          p_name: string;
          p_display_name: string;
        };
        Returns: {
          circle_id: string;
          invite_code: string;
        }[];
      };
      join_circle: {
        Args: {
          p_invite_code: string;
          p_display_name: string;
        };
        Returns: string;
      };
      save_live: {
        Args: {
          p_live_id: string | null;
          p_circle_id: string;
          p_title: string;
          p_performed_on: string;
          p_venue: string | null;
          p_band: string | null;
          // [{ title, pa_note?, lighting_note? }, ...]
          p_songs: Json;
        };
        Returns: string;
      };
    };
    Enums: Record<never, never>;
    CompositeTypes: Record<never, never>;
  };
};

import { supabase } from '../supabase';

export type Membership = {
  circleId: string;
  circleName: string;
  inviteCode: string;
  /** 自分のこのサークルでの表示名 */
  displayName: string;
  role: 'admin' | 'member';
};

export type Member = {
  userId: string;
  displayName: string;
  role: 'admin' | 'member';
};

/**
 * 自分が所属しているサークルの一覧。
 * circle_members の select ポリシーが「所属しているサークルの行だけ」なので、
 * 条件を書かなくても他人の所属は返ってこない（フロントで絞っているわけではない）。
 */
export async function fetchMyMemberships(userId: string): Promise<Membership[]> {
  const { data, error } = await supabase
    .from('circle_members')
    .select('circle_id, display_name, role, circles(name, invite_code)')
    .eq('user_id', userId)
    .order('joined_at', { ascending: true });

  if (error) throw error;

  return (data ?? [])
    .filter((row) => row.circles !== null)
    .map((row) => ({
      circleId: row.circle_id,
      circleName: row.circles?.name ?? '',
      inviteCode: row.circles?.invite_code ?? '',
      displayName: row.display_name,
      role: row.role === 'admin' ? 'admin' : 'member',
    }));
}

/** サークルの部員名簿。ライブの「登録者」を名前で出すために使う。 */
export async function fetchMembers(circleId: string): Promise<Member[]> {
  const { data, error } = await supabase
    .from('circle_members')
    .select('user_id, display_name, role')
    .eq('circle_id', circleId)
    .order('joined_at', { ascending: true });

  if (error) throw error;

  return (data ?? []).map((row) => ({
    userId: row.user_id,
    displayName: row.display_name,
    role: row.role === 'admin' ? 'admin' : 'member',
  }));
}

/**
 * サークルを新規作成し、作った人を管理者として登録する。
 * circles には insert のポリシーが無く、この RPC（security definer）だけが作成経路。
 */
export async function createCircle(name: string, displayName: string): Promise<Membership> {
  const { data, error } = await supabase.rpc('create_circle', {
    p_name: name.trim(),
    p_display_name: displayName.trim(),
  });

  if (error) throw error;
  const created = data?.[0];
  if (!created) throw new Error('サークルを作成できませんでした');

  return {
    circleId: created.circle_id,
    circleName: name.trim(),
    inviteCode: created.invite_code,
    displayName: displayName.trim(),
    role: 'admin',
  };
}

/**
 * 招待コードでサークルに参加する。
 * 参加前は circles を select できない（RLS で弾かれる）ので、コードの照合も RPC 側で行う。
 */
export async function joinCircle(inviteCode: string, displayName: string): Promise<string> {
  const { data, error } = await supabase.rpc('join_circle', {
    p_invite_code: inviteCode.trim().toUpperCase(),
    p_display_name: displayName.trim(),
  });

  if (error) throw error;
  return data;
}

/** 自分の表示名を変更する（他人の行は RLS で更新できない）。 */
export async function updateMyDisplayName(
  circleId: string,
  userId: string,
  displayName: string,
): Promise<void> {
  const { error } = await supabase
    .from('circle_members')
    .update({ display_name: displayName.trim() })
    .eq('circle_id', circleId)
    .eq('user_id', userId);

  if (error) throw error;
}

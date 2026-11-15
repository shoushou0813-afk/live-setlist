import { describe, expect, it } from 'vitest';
import {
  normalizeInviteCode,
  validateCircleName,
  validateDisplayName,
  validateInviteCode,
  validatePassword,
} from './circle';

describe('normalizeInviteCode', () => {
  it('前後の空白を除いて大文字にそろえる', () => {
    expect(normalizeInviteCode('  demo01 ')).toBe('DEMO01');
  });

  it('すでに大文字ならそのまま', () => {
    expect(normalizeInviteCode('ABC234')).toBe('ABC234');
  });
});

describe('validateDisplayName', () => {
  it('空欄は弾く', () => {
    expect(validateDisplayName('   ')?.field).toBe('displayName');
  });

  it('30文字までは通る', () => {
    expect(validateDisplayName('あ'.repeat(30))).toBeNull();
  });

  it('31文字は弾く', () => {
    expect(validateDisplayName('あ'.repeat(31))?.message).toContain('30文字');
  });
});

describe('validateCircleName', () => {
  it('空欄は弾く', () => {
    expect(validateCircleName('')?.field).toBe('circleName');
  });

  it('前後の空白を除いて判定する', () => {
    expect(validateCircleName('  軽音サークル  ')).toBeNull();
  });
});

describe('validateInviteCode', () => {
  it('小文字で入力されても通る（大文字にそろえてから判定する）', () => {
    expect(validateInviteCode('demo01')).toBeNull();
  });

  it('5文字は短すぎるので弾く', () => {
    expect(validateInviteCode('DEMO1')?.field).toBe('inviteCode');
  });

  it('記号入りは弾く', () => {
    expect(validateInviteCode('DEMO-1')?.field).toBe('inviteCode');
  });

  it('空欄は専用のメッセージにする', () => {
    expect(validateInviteCode('  ')?.message).toContain('入力してください');
  });
});

describe('validatePassword', () => {
  it('6文字未満は弾く', () => {
    expect(validatePassword('12345')?.field).toBe('password');
  });

  it('6文字以上は通る', () => {
    expect(validatePassword('123456')).toBeNull();
  });
});

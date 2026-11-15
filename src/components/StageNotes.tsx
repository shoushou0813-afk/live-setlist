import styles from './StageNotes.module.css';

type Props = {
  paNote: string | null;
  lightingColor: string | null;
  lightingBrightness: number | null;
  lightingNote: string | null;
  procedureNote: string | null;
  /** 置く場所の背景。紙色のセトリカード（既定）か、紺のステージ背景か */
  tone?: 'paper' | 'stage';
};

/** 照明の色・明るさ・メモを「赤 ／ 80% ／ サビで白フラッシュ」のように 1 行にまとめる。 */
function lightingSummary({ lightingColor, lightingBrightness, lightingNote }: Props): string {
  return [
    lightingColor,
    lightingBrightness === null ? null : `${lightingBrightness}%`,
    lightingNote,
  ]
    .filter((part): part is string => part !== null && part !== '')
    .join(' ／ ');
}

/**
 * 1 曲分の PA・照明・手順を表示する。ライブ画面と曲一覧（過去の演奏）の両方で使い、
 * PA 班と照明班が同じ見た目で設定を確認できるようにしている。
 * 何も入っていない欄は出さない。
 */
export function StageNotes(props: Props) {
  const lighting = lightingSummary(props);
  if (!props.paNote && !lighting && !props.procedureNote) return null;

  return (
    <dl className={props.tone === 'stage' ? `${styles.notes} ${styles.onStage}` : styles.notes}>
      {props.paNote && (
        <div>
          <dt>PA</dt>
          <dd>{props.paNote}</dd>
        </div>
      )}
      {lighting && (
        <div>
          <dt>照明</dt>
          <dd>{lighting}</dd>
        </div>
      )}
      {props.procedureNote && (
        <div>
          <dt>手順</dt>
          <dd>{props.procedureNote}</dd>
        </div>
      )}
    </dl>
  );
}

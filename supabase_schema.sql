-- ================================================================
--  タイピングバスケ データベーススキーマ
--  Supabase SQL Editor にそのまま貼り付けて実行してください
-- ================================================================

-- ゲームセッションテーブル（1回のプレイ = 1セッション）
CREATE TABLE IF NOT EXISTS game_sessions (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  player_name   TEXT NOT NULL,
  player_id     TEXT,                        -- localStorage UUID
  started_at    TIMESTAMPTZ DEFAULT NOW(),
  completed_at  TIMESTAMPTZ,                 -- NULLなら未完了
  stages_cleared INT DEFAULT 0,
  final_rank    TEXT,
  total_score   INT DEFAULT 0,
  total_attempts INT DEFAULT 0
);

-- ステージ結果テーブル（ステージごとの記録）
CREATE TABLE IF NOT EXISTS stage_results (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id   UUID REFERENCES game_sessions(id) ON DELETE CASCADE,
  player_name  TEXT NOT NULL,
  player_id    TEXT,
  stage_num    INT NOT NULL CHECK (stage_num BETWEEN 1 AND 3),
  cleared      BOOLEAN NOT NULL,
  score        INT NOT NULL DEFAULT 0,
  attempts     INT NOT NULL DEFAULT 0,
  accuracy     INT,          -- Stage1用（命中率%）
  goals_scored INT,          -- Stage2/3用（ゴール数）
  played_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
--  Row Level Security（匿名でも読み書き可能）
-- ================================================================
ALTER TABLE game_sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE stage_results  ENABLE ROW LEVEL SECURITY;

-- 誰でも挿入・選択・更新可能（ゲームの公開スコア）
CREATE POLICY "public insert sessions"  ON game_sessions FOR INSERT WITH CHECK (true);
CREATE POLICY "public select sessions"  ON game_sessions FOR SELECT USING (true);
CREATE POLICY "public update sessions"  ON game_sessions FOR UPDATE USING (true);
CREATE POLICY "public insert results"   ON stage_results FOR INSERT WITH CHECK (true);
CREATE POLICY "public select results"   ON stage_results FOR SELECT USING (true);

-- ================================================================
--  便利なビュー
-- ================================================================

-- ランキングビュー
CREATE OR REPLACE VIEW leaderboard AS
SELECT
  player_name,
  stages_cleared,
  total_score,
  total_attempts,
  CASE WHEN total_attempts > 0
       THEN ROUND(total_score::numeric / total_attempts * 100)
       ELSE 0 END AS accuracy_pct,
  final_rank,
  completed_at
FROM game_sessions
WHERE completed_at IS NOT NULL
ORDER BY stages_cleared DESC, total_score DESC;

-- ステージ別クリア率ビュー
CREATE OR REPLACE VIEW stage_stats AS
SELECT
  stage_num,
  COUNT(*)                                          AS total_plays,
  COUNT(*) FILTER (WHERE cleared)                   AS cleared_count,
  ROUND(COUNT(*) FILTER (WHERE cleared)::numeric
        / NULLIF(COUNT(*), 0) * 100)                AS clear_rate_pct,
  ROUND(AVG(score))                                 AS avg_score,
  ROUND(AVG(CASE WHEN cleared THEN accuracy END))   AS avg_accuracy_stage1,
  ROUND(AVG(CASE WHEN cleared THEN goals_scored END)) AS avg_goals_stage23
FROM stage_results
GROUP BY stage_num
ORDER BY stage_num;

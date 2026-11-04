-- ============================================================================
-- ARCHITECTURAL DDL: SMART TRAINING, BIOMETRIC ANALYTICS & RANKED ELO SYSTEM
-- Target Engine: PostgreSQL 15+ (Render Managed PostgreSQL)
-- ============================================================================

BEGIN;

-- Habilitar extensión para generación criptográfica de UUIDs v4
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. TIPOS ENUMERADOS (DOMINIOS DE METROLOGÍA Y COMPETICIÓN)
-- ============================================================================

DO $$ BEGIN
    CREATE TYPE unit_system_enum AS ENUM ('KG', 'LB');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE biological_sex_enum AS ENUM ('MALE', 'FEMALE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE wearable_source_enum AS ENUM (
        'HEALTH_CONNECT',
        'GOOGLE_FIT',
        'WHOOP',
        'HUAWEI_GT',
        'GARMIN'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE exercise_category_enum AS ENUM ('fuerza', 'hipertrofia', 'cardio');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE formula_1rm_enum AS ENUM ('EPLEY', 'BRZYCKI', 'LOMBARDI', 'MAYHEW');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE workout_status_enum AS ENUM (
        'PLANNED',
        'IN_PROGRESS',
        'COMPLETED',
        'CANCELLED'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE competition_type_enum AS ENUM (
        '1v1',
        'team_vs_team',
        'global_leaderboard'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE metric_target_enum AS ENUM (
        'DOTS_RELATIVE_VOLUME',
        'LBM_ALLOMETRIC_RATIO',
        'RPE_COMPLIANCE_INDEX',
        'TOTAL_ELO_DELTA'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE ranked_tier_enum AS ENUM (
        'Bronce',
        'Plata',
        'Oro',
        'Platino',
        'Diamante',
        'Élite'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE team_role_enum AS ENUM ('CAPTAIN', 'CO_CAPTAIN', 'MEMBER');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE training_goal_enum AS ENUM ('FUERZA', 'HIPERTROFIA', 'RECOMPOSICION');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================================
-- 2. TABLAS PRINCIPALES DEL ESQUEMA NORMALIZADO (3NF)
-- ============================================================================

-- 2.1 USERS
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(32) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(120),
    birth_date DATE,
    biological_sex biological_sex_enum NOT NULL DEFAULT 'MALE',
    height_cm NUMERIC(5,2) CHECK (height_cm BETWEEN 100.00 AND 250.00),
    training_goal training_goal_enum NOT NULL DEFAULT 'HIPERTROFIA',
    preferred_wearable wearable_source_enum NOT NULL DEFAULT 'WHOOP',
    unit_system unit_system_enum NOT NULL DEFAULT 'KG',
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_username_format CHECK (username ~ '^[a-zA-Z0-9_.-]{3,32}$')
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS full_name VARCHAR(120);
ALTER TABLE users ADD COLUMN IF NOT EXISTS birth_date DATE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS training_goal training_goal_enum NOT NULL DEFAULT 'HIPERTROFIA';
ALTER TABLE users ADD COLUMN IF NOT EXISTS preferred_wearable wearable_source_enum NOT NULL DEFAULT 'WHOOP';
ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;

-- 2.2 BIOMETRICS (Ingesta desde OCR Fitdays / Bioimpedancia)
CREATE TABLE IF NOT EXISTS biometrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    weight_kg NUMERIC(5,2) NOT NULL CHECK (weight_kg BETWEEN 25.00 AND 300.00),
    fat_percentage NUMERIC(4,2) NOT NULL CHECK (fat_percentage BETWEEN 2.00 AND 75.00),
    muscle_mass_kg NUMERIC(5,2) NOT NULL CHECK (muscle_mass_kg BETWEEN 10.00 AND 180.00),
    skeletal_muscle_pct NUMERIC(4,2) NOT NULL CHECK (skeletal_muscle_pct BETWEEN 15.00 AND 75.00),
    visceral_fat SMALLINT NOT NULL CHECK (visceral_fat BETWEEN 1 AND 60),
    body_water_pct NUMERIC(4,2) CHECK (body_water_pct BETWEEN 30.00 AND 85.00),
    bmr INTEGER NOT NULL CHECK (bmr BETWEEN 600 AND 6000),
    -- Masa Magra Libre de Grasa calculada automáticamente para normalización alométrica
    lean_body_mass_kg NUMERIC(5,2) GENERATED ALWAYS AS (
        ROUND((weight_kg * (1.0 - (fat_percentage / 100.0)))::numeric, 2)
    ) STORED,
    ocr_confidence NUMERIC(4,3) DEFAULT 1.000 CHECK (ocr_confidence BETWEEN 0.000 AND 1.000),
    source_provider VARCHAR(50) NOT NULL DEFAULT 'FITDAYS_OCR',
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_muscle_less_than_weight CHECK (muscle_mass_kg < weight_kg)
);

-- 2.3 WEARABLE METRICS (Hub Health Connect / Whoop / Huawei Health Kit)
CREATE TABLE IF NOT EXISTS wearable_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    strain_score NUMERIC(4,2) NOT NULL CHECK (strain_score BETWEEN 0.00 AND 21.00),
    recovery_score NUMERIC(5,2) NOT NULL CHECK (recovery_score BETWEEN 0.00 AND 100.00),
    hrv_ms NUMERIC(5,2) CHECK (hrv_ms BETWEEN 5.00 AND 300.00),
    resting_hr SMALLINT CHECK (resting_hr BETWEEN 25 AND 140),
    avg_hr SMALLINT NOT NULL CHECK (avg_hr BETWEEN 30 AND 220),
    max_hr SMALLINT NOT NULL CHECK (max_hr BETWEEN 40 AND 240),
    sleep_hours NUMERIC(4,2) NOT NULL CHECK (sleep_hours BETWEEN 0.00 AND 24.00),
    sleep_efficiency_pct NUMERIC(5,2) CHECK (sleep_efficiency_pct BETWEEN 0.00 AND 100.00),
    source_device wearable_source_enum NOT NULL,
    raw_payload_hash VARCHAR(64),
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_hr_coherence CHECK (max_hr >= avg_hr),
    CONSTRAINT uq_user_date_device UNIQUE (user_id, date, source_device)
);

-- 2.4 EXERCISES (Catálogo Biomecánico)
CREATE TABLE IF NOT EXISTS exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(120) NOT NULL UNIQUE,
    muscle_group VARCHAR(60) NOT NULL,
    secondary_muscles TEXT[] DEFAULT '{}',
    category exercise_category_enum NOT NULL,
    formula_1rm_type formula_1rm_enum NOT NULL DEFAULT 'EPLEY',
    is_compound BOOLEAN NOT NULL DEFAULT TRUE,
    load_multiplier NUMERIC(3,2) NOT NULL DEFAULT 1.00 CHECK (load_multiplier BETWEEN 0.10 AND 2.00),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.45 ROUTINE_TEMPLATES & ROUTINE_TEMPLATE_EXERCISES (Plan Semanal y Rollover)
CREATE TABLE IF NOT EXISTS routine_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    progression_step_kg NUMERIC(4,2) NOT NULL DEFAULT 2.50 CHECK (progression_step_kg >= 0.00),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_routine_day UNIQUE (user_id, day_of_week)
);

CREATE TABLE IF NOT EXISTS routine_template_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    routine_id UUID NOT NULL REFERENCES routine_templates(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
    display_order SMALLINT NOT NULL DEFAULT 1,
    target_sets SMALLINT NOT NULL DEFAULT 4 CHECK (target_sets BETWEEN 1 AND 20),
    base_weight_kg NUMERIC(6,2) NOT NULL DEFAULT 40.00 CHECK (base_weight_kg >= 0.00),
    target_reps SMALLINT NOT NULL DEFAULT 8 CHECK (target_reps BETWEEN 1 AND 200),
    target_rpe NUMERIC(3,1) NOT NULL DEFAULT 8.0 CHECK (target_rpe BETWEEN 1.0 AND 10.0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.5 WORKOUTS (Sesiones de Entrenamiento)
CREATE TABLE IF NOT EXISTS workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    routine_id UUID REFERENCES routine_templates(id) ON DELETE SET NULL,
    scheduled_for_date DATE,
    is_rollover BOOLEAN NOT NULL DEFAULT FALSE,
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status workout_status_enum NOT NULL DEFAULT 'PLANNED',
    readiness_recovery_pct NUMERIC(5,2) CHECK (readiness_recovery_pct BETWEEN 0.00 AND 100.00),
    total_volume_kg NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (total_volume_kg >= 0.00),
    -- Volumen normalizado por coeficiente DOTS y por Masa Magra (LBM^0.67)
    dots_normalized_volume NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (dots_normalized_volume >= 0.00),
    lbm_allometric_score NUMERIC(10,2) NOT NULL DEFAULT 0.00 CHECK (lbm_allometric_score >= 0.00),
    intensity_rpe NUMERIC(3,1) CHECK (intensity_rpe BETWEEN 1.0 AND 10.0),
    compliance_pct NUMERIC(5,2) DEFAULT 100.00 CHECK (compliance_pct BETWEEN 0.00 AND 150.00),
    elo_delta INTEGER NOT NULL DEFAULT 0,
    ai_prescription_notes TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE workouts ADD COLUMN IF NOT EXISTS routine_id UUID REFERENCES routine_templates(id) ON DELETE SET NULL;
ALTER TABLE workouts ADD COLUMN IF NOT EXISTS scheduled_for_date DATE;
ALTER TABLE workouts ADD COLUMN IF NOT EXISTS is_rollover BOOLEAN NOT NULL DEFAULT FALSE;

-- 2.6 WORKOUT_SETS (Series Prescritas vs Ejecutadas en Tiempo Real)
CREATE TABLE IF NOT EXISTS workout_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
    set_number SMALLINT NOT NULL CHECK (set_number BETWEEN 1 AND 50),
    prescribed_weight NUMERIC(6,2) NOT NULL CHECK (prescribed_weight >= 0.00),
    prescribed_reps SMALLINT NOT NULL CHECK (prescribed_reps BETWEEN 1 AND 200),
    prescribed_rpe NUMERIC(3,1) NOT NULL DEFAULT 8.0 CHECK (prescribed_rpe BETWEEN 1.0 AND 10.0),
    actual_weight NUMERIC(6,2) CHECK (actual_weight >= 0.00),
    reps SMALLINT CHECK (reps >= 0 AND reps <= 200),
    rpe NUMERIC(3,1) CHECK (rpe BETWEEN 1.0 AND 10.0),
    estimated_1rm_kg NUMERIC(6,2) CHECK (estimated_1rm_kg >= 0.00),
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    ai_recalculated BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_workout_exercise_set UNIQUE (workout_id, exercise_id, set_number)
);

-- 2.7 TEAMS & TEAM_MEMBERS (Squads Cooperativos)
CREATE TABLE IF NOT EXISTS teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(80) NOT NULL UNIQUE,
    tag VARCHAR(6) NOT NULL UNIQUE,
    captain_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    team_elo INTEGER NOT NULL DEFAULT 1200 CHECK (team_elo >= 0),
    max_members SMALLINT NOT NULL DEFAULT 10 CHECK (max_members BETWEEN 2 AND 50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS team_members (
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role team_role_enum NOT NULL DEFAULT 'MEMBER',
    contribution_score NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (team_id, user_id)
);

-- 2.8 COMPETITIONS & PARTICIPANTS (1v1, Squad vs Squad, Global Leaderboard)
CREATE TABLE IF NOT EXISTS competitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(120) NOT NULL,
    type competition_type_enum NOT NULL,
    metric_target metric_target_enum NOT NULL DEFAULT 'LBM_ALLOMETRIC_RATIO',
    season_id VARCHAR(32) NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_competition_dates CHECK (end_date > start_date)
);

CREATE TABLE IF NOT EXISTS competition_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    competition_id UUID NOT NULL REFERENCES competitions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    normalized_score NUMERIC(12,3) NOT NULL DEFAULT 0.000,
    compliance_bonus NUMERIC(8,3) NOT NULL DEFAULT 0.000,
    biometric_consistency_bonus NUMERIC(8,3) NOT NULL DEFAULT 0.000,
    final_rank INTEGER,
    elo_change INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_participant_entity CHECK (
        (user_id IS NOT NULL AND team_id IS NULL) OR
        (user_id IS NULL AND team_id IS NOT NULL)
    )
);

-- 2.9 RANKED_POINTS (ELO Rating & Tiers por Temporada)
CREATE TABLE IF NOT EXISTS ranked_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    season_id VARCHAR(32) NOT NULL,
    current_elo INTEGER NOT NULL DEFAULT 1200 CHECK (current_elo >= 100),
    peak_elo INTEGER NOT NULL DEFAULT 1200 CHECK (peak_elo >= 100),
    tier ranked_tier_enum NOT NULL DEFAULT 'Plata',
    wins INTEGER NOT NULL DEFAULT 0 CHECK (wins >= 0),
    losses INTEGER NOT NULL DEFAULT 0 CHECK (losses >= 0),
    draws INTEGER NOT NULL DEFAULT 0 CHECK (draws >= 0),
    active_streak SMALLINT NOT NULL DEFAULT 0,
    consistency_multiplier NUMERIC(4,2) NOT NULL DEFAULT 1.00,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_season UNIQUE (user_id, season_id)
);

-- ============================================================================
-- 3. FUNCIONES Y TRIGGERS AUTOMÁTICOS (TIER ELO & TIMESTAMPS)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_resolve_elo_tier(elo INTEGER)
RETURNS ranked_tier_enum AS $$
BEGIN
    IF elo < 1100 THEN RETURN 'Bronce';
    ELSIF elo < 1300 THEN RETURN 'Plata';
    ELSIF elo < 1500 THEN RETURN 'Oro';
    ELSIF elo < 1700 THEN RETURN 'Platino';
    ELSIF elo < 1900 THEN RETURN 'Diamante';
    ELSE RETURN 'Élite';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION fn_sync_ranked_tier()
RETURNS TRIGGER AS $$
BEGIN
    NEW.tier := fn_resolve_elo_tier(NEW.current_elo);
    IF NEW.current_elo > NEW.peak_elo THEN
        NEW.peak_elo := NEW.current_elo;
    END IF;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_ranked_tier ON ranked_points;
CREATE TRIGGER trg_sync_ranked_tier
BEFORE INSERT OR UPDATE OF current_elo ON ranked_points
FOR EACH ROW
EXECUTE FUNCTION fn_sync_ranked_tier();

-- ============================================================================
-- 4. ÍNDICES DE RENDIMIENTO PARA CONSULTAS ANALÍTICAS Y LEADERBOARDS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_biometrics_user_captured
    ON biometrics (user_id, captured_at DESC);

CREATE INDEX IF NOT EXISTS idx_wearable_user_date
    ON wearable_metrics (user_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_workouts_user_date_status
    ON workouts (user_id, date DESC, status);

CREATE INDEX IF NOT EXISTS idx_workout_sets_workout_order
    ON workout_sets (workout_id, exercise_id, set_number);

CREATE INDEX IF NOT EXISTS idx_ranked_points_leaderboard
    ON ranked_points (season_id, current_elo DESC, tier);

CREATE INDEX IF NOT EXISTS idx_comp_participants_score
    ON competition_participants (competition_id, normalized_score DESC);

-- ============================================================================
-- 5. CATÁLOGO BIOMECÁNICO BASE (IDEMPOTENTE)
-- ============================================================================
INSERT INTO exercises (name, muscle_group, category, formula_1rm_type, is_compound, load_multiplier)
VALUES
    ('Barbell Bench Press', 'Pecho', 'fuerza', 'EPLEY', TRUE, 1.00),
    ('Incline Dumbbell Press', 'Pecho', 'hipertrofia', 'BRZYCKI', TRUE, 1.00),
    ('Triceps Rope Pushdown', 'Tríceps', 'hipertrofia', 'BRZYCKI', FALSE, 1.00),
    ('Barbell Bent-Over Row', 'Espalda', 'fuerza', 'EPLEY', TRUE, 1.00),
    ('Lat Pulldown', 'Espalda', 'hipertrofia', 'BRZYCKI', TRUE, 1.00),
    ('EZ-Bar Biceps Curl', 'Bíceps', 'hipertrofia', 'BRZYCKI', FALSE, 1.00),
    ('Barbell Back Squat', 'Pierna', 'fuerza', 'EPLEY', TRUE, 1.00),
    ('Romanian Deadlift', 'Pierna', 'fuerza', 'EPLEY', TRUE, 1.00),
    ('Overhead Barbell Press', 'Hombro', 'fuerza', 'EPLEY', TRUE, 1.00)
ON CONFLICT (name) DO NOTHING;

COMMIT;

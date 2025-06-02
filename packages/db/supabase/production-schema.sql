-- Production Schema Enhancement for Digital Rock Climbing Logbook
-- This extends the base schema with production-ready features

-- Additional extensions for production
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Enhanced custom types
CREATE TYPE session_status AS ENUM ('active', 'paused', 'completed', 'cancelled');
CREATE TYPE sync_status AS ENUM ('pending', 'synced', 'error', 'conflict');
CREATE TYPE media_type AS ENUM ('photo', 'video', 'audio');
CREATE TYPE device_type AS ENUM ('ios', 'android', 'web');

-- Locations table for gym/crag database
CREATE TABLE locations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    type location_type NOT NULL,
    address TEXT,
    coordinates POINT,
    website TEXT,
    phone TEXT,
    description TEXT,
    
    -- Climbing specific data
    route_count INTEGER DEFAULT 0,
    grade_range_min TEXT,
    grade_range_max TEXT,
    styles climbing_style[] DEFAULT ARRAY[]::climbing_style[],
    
    -- Metadata
    verified BOOLEAN DEFAULT false,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Search optimization
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('english', name || ' ' || COALESCE(address, '') || ' ' || COALESCE(description, ''))
    ) STORED
);

-- Enhanced sessions table with status and sync
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS status session_status DEFAULT 'active';
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS sync_status sync_status DEFAULT 'pending';
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS location_id UUID REFERENCES locations(id);
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS device_info JSONB;
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS app_version TEXT;

-- Enhanced climbs table with detailed tracking
ALTER TABLE climbs ADD COLUMN IF NOT EXISTS sync_status sync_status DEFAULT 'pending';
ALTER TABLE climbs ADD COLUMN IF NOT EXISTS route_length INTEGER; -- Length in feet/meters
ALTER TABLE climbs ADD COLUMN IF NOT EXISTS external_route_id TEXT; -- Mountain Project, etc.
ALTER TABLE climbs ADD COLUMN IF NOT EXISTS holds_quality INTEGER CHECK (holds_quality >= 1 AND holds_quality <= 5);
ALTER TABLE climbs ADD COLUMN IF NOT EXISTS movement_quality INTEGER CHECK (movement_quality >= 1 AND movement_quality <= 5);
ALTER TABLE climbs ADD COLUMN IF NOT EXISTS perceived_grade TEXT;
ALTER TABLE climbs ADD COLUMN IF NOT EXISTS comparative_difficulty TEXT CHECK (comparative_difficulty IN ('soft', 'accurate', 'stiff'));

-- Media attachments table
CREATE TABLE media_attachments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    climb_id UUID REFERENCES climbs(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Media details
    type media_type NOT NULL,
    file_path TEXT NOT NULL,
    file_size INTEGER,
    mime_type TEXT,
    duration INTEGER, -- For video/audio in seconds
    width INTEGER, -- For images/video
    height INTEGER, -- For images/video
    
    -- Upload tracking
    upload_status sync_status DEFAULT 'pending',
    upload_attempts INTEGER DEFAULT 0,
    last_upload_attempt TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CHECK (
        (climb_id IS NOT NULL AND session_id IS NULL) OR 
        (climb_id IS NULL AND session_id IS NOT NULL)
    )
);

-- Route information table
CREATE TABLE routes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
    
    -- Route details
    name TEXT NOT NULL,
    grade TEXT NOT NULL,
    grade_system grade_system NOT NULL,
    style climbing_style NOT NULL,
    length INTEGER, -- Length in feet/meters
    pitches INTEGER DEFAULT 1,
    
    -- Route characteristics
    color TEXT,
    setter TEXT,
    section TEXT, -- Wall section or crag area
    description TEXT,
    beta_notes TEXT,
    first_ascent_date DATE,
    first_ascent_by TEXT,
    
    -- External references
    external_ids JSONB, -- {mountain_project: "id", 8a_nu: "id", etc.}
    
    -- Aggregated data
    avg_rating DECIMAL(3,2),
    total_ascents INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Search optimization
    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('english', name || ' ' || COALESCE(description, '') || ' ' || COALESCE(beta_notes, ''))
    ) STORED
);

-- Training plans table
CREATE TABLE training_plans (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    goal_id UUID REFERENCES goals(id) ON DELETE CASCADE,
    
    -- Plan details
    name TEXT NOT NULL,
    description TEXT,
    duration_weeks INTEGER,
    difficulty_level INTEGER CHECK (difficulty_level >= 1 AND difficulty_level <= 5),
    
    -- Plan structure
    plan_data JSONB NOT NULL, -- Detailed weekly/daily structure
    
    -- Progress tracking
    status TEXT DEFAULT 'active', -- 'active', 'completed', 'paused', 'cancelled'
    current_week INTEGER DEFAULT 1,
    completion_percentage INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sync queue for offline operations
CREATE TABLE sync_queue (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    
    -- Sync details
    entity_type TEXT NOT NULL, -- 'session', 'climb', 'media', etc.
    entity_id UUID NOT NULL,
    operation TEXT NOT NULL, -- 'create', 'update', 'delete'
    data JSONB,
    
    -- Retry logic
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 5,
    next_retry TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_error TEXT,
    
    -- Priority and batching
    priority INTEGER DEFAULT 1, -- Higher = more important
    batch_id UUID,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audit log for data changes
CREATE TABLE audit_log (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    -- Change details
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    operation TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    old_values JSONB,
    new_values JSONB,
    
    -- Context
    device_type device_type,
    ip_address INET,
    user_agent TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Performance monitoring table
CREATE TABLE performance_metrics (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    
    -- Metrics
    metric_type TEXT NOT NULL, -- 'session_duration', 'sync_time', 'load_time', etc.
    value DECIMAL,
    unit TEXT,
    context JSONB,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Additional indexes for production performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sessions_status ON sessions(status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sessions_location_id ON sessions(location_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sessions_sync_status ON sessions(sync_status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_climbs_sync_status ON climbs(sync_status);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_climbs_result ON climbs(result);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_climbs_style ON climbs(style);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_locations_type ON locations(type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_locations_coordinates ON locations USING GIST(coordinates);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_locations_search ON locations USING GIN(search_vector);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_routes_location_id ON routes(location_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_routes_grade_style ON routes(grade, style);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_routes_search ON routes USING GIN(search_vector);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_media_climb_id ON media_attachments(climb_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_media_session_id ON media_attachments(session_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_media_upload_status ON media_attachments(upload_status);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sync_queue_user_id ON sync_queue(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sync_queue_next_retry ON sync_queue(next_retry) WHERE attempts < max_attempts;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sync_queue_priority ON sync_queue(priority DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_table_record ON audit_log(table_name, record_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at DESC);

-- Partial indexes for efficiency
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_climbs_active_sessions ON climbs(session_id) 
WHERE created_at > NOW() - INTERVAL '30 days';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pending_sync ON sync_queue(user_id, priority DESC) 
WHERE attempts < max_attempts AND next_retry <= NOW();

-- RLS policies for new tables
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE performance_metrics ENABLE ROW LEVEL SECURITY;

-- Locations policies (public read, authenticated write)
CREATE POLICY "Anyone can view locations" ON locations FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Authenticated users can create locations" ON locations FOR INSERT TO authenticated WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Users can update own created locations" ON locations FOR UPDATE TO authenticated USING (auth.uid() = created_by);

-- Routes policies (public read, authenticated write)
CREATE POLICY "Anyone can view routes" ON routes FOR SELECT TO authenticated, anon USING (true);
CREATE POLICY "Authenticated users can create routes" ON routes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Authenticated users can update routes" ON routes FOR UPDATE TO authenticated USING (true);

-- Media policies (users own data)
CREATE POLICY "Users can view own media" ON media_attachments FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own media" ON media_attachments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own media" ON media_attachments FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own media" ON media_attachments FOR DELETE USING (auth.uid() = user_id);

-- Training plans policies
CREATE POLICY "Users can view own training plans" ON training_plans FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own training plans" ON training_plans FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own training plans" ON training_plans FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own training plans" ON training_plans FOR DELETE USING (auth.uid() = user_id);

-- Sync queue policies
CREATE POLICY "Users can view own sync queue" ON sync_queue FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own sync items" ON sync_queue FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own sync items" ON sync_queue FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own sync items" ON sync_queue FOR DELETE USING (auth.uid() = user_id);

-- Audit log policies (read-only for users)
CREATE POLICY "Users can view own audit log" ON audit_log FOR SELECT USING (auth.uid() = user_id);

-- Performance metrics policies
CREATE POLICY "Users can view own metrics" ON performance_metrics FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own metrics" ON performance_metrics FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Additional triggers for new tables
CREATE TRIGGER update_locations_updated_at BEFORE UPDATE ON locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_routes_updated_at BEFORE UPDATE ON routes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_media_attachments_updated_at BEFORE UPDATE ON media_attachments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_training_plans_updated_at BEFORE UPDATE ON training_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sync_queue_updated_at BEFORE UPDATE ON sync_queue
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function for audit logging
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_values, user_id)
        VALUES (TG_TABLE_NAME, OLD.id, TG_OP, to_jsonb(OLD), auth.uid());
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, to_jsonb(OLD), to_jsonb(NEW), auth.uid());
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, operation, new_values, user_id)
        VALUES (TG_TABLE_NAME, NEW.id, TG_OP, to_jsonb(NEW), auth.uid());
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit triggers to critical tables
CREATE TRIGGER audit_profiles_trigger
    AFTER INSERT OR UPDATE OR DELETE ON profiles
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_sessions_trigger
    AFTER INSERT OR UPDATE OR DELETE ON sessions
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_climbs_trigger
    AFTER INSERT OR UPDATE OR DELETE ON climbs
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Enhanced views for analytics
CREATE OR REPLACE VIEW detailed_session_stats AS
SELECT 
    s.id as session_id,
    s.user_id,
    s.start_time,
    s.end_time,
    s.status,
    s.location_name,
    s.location_type,
    l.name as location_full_name,
    
    -- Session metrics
    EXTRACT(EPOCH FROM (s.end_time - s.start_time))/3600 as duration_hours,
    COUNT(c.id) as total_climbs,
    COUNT(CASE WHEN c.result IN ('flash', 'onsight', 'redpoint') THEN 1 END) as successful_climbs,
    
    -- Grade analysis
    MAX(CASE 
        WHEN c.grade_system = 'YDS' THEN 
            CAST(SUBSTRING(c.grade FROM '\d+\.?\d*') AS DECIMAL) * 10 +
            CASE 
                WHEN c.grade LIKE '%a' THEN 1
                WHEN c.grade LIKE '%b' THEN 2
                WHEN c.grade LIKE '%c' THEN 3
                WHEN c.grade LIKE '%d' THEN 4
                ELSE 0
            END
        WHEN c.grade_system = 'V-Scale' THEN 
            CAST(SUBSTRING(c.grade FROM '\d+') AS DECIMAL) * 10
        ELSE NULL
    END) as max_grade_numeric,
    
    AVG(c.quality_rating) as avg_quality,
    AVG(c.difficulty_perception) as avg_perceived_difficulty,
    
    -- Style distribution
    COUNT(CASE WHEN c.style = 'lead' THEN 1 END) as lead_climbs,
    COUNT(CASE WHEN c.style = 'toprope' THEN 1 END) as toprope_climbs,
    COUNT(CASE WHEN c.style = 'boulder' THEN 1 END) as boulder_climbs
    
FROM sessions s
LEFT JOIN climbs c ON s.id = c.session_id
LEFT JOIN locations l ON s.location_id = l.id
GROUP BY s.id, s.user_id, s.start_time, s.end_time, s.status, 
         s.location_name, s.location_type, l.name;

-- View for grade progression analysis
CREATE OR REPLACE VIEW grade_progression AS
WITH grade_numeric AS (
    SELECT 
        c.*,
        CASE 
            WHEN c.grade_system = 'YDS' THEN 
                CAST(SUBSTRING(c.grade FROM '\d+\.?\d*') AS DECIMAL) * 10 +
                CASE 
                    WHEN c.grade LIKE '%a' THEN 1
                    WHEN c.grade LIKE '%b' THEN 2
                    WHEN c.grade LIKE '%c' THEN 3
                    WHEN c.grade LIKE '%d' THEN 4
                    ELSE 0
                END
            WHEN c.grade_system = 'V-Scale' THEN 
                CAST(SUBSTRING(c.grade FROM '\d+') AS DECIMAL) * 10
            ELSE NULL
        END as grade_numeric
    FROM climbs c
    WHERE c.result IN ('flash', 'onsight', 'redpoint')
)
SELECT 
    user_id,
    style,
    grade_system,
    DATE_TRUNC('week', created_at) as week,
    MAX(grade_numeric) as max_grade_numeric,
    AVG(grade_numeric) as avg_grade_numeric,
    COUNT(*) as successful_climbs
FROM grade_numeric
WHERE grade_numeric IS NOT NULL
GROUP BY user_id, style, grade_system, DATE_TRUNC('week', created_at)
ORDER BY user_id, style, week;

-- Function to calculate user climbing level
CREATE OR REPLACE FUNCTION calculate_user_level(user_uuid UUID)
RETURNS TABLE (
    style climbing_style,
    current_level TEXT,
    level_numeric DECIMAL,
    recent_sends INTEGER,
    consistency_score DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    WITH recent_sends AS (
        SELECT 
            c.style,
            c.grade,
            c.grade_system,
            CASE 
                WHEN c.grade_system = 'YDS' THEN 
                    CAST(SUBSTRING(c.grade FROM '\d+\.?\d*') AS DECIMAL) * 10 +
                    CASE 
                        WHEN c.grade LIKE '%a' THEN 1
                        WHEN c.grade LIKE '%b' THEN 2
                        WHEN c.grade LIKE '%c' THEN 3
                        WHEN c.grade LIKE '%d' THEN 4
                        ELSE 0
                    END
                WHEN c.grade_system = 'V-Scale' THEN 
                    CAST(SUBSTRING(c.grade FROM '\d+') AS DECIMAL) * 10
                ELSE NULL
            END as grade_numeric
        FROM climbs c
        WHERE c.user_id = user_uuid
        AND c.result IN ('flash', 'onsight', 'redpoint')
        AND c.created_at > NOW() - INTERVAL '90 days'
        AND grade IS NOT NULL
    )
    SELECT 
        rs.style,
        MAX(rs.grade) as current_level,
        MAX(rs.grade_numeric) as level_numeric,
        COUNT(*)::INTEGER as recent_sends,
        (COUNT(*) / 90.0 * 7)::DECIMAL as consistency_score  -- Sends per week
    FROM recent_sends rs
    WHERE rs.grade_numeric IS NOT NULL
    GROUP BY rs.style
    ORDER BY level_numeric DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 
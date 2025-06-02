-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE climbing_style AS ENUM ('lead', 'toprope', 'boulder', 'aid', 'solo');
CREATE TYPE location_type AS ENUM ('gym', 'outdoor');
CREATE TYPE climb_result AS ENUM ('flash', 'onsight', 'redpoint', 'attempt', 'project');
CREATE TYPE grade_system AS ENUM ('YDS', 'French', 'V-Scale', 'UIAA');

-- Profiles table (extends Supabase auth.users)
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    climbing_style_preference climbing_style DEFAULT 'lead',
    preferred_grade_system grade_system DEFAULT 'YDS',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sessions table
CREATE TABLE sessions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE,
    location_name TEXT NOT NULL,
    location_type location_type NOT NULL,
    location_coordinates POINT,
    notes TEXT,
    weather_conditions JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Climbs table
CREATE TABLE climbs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    session_id UUID REFERENCES sessions(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    sequence_number INTEGER NOT NULL DEFAULT 1,
    
    -- Route information
    route_name TEXT,
    route_color TEXT,
    route_setter TEXT,
    
    -- Climb details
    grade TEXT NOT NULL,
    grade_system grade_system NOT NULL DEFAULT 'YDS',
    style climbing_style NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 1,
    result climb_result NOT NULL,
    
    -- Performance metrics
    quality_rating INTEGER CHECK (quality_rating >= 1 AND quality_rating <= 5),
    difficulty_perception INTEGER CHECK (difficulty_perception >= 1 AND difficulty_perception <= 5),
    fall_count INTEGER DEFAULT 0,
    rest_count INTEGER DEFAULT 0,
    
    -- Additional data
    notes TEXT,
    photos TEXT[], -- Array of photo URLs
    videos TEXT[], -- Array of video URLs
    beta_notes TEXT,
    
    -- Timing
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER,
    
    -- Metadata
    input_method TEXT DEFAULT 'manual', -- 'manual', 'voice', 'photo', 'bulk'
    confidence_score DECIMAL(3,2) DEFAULT 1.0, -- For AI-parsed data
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(session_id, sequence_number)
);

-- Goals table
CREATE TABLE goals (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    target_grade TEXT,
    target_date DATE,
    goal_type TEXT NOT NULL, -- 'grade', 'volume', 'style', 'route'
    status TEXT DEFAULT 'active', -- 'active', 'completed', 'paused', 'cancelled'
    progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User preferences table
CREATE TABLE user_preferences (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL UNIQUE,
    
    -- App preferences
    default_location TEXT,
    auto_start_session BOOLEAN DEFAULT false,
    voice_logging_enabled BOOLEAN DEFAULT true,
    
    -- Notification preferences
    session_reminders BOOLEAN DEFAULT true,
    goal_reminders BOOLEAN DEFAULT true,
    weekly_summary BOOLEAN DEFAULT true,
    
    -- Privacy preferences
    profile_public BOOLEAN DEFAULT false,
    share_sessions BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_start_time ON sessions(start_time DESC);
CREATE INDEX idx_climbs_session_id ON climbs(session_id);
CREATE INDEX idx_climbs_user_id ON climbs(user_id);
CREATE INDEX idx_climbs_grade ON climbs(grade);
CREATE INDEX idx_climbs_created_at ON climbs(created_at DESC);
CREATE INDEX idx_goals_user_id ON goals(user_id);

-- Row Level Security (RLS) policies
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE climbs ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Sessions policies
CREATE POLICY "Users can view own sessions" ON sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions" ON sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions" ON sessions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions" ON sessions
    FOR DELETE USING (auth.uid() = user_id);

-- Climbs policies
CREATE POLICY "Users can view own climbs" ON climbs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own climbs" ON climbs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own climbs" ON climbs
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own climbs" ON climbs
    FOR DELETE USING (auth.uid() = user_id);

-- Goals policies
CREATE POLICY "Users can view own goals" ON goals
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own goals" ON goals
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own goals" ON goals
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own goals" ON goals
    FOR DELETE USING (auth.uid() = user_id);

-- User preferences policies
CREATE POLICY "Users can view own preferences" ON user_preferences
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences" ON user_preferences
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own preferences" ON user_preferences
    FOR UPDATE USING (auth.uid() = user_id);

-- Functions for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for automatic timestamp updates
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_climbs_updated_at BEFORE UPDATE ON climbs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_goals_updated_at BEFORE UPDATE ON goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically create user preferences on profile creation
CREATE OR REPLACE FUNCTION create_user_preferences()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_preferences (user_id)
    VALUES (NEW.id);
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER create_user_preferences_trigger
    AFTER INSERT ON profiles
    FOR EACH ROW EXECUTE FUNCTION create_user_preferences();

-- Views for common queries
CREATE VIEW user_session_stats AS
SELECT 
    p.id as user_id,
    p.full_name,
    COUNT(s.id) as total_sessions,
    COUNT(c.id) as total_climbs,
    MAX(s.start_time) as last_session_date,
    AVG(
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
        END
    ) as avg_grade_numeric
FROM profiles p
LEFT JOIN sessions s ON p.id = s.user_id
LEFT JOIN climbs c ON s.id = c.session_id
GROUP BY p.id, p.full_name;

-- View for recent activity
CREATE VIEW recent_activity AS
SELECT 
    c.id,
    c.user_id,
    c.session_id,
    c.route_name,
    c.grade,
    c.style,
    c.result,
    c.quality_rating,
    c.created_at,
    s.location_name,
    s.location_type
FROM climbs c
JOIN sessions s ON c.session_id = s.id
ORDER BY c.created_at DESC; 
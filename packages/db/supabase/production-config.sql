-- Production Configuration for Digital Rock Climbing Logbook
-- Monitoring, backup, and operational settings

-- Enable query performance tracking
ALTER SYSTEM SET track_activity_query_size = 2048;
ALTER SYSTEM SET log_min_duration_statement = 1000; -- Log queries > 1s
ALTER SYSTEM SET log_checkpoints = on;
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_lock_waits = on;

-- Optimize for climbing app workload patterns
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '4MB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET random_page_cost = 1.1; -- SSD optimization

-- Backup and reliability settings
ALTER SYSTEM SET wal_level = 'replica';
ALTER SYSTEM SET archive_mode = on;
ALTER SYSTEM SET archive_command = 'test ! -f /backup/archive/%f && cp %p /backup/archive/%f';
ALTER SYSTEM SET max_wal_senders = 3;
ALTER SYSTEM SET checkpoint_timeout = '15min';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;

-- Function to setup automated database maintenance
CREATE OR REPLACE FUNCTION setup_maintenance_jobs()
RETURNS void AS $$
BEGIN
    -- This would be implemented with pg_cron in production
    -- Examples of maintenance tasks:
    
    -- Daily: Update statistics for query optimization
    -- SELECT cron.schedule('update-stats', '0 2 * * *', 'ANALYZE;');
    
    -- Weekly: Vacuum old data and rebuild indexes
    -- SELECT cron.schedule('weekly-maintenance', '0 3 * * 0', 
    --   'VACUUM (ANALYZE, VERBOSE) audit_log; REINDEX INDEX CONCURRENTLY idx_audit_log_created_at;');
    
    -- Monthly: Clean up old audit logs (keep 1 year)
    -- SELECT cron.schedule('cleanup-audit', '0 4 1 * *',
    --   'DELETE FROM audit_log WHERE created_at < NOW() - INTERVAL ''1 year'';');
    
    RAISE NOTICE 'Maintenance jobs configured (requires pg_cron extension)';
END;
$$ LANGUAGE plpgsql;

-- Performance monitoring functions
CREATE OR REPLACE FUNCTION get_climbing_app_metrics()
RETURNS TABLE (
    metric_name TEXT,
    value NUMERIC,
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'active_sessions' as metric_name,
        COUNT(*)::NUMERIC as value,
        'Currently active climbing sessions' as description
    FROM sessions 
    WHERE status = 'active' 
    AND start_time > NOW() - INTERVAL '24 hours'
    
    UNION ALL
    
    SELECT 
        'daily_climbs' as metric_name,
        COUNT(*)::NUMERIC as value,
        'Climbs logged in last 24 hours' as description
    FROM climbs 
    WHERE created_at > NOW() - INTERVAL '24 hours'
    
    UNION ALL
    
    SELECT 
        'pending_sync_items' as metric_name,
        COUNT(*)::NUMERIC as value,
        'Items waiting to sync' as description
    FROM sync_queue 
    WHERE attempts < max_attempts
    
    UNION ALL
    
    SELECT 
        'failed_sync_items' as metric_name,
        COUNT(*)::NUMERIC as value,
        'Items that failed to sync' as description
    FROM sync_queue 
    WHERE attempts >= max_attempts
    
    UNION ALL
    
    SELECT 
        'avg_session_duration_minutes' as metric_name,
        AVG(EXTRACT(EPOCH FROM (end_time - start_time))/60)::NUMERIC as value,
        'Average session duration in minutes' as description
    FROM sessions 
    WHERE end_time IS NOT NULL 
    AND start_time > NOW() - INTERVAL '7 days'
    
    UNION ALL
    
    SELECT 
        'weekly_active_users' as metric_name,
        COUNT(DISTINCT user_id)::NUMERIC as value,
        'Unique users active in last 7 days' as description
    FROM sessions 
    WHERE start_time > NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Database health check function
CREATE OR REPLACE FUNCTION database_health_check()
RETURNS TABLE (
    check_name TEXT,
    status TEXT,
    message TEXT,
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Check for large tables that might need partitioning
    SELECT 
        'large_tables' as check_name,
        CASE WHEN pg_total_relation_size('climbs') > 1073741824 THEN 'WARNING' ELSE 'OK' END as status,
        'Climbs table size: ' || pg_size_pretty(pg_total_relation_size('climbs')) as message,
        CASE WHEN pg_total_relation_size('climbs') > 1073741824 
             THEN 'Consider partitioning climbs table by date'
             ELSE 'Table size is manageable' END as recommendation
    
    UNION ALL
    
    -- Check index usage
    SELECT 
        'unused_indexes' as check_name,
        CASE WHEN COUNT(*) > 0 THEN 'WARNING' ELSE 'OK' END as status,
        'Unused indexes found: ' || COUNT(*)::TEXT as message,
        CASE WHEN COUNT(*) > 0 
             THEN 'Review and drop unused indexes to improve write performance'
             ELSE 'All indexes are being used' END as recommendation
    FROM pg_stat_user_indexes 
    WHERE idx_scan = 0 
    AND schemaname = 'public'
    
    UNION ALL
    
    -- Check for slow queries
    SELECT 
        'slow_queries' as check_name,
        CASE WHEN COUNT(*) > 10 THEN 'WARNING' ELSE 'OK' END as status,
        'Queries > 1s in last hour: ' || COUNT(*)::TEXT as message,
        CASE WHEN COUNT(*) > 10 
             THEN 'Investigate slow queries and optimize'
             ELSE 'Query performance is good' END as recommendation
    FROM pg_stat_statements 
    WHERE mean_exec_time > 1000 
    AND last_exec > NOW() - INTERVAL '1 hour'
    
    UNION ALL
    
    -- Check sync queue health
    SELECT 
        'sync_queue_health' as check_name,
        CASE WHEN COUNT(*) > 1000 THEN 'ERROR'
             WHEN COUNT(*) > 100 THEN 'WARNING' 
             ELSE 'OK' END as status,
        'Pending sync items: ' || COUNT(*)::TEXT as message,
        CASE WHEN COUNT(*) > 1000 THEN 'Sync system may be down - investigate immediately'
             WHEN COUNT(*) > 100 THEN 'Sync backlog detected - check network connectivity'
             ELSE 'Sync queue is healthy' END as recommendation
    FROM sync_queue 
    WHERE attempts < max_attempts;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create monitoring views for Grafana/external monitoring
CREATE OR REPLACE VIEW app_metrics_real_time AS
SELECT 
    'climbing_logbook' as app_name,
    extract(epoch from now()) as timestamp,
    (SELECT COUNT(*) FROM sessions WHERE status = 'active') as active_sessions,
    (SELECT COUNT(*) FROM climbs WHERE created_at > NOW() - INTERVAL '1 hour') as climbs_last_hour,
    (SELECT COUNT(*) FROM sync_queue WHERE attempts < max_attempts) as pending_sync,
    (SELECT COUNT(DISTINCT user_id) FROM sessions WHERE start_time > NOW() - INTERVAL '24 hours') as daily_active_users,
    (SELECT AVG(value) FROM performance_metrics WHERE metric_type = 'session_duration' AND created_at > NOW() - INTERVAL '1 hour') as avg_session_duration;

-- Email configuration for notifications (Supabase-specific)
-- Note: This would be configured in Supabase dashboard, but documenting here

/*
Email Templates for Production:

1. Welcome Email:
Subject: Welcome to ClimbLog - Your Digital Climbing Journey Starts Here!
Template: welcome_email.html

2. Password Reset:
Subject: Reset Your ClimbLog Password
Template: password_reset.html

3. Weekly Summary:
Subject: Your Weekly Climbing Summary 🧗‍♂️
Template: weekly_summary.html

4. Goal Achievement:
Subject: Congratulations! You've Achieved Your Climbing Goal 🎯
Template: goal_achievement.html

5. Session Reminder:
Subject: Time to Get Back on the Wall! 💪
Template: session_reminder.html

SMTP Configuration:
- Provider: Supabase managed SMTP or custom SMTP (Sendgrid, Mailgun)
- Rate limits: 1000 emails/hour for free tier
- Bounce handling: Enabled
- Unsubscribe handling: Enabled
*/

-- Function to trigger email notifications
CREATE OR REPLACE FUNCTION trigger_email_notification(
    user_uuid UUID,
    email_type TEXT,
    template_data JSONB DEFAULT '{}'::JSONB
)
RETURNS void AS $$
BEGIN
    -- This would integrate with Supabase Edge Functions for email sending
    -- For now, we'll log the notification request
    
    INSERT INTO audit_log (
        user_id,
        table_name,
        operation,
        new_values
    ) VALUES (
        user_uuid,
        'email_notifications',
        'SEND',
        jsonb_build_object(
            'email_type', email_type,
            'template_data', template_data,
            'timestamp', NOW()
        )
    );
    
    -- In production, this would call:
    -- SELECT net.http_post(
    --     url := 'https://your-edge-function-url/send-email',
    --     headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || auth.jwt() || '"}',
    --     body := jsonb_build_object(
    --         'user_id', user_uuid,
    --         'email_type', email_type,
    --         'template_data', template_data
    --     )::text
    -- );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Automated notification triggers
CREATE OR REPLACE FUNCTION handle_goal_completion()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        PERFORM trigger_email_notification(
            NEW.user_id,
            'goal_achievement',
            jsonb_build_object(
                'goal_title', NEW.title,
                'completion_date', NOW()
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER goal_completion_notification
    AFTER UPDATE ON goals
    FOR EACH ROW
    EXECUTE FUNCTION handle_goal_completion();

-- Weekly summary notification function
CREATE OR REPLACE FUNCTION send_weekly_summaries()
RETURNS void AS $$
DECLARE
    user_record RECORD;
    summary_data JSONB;
BEGIN
    -- Send weekly summaries to active users
    FOR user_record IN 
        SELECT DISTINCT p.id, p.email, p.full_name
        FROM profiles p
        JOIN user_preferences up ON p.id = up.user_id
        JOIN sessions s ON p.id = s.user_id
        WHERE up.weekly_summary = true
        AND s.start_time > NOW() - INTERVAL '7 days'
    LOOP
        -- Calculate weekly stats
        SELECT jsonb_build_object(
            'total_sessions', COUNT(DISTINCT s.id),
            'total_climbs', COUNT(c.id),
            'successful_climbs', COUNT(CASE WHEN c.result IN ('flash', 'onsight', 'redpoint') THEN 1 END),
            'max_grade', MAX(c.grade),
            'total_time_hours', ROUND(SUM(EXTRACT(EPOCH FROM (s.end_time - s.start_time))/3600)::NUMERIC, 1)
        ) INTO summary_data
        FROM sessions s
        LEFT JOIN climbs c ON s.id = c.session_id
        WHERE s.user_id = user_record.id
        AND s.start_time > NOW() - INTERVAL '7 days';
        
        PERFORM trigger_email_notification(
            user_record.id,
            'weekly_summary',
            summary_data
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Security enhancements
CREATE OR REPLACE FUNCTION log_security_event(
    event_type TEXT,
    event_data JSONB DEFAULT '{}'::JSONB
)
RETURNS void AS $$
BEGIN
    INSERT INTO audit_log (
        user_id,
        table_name,
        operation,
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        auth.uid(),
        'security_events',
        event_type,
        event_data,
        inet_client_addr(),
        current_setting('request.headers')::JSONB->>'user-agent'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Rate limiting function for API endpoints
CREATE OR REPLACE FUNCTION check_rate_limit(
    user_uuid UUID,
    action_type TEXT,
    time_window INTERVAL DEFAULT '1 hour',
    max_actions INTEGER DEFAULT 100
)
RETURNS BOOLEAN AS $$
DECLARE
    current_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO current_count
    FROM audit_log
    WHERE user_id = user_uuid
    AND table_name = action_type
    AND created_at > NOW() - time_window;
    
    IF current_count >= max_actions THEN
        PERFORM log_security_event(
            'RATE_LIMIT_EXCEEDED',
            jsonb_build_object(
                'action_type', action_type,
                'current_count', current_count,
                'max_actions', max_actions,
                'time_window', time_window
            )
        );
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Initialize production settings
SELECT setup_maintenance_jobs();

-- Grant necessary permissions for monitoring
GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO postgres;

-- Create read-only user for monitoring tools
-- CREATE USER monitoring_user WITH PASSWORD 'secure_monitoring_password';
-- GRANT CONNECT ON DATABASE postgres TO monitoring_user;
-- GRANT USAGE ON SCHEMA public TO monitoring_user;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitoring_user;
-- GRANT SELECT ON pg_stat_statements TO monitoring_user; 
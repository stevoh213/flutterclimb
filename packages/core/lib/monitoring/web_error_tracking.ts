// Web Error Tracking Configuration
// Modular error tracking system for React app

import * as Sentry from '@sentry/react';
import { BrowserTracing } from '@sentry/tracing';
import React from 'react';
import { 
  useLocation, 
  useNavigationType, 
  createRoutesFromChildren, 
  matchRoutes 
} from 'react-router-dom';

/// Environment-aware configuration
const SENTRY_DSN = import.meta.env?.VITE_SENTRY_DSN || '';
const ENVIRONMENT = import.meta.env?.VITE_ENVIRONMENT || 'development';
const APP_VERSION = import.meta.env?.VITE_APP_VERSION || '1.0.0';

/// Error categories for climbing web app
export enum WebErrorCategory {
  AUTHENTICATION = 'auth',
  SESSION_MANAGEMENT = 'session',
  CLIMB_LOGGING = 'climb_logging',
  DATA_SYNC = 'data_sync',
  ANALYTICS = 'analytics',
  API = 'api',
  ROUTER = 'router',
  UI = 'ui',
  UNKNOWN = 'unknown',
}

/// Performance metrics categories
export enum PerformanceCategory {
  PAGE_LOAD = 'page_load',
  API_CALL = 'api_call',
  DATA_PROCESSING = 'data_processing',
  COMPONENT_RENDER = 'component_render',
  USER_INTERACTION = 'user_interaction',
}

/// Initialize Sentry for web app
export function initializeWebErrorTracking(): void {
  if (!SENTRY_DSN) {
    if (import.meta.env.DEV) {
      console.warn('⚠️ Sentry DSN not configured, error tracking disabled');
    }
    return;
  }

  Sentry.init({
    dsn: SENTRY_DSN,
    environment: ENVIRONMENT,
    release: APP_VERSION,
    
    // Performance monitoring
    tracesSampleRate: getTracesSampleRate(),
    
    // Integrations
    integrations: [
      new BrowserTracing({
        // Set up automatic route change tracking for React Router
        routingInstrumentation: Sentry.reactRouterV6Instrumentation(
          React.useEffect,
          useLocation,
          useNavigationType,
          createRoutesFromChildren,
          matchRoutes
        ),
        
        // Track specific components
        tracePropagationTargets: [
          'localhost',
          /^https:\/\/[^/]*\.climblog\.app/,
          /^https:\/\/[^/]*\.supabase\.co/,
        ],
      }),
    ],

    // Error filtering
    beforeSend: filterWebErrors,
    beforeBreadcrumb: filterWebBreadcrumbs,

    // Privacy settings
    sendDefaultPii: false,
    beforeSendTransaction: filterWebTransactions,

    // Debug settings
    debug: import.meta.env.DEV,
    
    // Initial scope
    initialScope: {
      tags: {
        'app.name': 'climbing_logbook_web',
        'app.platform': 'web',
        'app.version': APP_VERSION,
      },
    },

    // Auto session tracking
    autoSessionTracking: true,
    
    // Network tracking
    beforeSend: (event) => {
      // Filter out expected network errors
      if (event.exception?.values?.[0]?.type === 'ChunkLoadError') {
        return null; // Don't report chunk load errors
      }
      return filterWebErrors(event);
    },
  });
}

/// Get sample rate based on environment
function getTracesSampleRate(): number {
  switch (ENVIRONMENT) {
    case 'production':
      return 0.1; // 10% sampling in production
    case 'staging':
      return 0.5; // 50% sampling in staging
    default:
      return 1.0; // 100% sampling in development
  }
}

/// Filter errors to reduce noise
function filterWebErrors(event: Sentry.Event): Sentry.Event | null {
  // Don't send errors in development
  if (import.meta.env.DEV) return null;

  // Filter out common browser errors
  const error = event.exception?.values?.[0];
  if (error?.value) {
    const errorMessage = error.value.toLowerCase();
    
    // Network errors that are expected
    if (
      errorMessage.includes('network error') ||
      errorMessage.includes('fetch error') ||
      errorMessage.includes('load failed') ||
      errorMessage.includes('script error')
    ) {
      return null;
    }

    // Browser extension errors
    if (
      errorMessage.includes('extension') ||
      errorMessage.includes('chrome://') ||
      errorMessage.includes('moz-extension://')
    ) {
      return null;
    }

    // Ad blocker related errors
    if (
      errorMessage.includes('adsbygoogle') ||
      errorMessage.includes('googlesyndication')
    ) {
      return null;
    }
  }

  // Add climbing-specific context
  return {
    ...event,
    tags: {
      ...event.tags,
      'app.component': 'climbing_logbook_web',
      'browser': getBrowserInfo(),
    },
    contexts: {
      ...event.contexts,
      climbing_context: getClimbingContext(),
    },
  };
}

/// Filter breadcrumbs to reduce noise
function filterWebBreadcrumbs(breadcrumb: Sentry.Breadcrumb): Sentry.Breadcrumb | null {
  // Skip navigation breadcrumbs in development
  if (import.meta.env.DEV && breadcrumb.category === 'navigation') {
    return null;
  }

  // Skip frequent UI interactions
  if (
    breadcrumb.category === 'ui.click' &&
    breadcrumb.message?.includes('grade-selector')
  ) {
    return null;
  }

  return breadcrumb;
}

/// Filter performance transactions
function filterWebTransactions(event: Sentry.Transaction): Sentry.Transaction | null {
  // Don't track page loads for development
  if (import.meta.env.DEV && event.transaction?.includes('pageload')) {
    return null;
  }

  return event;
}

/// Get browser information
function getBrowserInfo(): string {
  const userAgent = navigator.userAgent;
  if (userAgent.includes('Chrome')) return 'chrome';
  if (userAgent.includes('Firefox')) return 'firefox';
  if (userAgent.includes('Safari')) return 'safari';
  if (userAgent.includes('Edge')) return 'edge';
  return 'unknown';
}

/// Get climbing-specific context
function getClimbingContext(): Record<string, any> {
  return {
    module: 'web',
    feature: 'error_tracking',
    timestamp: new Date().toISOString(),
    url: window.location.href,
    referrer: document.referrer,
  };
}

/// Web-specific error reporter
export class WebClimbingErrorReporter {
  /// Report error with web-specific context
  static reportError(
    error: Error,
    category: WebErrorCategory = WebErrorCategory.UNKNOWN,
    extra?: Record<string, any>,
    userAction?: string,
    fatal = false
  ): void {
    if (import.meta.env.DEV) {
      console.error(`🚨 Error [${category}]:`, error);
      return;
    }

    Sentry.withScope((scope) => {
      scope.setTag('error.category', category);
      scope.setTag('error.fatal', fatal.toString());
      
      if (userAction) {
        scope.setContext('user_action', { action: userAction });
      }

      if (extra) {
        scope.setContext('extra_data', extra);
      }

      scope.setLevel(fatal ? 'error' : 'warning');
      
      Sentry.captureException(error);
    });
  }

  /// Report performance issue
  static reportPerformanceIssue(
    operation: string,
    duration: number,
    category: PerformanceCategory,
    data?: Record<string, any>
  ): void {
    if (import.meta.env.DEV) {
      console.log(`⚡ Performance [${operation}]: ${duration}ms`);
      return;
    }

    const transaction = Sentry.startTransaction({
      name: operation,
      op: 'performance_issue',
    });

    transaction.setData('duration_ms', duration);
    transaction.setData('category', category);
    transaction.setData('operation', operation);

    if (data) {
      Object.entries(data).forEach(([key, value]) => {
        transaction.setData(key, value);
      });
    }

    transaction.finish();
  }

  /// Add breadcrumb for climbing action
  static addClimbingBreadcrumb(
    message: string,
    category = 'climbing',
    data?: Record<string, any>,
    level: Sentry.SeverityLevel = 'info'
  ): void {
    if (import.meta.env.DEV) {
      console.log(`🍞 Breadcrumb [${category}]: ${message}`);
      return;
    }

    Sentry.addBreadcrumb({
      message,
      category,
      data,
      level,
      timestamp: Date.now() / 1000,
    });
  }

  /// Set user context (privacy-safe)
  static setUserContext(userId?: string, userLevel?: string, sessionCount?: number): void {
    if (import.meta.env.DEV) return;

    Sentry.setUser({
      id: userId,
      // Don't include email or personal data
      ...(userLevel && { climbing_level: userLevel }),
      ...(sessionCount && { session_count: sessionCount }),
    });
  }

  /// Clear user context (on logout)
  static clearUserContext(): void {
    if (import.meta.env.DEV) return;
    Sentry.setUser(null);
  }

  /// Start performance transaction
  static startTransaction(name: string, op: string): Sentry.Transaction {
    return Sentry.startTransaction({ name, op });
  }

  /// Report user feedback
  static reportUserFeedback(
    feedbackId: string,
    userEmail: string,
    comment: string
  ): void {
    if (import.meta.env.DEV) {
      console.log('📝 User feedback:', comment);
      return;
    }

    Sentry.captureUserFeedback({
      event_id: feedbackId,
      email: userEmail,
      comments: comment,
    });
  }

  /// Capture API error with request details
  static captureApiError(
    error: Error,
    endpoint: string,
    method: string,
    statusCode?: number,
    requestData?: any
  ): void {
    this.reportError(
      error,
      WebErrorCategory.API,
      {
        endpoint,
        method,
        status_code: statusCode,
        request_data: requestData,
      },
      'api_call',
      statusCode ? statusCode >= 500 : false
    );
  }
}

/// React Error Boundary component with Sentry integration
export function createSentryErrorBoundary<P extends Record<string, any>>(
  FallbackComponent: React.ComponentType<{ error: Error; resetError: () => void }>
) {
  return Sentry.withErrorBoundary(
    React.memo<P>((props) => React.createElement(React.Fragment, null, props.children)),
    {
      fallback: ({ error, resetError }) => 
        React.createElement(FallbackComponent, { error, resetError }),
      beforeCapture: (scope, error, info) => {
        scope.setTag('error.boundary', 'react');
        scope.setContext('component_stack', { stack: info.componentStack });
      },
    }
  );
}

/// Hook for component-level error reporting
export function useErrorReporting(componentName: string) {
  const reportError = React.useCallback(
    (error: Error, extra?: Record<string, any>) => {
      WebClimbingErrorReporter.reportError(
        error,
        WebErrorCategory.UI,
        {
          component: componentName,
          ...extra,
        },
        'component_error'
      );
    },
    [componentName]
  );

  const reportPerformance = React.useCallback(
    (operation: string, duration: number, data?: Record<string, any>) => {
      WebClimbingErrorReporter.reportPerformanceIssue(
        operation,
        duration,
        PerformanceCategory.COMPONENT_RENDER,
        {
          component: componentName,
          ...data,
        }
      );
    },
    [componentName]
  );

  return { reportError, reportPerformance };
}

/// Performance measurement decorator
export function measurePerformance<T extends (...args: any[]) => any>(
  fn: T,
  operationName: string,
  category: PerformanceCategory
): T {
  return ((...args: Parameters<T>) => {
    const start = performance.now();
    const result = fn(...args);
    
    if (result instanceof Promise) {
      return result.finally(() => {
        const duration = performance.now() - start;
        WebClimbingErrorReporter.reportPerformanceIssue(
          operationName,
          duration,
          category
        );
      });
    } else {
      const duration = performance.now() - start;
      WebClimbingErrorReporter.reportPerformanceIssue(
        operationName,
        duration,
        category
      );
      return result;
    }
  }) as T;
} 
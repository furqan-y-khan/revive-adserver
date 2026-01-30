<?php
/**
 * Cloud Run / Load Balancer Proxy Fix
 * 
 * This file is auto-prepended to all PHP requests when running behind
 * Cloud Run or other reverse proxies that terminate SSL.
 * 
 * It ensures that PHP correctly detects HTTPS connections by reading
 * the X-Forwarded-Proto header set by the load balancer.
 */

// Only apply fixes when running in Cloud Run (K_SERVICE env var is set)
if (getenv('K_SERVICE') || getenv('CLOUD_RUN')) {
    
    // Trust X-Forwarded-Proto header from Cloud Run load balancer
    if (
        isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && 
        strtolower($_SERVER['HTTP_X_FORWARDED_PROTO']) === 'https'
    ) {
        // Set HTTPS server variable so PHP and the app know we're on HTTPS
        $_SERVER['HTTPS'] = 'on';
        $_SERVER['SERVER_PORT'] = 443;
    }
    
    // Also check X-Forwarded-SSL header (some proxies use this)
    if (
        isset($_SERVER['HTTP_X_FORWARDED_SSL']) && 
        strtolower($_SERVER['HTTP_X_FORWARDED_SSL']) === 'on'
    ) {
        $_SERVER['HTTPS'] = 'on';
        $_SERVER['SERVER_PORT'] = 443;
    }
}

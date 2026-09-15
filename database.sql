-- SEO 80/20 System Database Schema
CREATE DATABASE IF NOT EXISTS seo_system CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE seo_system;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    role VARCHAR(50) DEFAULT 'client',
    allowed_menus TEXT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    website_url VARCHAR(255) NOT NULL,
    target_keyword TEXT DEFAULT NULL,
    target_site TEXT DEFAULT NULL,
    package_type VARCHAR(50) DEFAULT 'basic',
    business_name VARCHAR(255) DEFAULT '',
    contact_name VARCHAR(255) DEFAULT '',
    phone VARCHAR(50) DEFAULT '',
    email VARCHAR(255) DEFAULT '',
    category VARCHAR(100) DEFAULT NULL,
    gsc_access TEXT DEFAULT NULL,
    ga_access TEXT DEFAULT NULL,
    google_ads_id VARCHAR(100) DEFAULT NULL,
    business_address TEXT DEFAULT NULL,
    business_hours VARCHAR(255) DEFAULT NULL,
    admin_url VARCHAR(255) DEFAULT '',
    admin_user VARCHAR(255) DEFAULT '',
    admin_pass TEXT DEFAULT NULL,
    competitor_sites TEXT DEFAULT NULL,
    business_desc TEXT DEFAULT NULL,
    post_image VARCHAR(255) DEFAULT NULL,
    onboarding_token VARCHAR(255) DEFAULT NULL,
    pagespeed_mobile_score INT DEFAULT NULL,
    pagespeed_desktop_score INT DEFAULT NULL,
    pagespeed_metrics_json TEXT DEFAULT NULL,
    pagespeed_checked_at DATETIME DEFAULT NULL,
    status VARCHAR(50) DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Social Accounts table
CREATE TABLE IF NOT EXISTS social_accounts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL DEFAULT 0,
    project_id INT NOT NULL DEFAULT 0,
    platform VARCHAR(100) NOT NULL,
    username VARCHAR(255) DEFAULT NULL,
    password VARCHAR(255) DEFAULT NULL,
    api_key TEXT DEFAULT NULL,
    api_secret TEXT DEFAULT NULL,
    refresh_token TEXT DEFAULT NULL,
    access_token TEXT DEFAULT NULL,
    extra_data TEXT DEFAULT NULL,
    profile_url VARCHAR(500) DEFAULT NULL,
    status VARCHAR(50) DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_user_platform (user_id, platform),
    KEY idx_project_platform (project_id, platform)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Project Meta table
CREATE TABLE IF NOT EXISTS project_meta (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    meta_key VARCHAR(100) NOT NULL,
    meta_value TEXT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_project_meta (project_id, meta_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Backlinks table
CREATE TABLE IF NOT EXISTS backlinks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    backlink_url VARCHAR(500) NOT NULL,
    platform VARCHAR(100) DEFAULT NULL,
    da_score INT DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending',
    indexed_status VARCHAR(50) DEFAULT 'unchecked',
    last_checked DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_project_backlink (project_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Keywords table
CREATE TABLE IF NOT EXISTS keywords (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    keyword VARCHAR(255) NOT NULL,
    current_rank INT DEFAULT 0,
    previous_rank INT DEFAULT 0,
    target_url VARCHAR(500) DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_project_keyword (project_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- SEO Reports table
CREATE TABLE IF NOT EXISTS seo_reports (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    `rank` INT DEFAULT 0,
    seo_score INT DEFAULT 0,
    report_date DATE DEFAULT NULL,
    report_type VARCHAR(50) DEFAULT 'general',
    report_data LONGTEXT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_project_report (project_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Backlink Queue table
CREATE TABLE IF NOT EXISTS backlink_queue (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    social_account_id INT DEFAULT NULL,
    platform VARCHAR(100) NOT NULL,
    keyword VARCHAR(255) DEFAULT NULL,
    target_url VARCHAR(500) DEFAULT NULL,
    published_url VARCHAR(500) DEFAULT NULL,
    error_message TEXT DEFAULT NULL,
    payload LONGTEXT DEFAULT NULL,
    post_image VARCHAR(255) DEFAULT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    scheduled_at DATETIME DEFAULT NULL,
    executed_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    response_log TEXT DEFAULT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_queue_status (status, scheduled_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- System Settings table
CREATE TABLE IF NOT EXISTS system_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value TEXT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Broken Internal Links table
CREATE TABLE IF NOT EXISTS broken_internal_links (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    source_url VARCHAR(500) NOT NULL,
    broken_url VARCHAR(500) NOT NULL,
    http_code INT DEFAULT 0,
    status VARCHAR(50) DEFAULT 'open',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_project_broken (project_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Keyword Rankings Log table
CREATE TABLE IF NOT EXISTS keyword_rankings_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    keyword VARCHAR(255) NOT NULL,
    rank_position INT DEFAULT 0,
    checked_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    KEY idx_project_rank_log (project_id, keyword)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

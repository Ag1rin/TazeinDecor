-- Migration: Add brand_name and brand_thumbnail columns to companies table
ALTER TABLE companies ADD COLUMN IF NOT EXISTS brand_name VARCHAR;
ALTER TABLE companies ADD COLUMN IF NOT EXISTS brand_thumbnail VARCHAR;


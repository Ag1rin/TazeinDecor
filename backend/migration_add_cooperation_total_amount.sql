-- Migration: Add cooperation_total_amount column to orders table
-- This field stores the calculated total from calculator (sum of item.total + tax - discount)

-- For PostgreSQL
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cooperation_total_amount DOUBLE PRECISION;

-- For SQLite (uncomment if using SQLite)
-- ALTER TABLE orders ADD COLUMN cooperation_total_amount REAL;


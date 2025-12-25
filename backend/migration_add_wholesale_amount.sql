-- Migration: Add wholesale_amount column to orders table
-- This column stores the wholesale/cooperation price (actual seller payment)

-- For PostgreSQL:
ALTER TABLE orders ADD COLUMN IF NOT EXISTS wholesale_amount DOUBLE PRECISION;

-- For SQLite (if needed):
-- ALTER TABLE orders ADD COLUMN wholesale_amount REAL;


-- Migration: Add invoice fields to orders table
-- Run this SQL script on your PostgreSQL database

-- Add invoice fields
ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoice_number VARCHAR(255);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS issue_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS due_date TIMESTAMP WITH TIME ZONE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS subtotal REAL;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tax_amount REAL DEFAULT 0.0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount_amount REAL DEFAULT 0.0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_terms TEXT;

-- Add edit approval fields
ALTER TABLE orders ADD COLUMN IF NOT EXISTS edit_requested_by INTEGER;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS edit_requested_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS edit_approved_by INTEGER;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS edit_approved_at TIMESTAMP WITH TIME ZONE;

-- Add foreign key constraints (if they don't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_orders_edit_requested_by'
    ) THEN
        ALTER TABLE orders 
        ADD CONSTRAINT fk_orders_edit_requested_by 
        FOREIGN KEY (edit_requested_by) REFERENCES users(id);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_orders_edit_approved_by'
    ) THEN
        ALTER TABLE orders 
        ADD CONSTRAINT fk_orders_edit_approved_by 
        FOREIGN KEY (edit_approved_by) REFERENCES users(id);
    END IF;
END $$;

-- Create index on invoice_number for faster searches
CREATE INDEX IF NOT EXISTS idx_orders_invoice_number ON orders(invoice_number);


-- Migration: Add referral code system
-- Created: 2024-12-17
-- Description: Adds referral_code to users and referrer_id to orders

-- Add referral_code column to users table
-- This column stores a unique 8-character referral code for sellers and store managers
ALTER TABLE users ADD COLUMN IF NOT EXISTS referral_code VARCHAR(10) UNIQUE;

-- Create index for faster referral code lookups
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON users(referral_code) WHERE referral_code IS NOT NULL;

-- Add referrer_id column to orders table
-- This column tracks which user referred the order (via their referral code)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS referrer_id INTEGER REFERENCES users(id);

-- Create index for referrer lookups in reports
CREATE INDEX IF NOT EXISTS idx_orders_referrer_id ON orders(referrer_id) WHERE referrer_id IS NOT NULL;

-- Generate referral codes for existing sellers and store managers who don't have one
-- Uses a random 8-character uppercase alphanumeric code
DO $$
DECLARE
    rec RECORD;
    new_code VARCHAR(10);
    code_exists BOOLEAN;
BEGIN
    FOR rec IN SELECT id FROM users WHERE role IN ('seller', 'store_manager') AND referral_code IS NULL
    LOOP
        LOOP
            -- Generate random 8-character alphanumeric code
            new_code := upper(substring(md5(random()::text) for 8));
            
            -- Check if code already exists
            SELECT EXISTS(SELECT 1 FROM users WHERE referral_code = new_code) INTO code_exists;
            
            -- Exit loop if code is unique
            EXIT WHEN NOT code_exists;
        END LOOP;
        
        -- Update user with new referral code
        UPDATE users SET referral_code = new_code WHERE id = rec.id;
        RAISE NOTICE 'Generated referral code % for user %', new_code, rec.id;
    END LOOP;
END $$;

-- Verify migration
SELECT 'Users with referral codes:' as info, count(*) as count FROM users WHERE referral_code IS NOT NULL;
SELECT 'Orders with referrers:' as info, count(*) as count FROM orders WHERE referrer_id IS NOT NULL;


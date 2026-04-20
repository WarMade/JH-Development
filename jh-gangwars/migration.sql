-- 1. Add the new flexible JSON column
ALTER TABLE `dealer_data` ADD COLUMN IF NOT EXISTS `inventory` LONGTEXT DEFAULT '{}';

-- 2. Ensure uncollected matches the current schema
ALTER TABLE `dealer_data` MODIFY COLUMN `uncollected` INT(11) DEFAULT 0;

-- 3. Add reputation support
ALTER TABLE `dealer_data` ADD COLUMN IF NOT EXISTS `reputation` INT(11) DEFAULT 0;

-- 4. Remove the old, single-drug columns that are now obsolete
ALTER TABLE `dealer_data` DROP COLUMN IF EXISTS `item`;
ALTER TABLE `dealer_data` DROP COLUMN IF EXISTS `bulk_stock`;
ALTER TABLE `dealer_data` DROP COLUMN IF EXISTS `baggy_stock`;
ALTER TABLE `dealer_data` DROP COLUMN IF EXISTS `strain`;
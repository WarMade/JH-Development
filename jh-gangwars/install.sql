CREATE TABLE IF NOT EXISTS `dealer_data` (
  `dealerid` varchar(50) NOT NULL,
  `inventory` longtext DEFAULT '{}',
  `uncollected` int(11) DEFAULT 0,
  `reputation` int(11) DEFAULT 0,
  PRIMARY KEY (`dealerid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `dealer_data` MODIFY COLUMN `inventory` LONGTEXT;
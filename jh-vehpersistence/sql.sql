CREATE TABLE IF NOT EXISTS `player_persistent_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `plate` varchar(8) NOT NULL,
  `model` varchar(60) NOT NULL,
  `x` float NOT NULL,
  `y` float NOT NULL,
  `z` float NOT NULL,
  `heading` float NOT NULL,
  `properties` longtext NOT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_citizenid_plate` (`citizenid`,`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
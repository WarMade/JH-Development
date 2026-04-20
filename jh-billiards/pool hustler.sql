CREATE TABLE IF NOT EXISTS `billiards_leaderboard` (
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `wins` INT(11) DEFAULT 0,
    `losses` INT(11) DEFAULT 0,
    PRIMARY KEY (`citizenid`)
);
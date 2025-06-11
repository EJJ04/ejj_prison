CREATE TABLE IF NOT EXISTS `ejj_prison` (
  `identifier` varchar(50) NOT NULL,
  `time` int(11) NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `inventory` json DEFAULT NULL,
  `prison` varchar(50) DEFAULT 'bolingbroke',
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci; 

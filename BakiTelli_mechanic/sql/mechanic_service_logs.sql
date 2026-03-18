CREATE TABLE IF NOT EXISTS `mechanic_service_logs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `plate` VARCHAR(16) NOT NULL,
  `service_type` VARCHAR(32) NOT NULL,
  `mechanic_license` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_plate_created` (`plate`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

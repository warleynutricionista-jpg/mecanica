-- ============================================================
-- VRS_MECHANIC - BANCO DE DADOS
-- Execute este arquivo no seu banco de dados MySQL/MariaDB
-- ============================================================

-- Status dos veículos (persistência)
CREATE TABLE IF NOT EXISTS `vrs_mechanic_vehicle_status` (
    `plate` VARCHAR(20) NOT NULL,
    `status` LONGTEXT NOT NULL DEFAULT '{}',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`plate`),
    INDEX `idx_updated` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ordens de serviço
CREATE TABLE IF NOT EXISTS `vrs_mechanic_work_orders` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` VARCHAR(50) NOT NULL,
    `plate` VARCHAR(20) NOT NULL,
    `model` VARCHAR(50) DEFAULT '',
    `owner_name` VARCHAR(100) DEFAULT 'Desconhecido',
    `mechanic_name` VARCHAR(100) NOT NULL,
    `mechanic_citizenid` VARCHAR(50) NOT NULL,
    `problems` LONGTEXT DEFAULT '[]',
    `materials` LONGTEXT DEFAULT '[]',
    `budget` FLOAT DEFAULT 0,
    `notes` TEXT DEFAULT '',
    `status` VARCHAR(20) NOT NULL DEFAULT 'open',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_shop` (`shop_id`),
    INDEX `idx_plate` (`plate`),
    INDEX `idx_status` (`status`),
    INDEX `idx_mechanic` (`mechanic_citizenid`),
    INDEX `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Funcionários das oficinas
CREATE TABLE IF NOT EXISTS `vrs_mechanic_employees` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` VARCHAR(50) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `grade` INT(11) NOT NULL DEFAULT 0,
    `hired_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_shop_citizen` (`shop_id`, `citizenid`),
    INDEX `idx_shop` (`shop_id`),
    INDEX `idx_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sobrescrita de preços por oficina
CREATE TABLE IF NOT EXISTS `vrs_mechanic_price_overrides` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` VARCHAR(50) NOT NULL,
    `service` VARCHAR(50) NOT NULL,
    `price` FLOAT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_shop_service` (`shop_id`, `service`),
    INDEX `idx_shop` (`shop_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Logs de serviços / faturamento
CREATE TABLE IF NOT EXISTS `vrs_mechanic_service_logs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` VARCHAR(50) NOT NULL DEFAULT 'system',
    `mechanic_citizenid` VARCHAR(50) DEFAULT NULL,
    `mechanic_name` VARCHAR(100) DEFAULT NULL,
    `customer_citizenid` VARCHAR(50) DEFAULT NULL,
    `customer_name` VARCHAR(100) DEFAULT NULL,
    `service_type` VARCHAR(50) NOT NULL DEFAULT 'unknown',
    `amount` FLOAT DEFAULT 0,
    `description` TEXT DEFAULT '',
    `work_order_id` INT(11) DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_shop` (`shop_id`),
    INDEX `idx_mechanic` (`mechanic_citizenid`),
    INDEX `idx_customer` (`customer_citizenid`),
    INDEX `idx_created` (`created_at`),
    INDEX `idx_type` (`service_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dados das oficinas (saldo society, proprietário)
CREATE TABLE IF NOT EXISTS `vrs_mechanic_shops` (
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `balance` FLOAT NOT NULL DEFAULT 0,
    `owner_citizenid` VARCHAR(50) DEFAULT NULL,
    `owner_name` VARCHAR(100) DEFAULT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

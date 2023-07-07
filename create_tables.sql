-- /tmp/create_tables.sql

-- Drop devices table if exists
DROP TABLE IF EXISTS `devices`;

-- Create devices table
CREATE TABLE `devices` (
  `id` INT AUTO_INCREMENT,
  `type` LONGTEXT,
  `device_name` VARCHAR(191) NOT NULL,
  `display_name` LONGTEXT,
  `private_key` LONGTEXT,
  `listen_port` BIGINT DEFAULT NULL,
  `firewall_mark` INT DEFAULT NULL,
  `public_key` LONGTEXT,
  `mtu` BIGINT DEFAULT NULL,
  `ips_str` LONGTEXT,
  `dns_str` LONGTEXT,
  `routing_table` LONGTEXT,
  `pre_up` LONGTEXT,
  `post_up` LONGTEXT,
  `pre_down` LONGTEXT,
  `post_down` LONGTEXT,
  `save_config` TINYINT(1) DEFAULT NULL,
  `default_endpoint` LONGTEXT,
  `default_allowed_ips_str` LONGTEXT,
  `default_persistent_keepalive` BIGINT DEFAULT NULL,
  `created_at` DATETIME(3) DEFAULT NULL,
  `updated_at` DATETIME(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY (`device_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Drop peers table if exists
DROP TABLE IF EXISTS `peers`;

-- Create peers table
CREATE TABLE `peers` (
  `uid` LONGTEXT,
  `device_id` INT DEFAULT NULL,
  `identifier` LONGTEXT,
  `email` VARCHAR(191) DEFAULT NULL,
  `ignore_global_settings` TINYINT(1) DEFAULT NULL,
  `public_key` VARCHAR(191) NOT NULL,
  `preshared_key` LONGTEXT,
  `allowed_ips_str` LONGTEXT,
  `allowed_ips_srv_str` LONGTEXT,
  `endpoint` LONGTEXT,
  `persistent_keepalive` BIGINT DEFAULT NULL,
  `private_key` LONGTEXT,
  `ips_str` LONGTEXT,
  `dns_str` LONGTEXT,
  `mtu` BIGINT DEFAULT NULL,
  `deactivated_at` DATETIME(3) DEFAULT NULL,
  `deactivated_reason` LONGTEXT,
  `expires_at` DATETIME(3) DEFAULT NULL,
  `created_by` LONGTEXT,
  `updated_by` LONGTEXT,
  `created_at` DATETIME(3) DEFAULT NULL,
  `updated_at` DATETIME(3) DEFAULT NULL,
  PRIMARY KEY (`public_key`),
  KEY `idx_peers_email` (`email`),
  KEY `idx_peers_device_id` (`device_id`),
  CONSTRAINT `fk_devices_peers` FOREIGN KEY (`device_id`) REFERENCES `devices` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

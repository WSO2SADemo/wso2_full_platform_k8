-- MySQL Database Schema for File Transfer Tracking

CREATE DATABASE IF NOT EXISTS file_transfer_db;

USE file_transfer_db;

CREATE TABLE IF NOT EXISTS file_transfers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    source_location VARCHAR(500) NOT NULL,
    destination_location VARCHAR(500) NOT NULL,
    transfer_status VARCHAR(50) NOT NULL,
    transferred_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_file_name (file_name),
    INDEX idx_transfer_status (transfer_status),
    INDEX idx_transferred_at (transferred_at)
);

-- Employee Table
CREATE TABLE IF NOT EXISTS employee (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address VARCHAR(500) NOT NULL,
    mobile VARCHAR(20) NOT NULL,
    INDEX idx_name (name)
);

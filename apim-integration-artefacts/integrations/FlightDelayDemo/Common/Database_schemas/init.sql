-- =============================================================================
-- Autonomous Disruption Recovery (ADR) — Flight Delay Demo
-- Database Initialization Script
-- =============================================================================

CREATE DATABASE IF NOT EXISTS flight_delay_db;
USE flight_delay_db;

-- Create application user
CREATE USER IF NOT EXISTS 'adr_user'@'%' IDENTIFIED BY 'adr_password';
GRANT ALL PRIVILEGES ON flight_delay_db.* TO 'adr_user'@'%';
FLUSH PRIVILEGES;

-- =============================================================================
-- FLIGHTS & DISRUPTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS flights (
    flight_id VARCHAR(20) PRIMARY KEY,
    airline VARCHAR(50) NOT NULL,
    flight_number VARCHAR(20) NOT NULL,
    origin VARCHAR(10) NOT NULL,
    destination VARCHAR(10) NOT NULL,
    scheduled_departure DATETIME NOT NULL,
    scheduled_arrival DATETIME NOT NULL,
    actual_departure DATETIME,
    actual_arrival DATETIME,
    aircraft_type VARCHAR(50),
    gate VARCHAR(10),
    status ENUM('UNSCHEDULED', 'AVAILABLE', 'SCHEDULED', 'BOARDING', 'DELAYED', 'CANCELLED', 'DEPARTED', 'ARRIVED') DEFAULT 'UNSCHEDULED',
    passenger_count INT DEFAULT 0,
    -- Seat capacity per class
    seats_first INT DEFAULT 0,
    seats_business INT DEFAULT 0,
    seats_premium_economy INT DEFAULT 0,
    seats_economy INT DEFAULT 0,
    -- Crew requirements
    required_captains INT DEFAULT 1,
    required_first_officers INT DEFAULT 1,
    required_cabin_crew_leads INT DEFAULT 1,
    required_cabin_crew INT DEFAULT 2,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS disruptions (
    disruption_id VARCHAR(36) PRIMARY KEY,
    flight_id VARCHAR(20) NOT NULL,
    disruption_type ENUM('DELAY', 'CANCELLATION', 'DIVERSION') NOT NULL,
    delay_minutes INT DEFAULT 0,
    reason VARCHAR(500),
    severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') DEFAULT 'MEDIUM',
    status ENUM('DETECTED', 'RECOVERY_IN_PROGRESS', 'RESOLVED') DEFAULT 'DETECTED',
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

-- =============================================================================
-- CREW MANAGEMENT
-- =============================================================================

CREATE TABLE IF NOT EXISTS crew_members (
    crew_id VARCHAR(20) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role ENUM('CAPTAIN', 'FIRST_OFFICER', 'CABIN_CREW_LEAD', 'CABIN_CREW') NOT NULL,
    base_airport VARCHAR(10) NOT NULL,
    duty_hours_today DECIMAL(4,1) DEFAULT 0.0,
    max_duty_hours DECIMAL(4,1) DEFAULT 14.0,
    status ENUM('AVAILABLE', 'ON_DUTY', 'RESTING', 'OFF_DUTY') DEFAULT 'AVAILABLE',
    phone VARCHAR(20),
    email VARCHAR(100),
    certification VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS crew_assignments (
    assignment_id VARCHAR(36) PRIMARY KEY,
    crew_id VARCHAR(20) NOT NULL,
    flight_id VARCHAR(20) NOT NULL,
    role VARCHAR(50) NOT NULL,
    duty_start DATETIME,
    duty_end DATETIME,
    status ENUM('ASSIGNED', 'CHECKED_IN', 'COMPLETED', 'REASSIGNED') DEFAULT 'ASSIGNED',
    FOREIGN KEY (crew_id) REFERENCES crew_members(crew_id),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

-- =============================================================================
-- PASSENGERS & BOOKINGS
-- =============================================================================

CREATE TABLE IF NOT EXISTS passengers (
    passenger_id VARCHAR(20) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150),
    phone VARCHAR(20),
    loyalty_tier ENUM('STANDARD', 'SILVER', 'GOLD', 'PLATINUM') DEFAULT 'STANDARD',
    loyalty_points INT DEFAULT 0,
    special_needs VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS bookings (
    booking_id VARCHAR(36) PRIMARY KEY,
    passenger_id VARCHAR(20) NOT NULL,
    flight_id VARCHAR(20) NOT NULL,
    seat_number VARCHAR(10),
    booking_class ENUM('ECONOMY', 'PREMIUM_ECONOMY', 'BUSINESS', 'FIRST') DEFAULT 'ECONOMY',
    status ENUM('CONFIRMED', 'CHECKED_IN', 'REBOOKED', 'CANCELLED', 'NO_SHOW') DEFAULT 'CONFIRMED',
    original_flight_id VARCHAR(20),
    rebooked_at TIMESTAMP,
    FOREIGN KEY (passenger_id) REFERENCES passengers(passenger_id),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

CREATE TABLE IF NOT EXISTS notifications (
    notification_id VARCHAR(36) PRIMARY KEY,
    passenger_id VARCHAR(20) NOT NULL,
    notification_type ENUM('SMS', 'EMAIL', 'PUSH') NOT NULL,
    message TEXT NOT NULL,
    status ENUM('PENDING', 'SENT', 'DELIVERED', 'FAILED') DEFAULT 'PENDING',
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (passenger_id) REFERENCES passengers(passenger_id)
);

CREATE TABLE IF NOT EXISTS compensations (
    compensation_id VARCHAR(36) PRIMARY KEY,
    passenger_id VARCHAR(20) NOT NULL,
    flight_id VARCHAR(20) NOT NULL,
    compensation_type ENUM('VOUCHER', 'HOTEL', 'MEAL', 'TAXI', 'LOUNGE_ACCESS', 'MILES', 'REFUND') NOT NULL,
    amount DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'USD',
    description VARCHAR(500),
    status ENUM('PENDING', 'APPROVED', 'ISSUED', 'REDEEMED') DEFAULT 'PENDING',
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (passenger_id) REFERENCES passengers(passenger_id),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

-- =============================================================================
-- LOGISTICS & RESOURCES
-- =============================================================================

CREATE TABLE IF NOT EXISTS gates (
    gate_id VARCHAR(10) PRIMARY KEY,
    airport VARCHAR(10) NOT NULL,
    terminal VARCHAR(10) NOT NULL,
    gate_type ENUM('NARROW_BODY', 'WIDE_BODY', 'REGIONAL') DEFAULT 'NARROW_BODY',
    status ENUM('AVAILABLE', 'OCCUPIED', 'MAINTENANCE') DEFAULT 'AVAILABLE',
    assigned_flight_id VARCHAR(20),
    FOREIGN KEY (assigned_flight_id) REFERENCES flights(flight_id)
);

CREATE TABLE IF NOT EXISTS catering_orders (
    order_id VARCHAR(36) PRIMARY KEY,
    flight_id VARCHAR(20) NOT NULL,
    meal_count INT NOT NULL,
    special_meals INT DEFAULT 0,
    status ENUM('PREPARING', 'READY', 'LOADED', 'REDIRECTED', 'CANCELLED') DEFAULT 'PREPARING',
    delivery_gate VARCHAR(10),
    notes VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

CREATE TABLE IF NOT EXISTS ground_handling_tasks (
    task_id VARCHAR(36) PRIMARY KEY,
    flight_id VARCHAR(20) NOT NULL,
    task_type ENUM('BAGGAGE_TRANSFER', 'FUELING', 'CLEANING', 'DE_ICING', 'PUSHBACK', 'GATE_CHANGE') NOT NULL,
    assigned_team VARCHAR(50),
    status ENUM('PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') DEFAULT 'PENDING',
    gate VARCHAR(10),
    notes VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

-- =============================================================================
-- RECOVERY PLANS (ADR Orchestrator)
-- =============================================================================

CREATE TABLE IF NOT EXISTS recovery_plans (
    plan_id VARCHAR(36) PRIMARY KEY,
    disruption_id VARCHAR(36) NOT NULL,
    flight_id VARCHAR(20) NOT NULL,
    status ENUM('PLANNING', 'NEGOTIATING', 'APPROVED', 'EXECUTING', 'COMPLETED', 'FAILED') DEFAULT 'PLANNING',
    total_passengers_affected INT DEFAULT 0,
    passengers_rebooked INT DEFAULT 0,
    crew_reassignments INT DEFAULT 0,
    gate_changes INT DEFAULT 0,
    estimated_cost DECIMAL(12,2) DEFAULT 0.00,
    total_compensations DECIMAL(12,2) DEFAULT 0.00,
    negotiation_log JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    FOREIGN KEY (disruption_id) REFERENCES disruptions(disruption_id),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

-- =============================================================================
-- SEAT INVENTORY (real-time seat tracking per class per flight)
-- =============================================================================

CREATE TABLE IF NOT EXISTS seat_inventory (
    id INT AUTO_INCREMENT PRIMARY KEY,
    flight_id VARCHAR(20) NOT NULL,
    seat_class ENUM('FIRST', 'BUSINESS', 'PREMIUM_ECONOMY', 'ECONOMY') NOT NULL,
    total_seats INT DEFAULT 0,
    booked_seats INT DEFAULT 0,
    UNIQUE KEY uq_flight_seat_class (flight_id, seat_class),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

-- =============================================================================
-- FLIGHT CREW REQUIREMENTS (tracks required vs assigned crew per flight)
-- =============================================================================

CREATE TABLE IF NOT EXISTS flight_crew_requirements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    flight_id VARCHAR(20) NOT NULL,
    role ENUM('CAPTAIN', 'FIRST_OFFICER', 'CABIN_CREW_LEAD', 'CABIN_CREW') NOT NULL,
    required_count INT DEFAULT 0,
    assigned_count INT DEFAULT 0,
    UNIQUE KEY uq_flight_crew_role (flight_id, role),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

-- =============================================================================
-- PASSENGER FLIGHT HISTORY (tracks all flight assignment changes)
-- =============================================================================

CREATE TABLE IF NOT EXISTS passenger_flight_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    passenger_id VARCHAR(20) NOT NULL,
    flight_id VARCHAR(20) NOT NULL,
    booking_id VARCHAR(36),
    action ENUM('BOOKED', 'REBOOKED', 'CANCELLED', 'COMPENSATED', 'COMPLETED') NOT NULL,
    seat_class ENUM('FIRST', 'BUSINESS', 'PREMIUM_ECONOMY', 'ECONOMY'),
    seat_number VARCHAR(10),
    notes VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (passenger_id) REFERENCES passengers(passenger_id),
    FOREIGN KEY (flight_id) REFERENCES flights(flight_id)
);

-- =============================================================================
-- SEED DATA
-- =============================================================================

-- Flights (with seat capacity and crew requirements)
INSERT INTO flights (flight_id, airline, flight_number, origin, destination, scheduled_departure, scheduled_arrival, aircraft_type, gate, status, passenger_count, seats_first, seats_business, seats_premium_economy, seats_economy, required_captains, required_first_officers, required_cabin_crew_leads, required_cabin_crew) VALUES
('FL001', 'British Airways', 'BA256', 'LHR', 'JFK', '2026-02-14 08:00:00', '2026-02-14 11:30:00', 'Boeing 777-300ER', 'A14', 'SCHEDULED', 312, 14, 48, 40, 235, 1, 1, 2, 10),
('FL002', 'British Airways', 'BA123', 'LHR', 'CDG', '2026-02-14 09:30:00', '2026-02-14 10:45:00', 'Airbus A320', 'B07', 'SCHEDULED', 156, 0, 12, 18, 150, 1, 1, 1, 3),
('FL003', 'British Airways', 'BA125', 'LHR', 'CDG', '2026-02-14 12:00:00', '2026-02-14 13:15:00', 'Airbus A320', 'B12', 'AVAILABLE', 0, 0, 12, 18, 150, 1, 1, 1, 3),
('FL004', 'British Airways', 'BA456', 'LHR', 'FRA', '2026-02-14 10:00:00', '2026-02-14 12:30:00', 'Airbus A321', 'C03', 'SCHEDULED', 198, 0, 20, 24, 175, 1, 1, 1, 4),
('FL005', 'British Airways', 'BA789', 'LHR', 'MAD', '2026-02-14 14:00:00', '2026-02-14 17:15:00', 'Boeing 737-800', 'A09', 'SCHEDULED', 145, 0, 16, 0, 162, 1, 1, 1, 3),
('FL006', 'British Airways', 'BA321', 'LHR', 'JFK', '2026-02-14 15:00:00', '2026-02-14 18:30:00', 'Boeing 777-300ER', 'A22', 'SCHEDULED', 205, 14, 48, 40, 235, 1, 1, 2, 10),
('FL007', 'British Airways', 'BA654', 'LHR', 'DXB', '2026-02-14 22:00:00', '2026-02-15 06:30:00', 'Boeing 787-9', 'A18', 'SCHEDULED', 267, 8, 42, 21, 216, 1, 1, 2, 8),
('FL008', 'British Airways', 'BA258', 'LHR', 'JFK', '2026-02-15 08:00:00', '2026-02-15 11:30:00', 'Boeing 777-300ER', NULL, 'UNSCHEDULED', 0, 14, 48, 40, 235, 1, 1, 2, 10),
('FL009', 'British Airways', 'BA127', 'LHR', 'CDG', '2026-02-15 09:00:00', '2026-02-15 10:15:00', 'Airbus A320', NULL, 'UNSCHEDULED', 0, 0, 12, 18, 150, 1, 1, 1, 3),
('FL010', 'British Airways', 'BA458', 'LHR', 'FRA', '2026-02-15 10:00:00', '2026-02-15 12:30:00', 'Airbus A321', NULL, 'AVAILABLE', 0, 0, 20, 24, 175, 1, 1, 1, 4);

-- Crew Members
INSERT INTO crew_members (crew_id, first_name, last_name, role, base_airport, duty_hours_today, max_duty_hours, status, phone, email, certification) VALUES
('CRW001', 'James', 'Wilson', 'CAPTAIN', 'LHR', 6.5, 14.0, 'ON_DUTY', '+44-7700-100001', 'j.wilson@ba.com', 'Boeing 777 Type Rating'),
('CRW002', 'Sarah', 'Mitchell', 'FIRST_OFFICER', 'LHR', 6.5, 14.0, 'ON_DUTY', '+44-7700-100002', 's.mitchell@ba.com', 'Boeing 777 Type Rating'),
('CRW003', 'David', 'Chen', 'CABIN_CREW_LEAD', 'LHR', 5.0, 14.0, 'ON_DUTY', '+44-7700-100003', 'd.chen@ba.com', 'Senior Cabin Crew'),
('CRW004', 'Emma', 'Rodriguez', 'CAPTAIN', 'LHR', 2.0, 14.0, 'AVAILABLE', '+44-7700-100004', 'e.rodriguez@ba.com', 'Airbus A320 Type Rating'),
('CRW005', 'Michael', 'O''Brien', 'FIRST_OFFICER', 'LHR', 1.5, 14.0, 'AVAILABLE', '+44-7700-100005', 'm.obrien@ba.com', 'Airbus A320/A321 Type Rating'),
('CRW006', 'Lisa', 'Thompson', 'CAPTAIN', 'LHR', 12.0, 14.0, 'ON_DUTY', '+44-7700-100006', 'l.thompson@ba.com', 'Airbus A320 Type Rating'),
('CRW007', 'Robert', 'Patel', 'FIRST_OFFICER', 'LHR', 11.5, 14.0, 'ON_DUTY', '+44-7700-100007', 'r.patel@ba.com', 'Airbus A320 Type Rating'),
('CRW008', 'Anna', 'Kowalski', 'CABIN_CREW_LEAD', 'LHR', 3.0, 14.0, 'AVAILABLE', '+44-7700-100008', 'a.kowalski@ba.com', 'Senior Cabin Crew'),
('CRW009', 'Thomas', 'Nguyen', 'CABIN_CREW', 'LHR', 0.0, 14.0, 'AVAILABLE', '+44-7700-100009', 't.nguyen@ba.com', 'Cabin Crew'),
('CRW010', 'Sophie', 'Martin', 'CABIN_CREW', 'LHR', 0.0, 14.0, 'AVAILABLE', '+44-7700-100010', 's.martin@ba.com', 'Cabin Crew');

-- Crew Assignments
INSERT INTO crew_assignments (assignment_id, crew_id, flight_id, role, duty_start, duty_end, status) VALUES
('ASGN001', 'CRW001', 'FL001', 'CAPTAIN', '2026-02-14 06:00:00', '2026-02-14 13:00:00', 'ASSIGNED'),
('ASGN002', 'CRW002', 'FL001', 'FIRST_OFFICER', '2026-02-14 06:00:00', '2026-02-14 13:00:00', 'ASSIGNED'),
('ASGN003', 'CRW003', 'FL001', 'CABIN_CREW_LEAD', '2026-02-14 06:00:00', '2026-02-14 13:00:00', 'ASSIGNED'),
('ASGN004', 'CRW006', 'FL002', 'CAPTAIN', '2026-02-14 07:30:00', '2026-02-14 12:00:00', 'ASSIGNED'),
('ASGN005', 'CRW007', 'FL002', 'FIRST_OFFICER', '2026-02-14 07:30:00', '2026-02-14 12:00:00', 'ASSIGNED');

-- Passengers (sample — representing different loyalty tiers)
INSERT INTO passengers (passenger_id, first_name, last_name, email, phone, loyalty_tier, loyalty_points, special_needs) VALUES
('PAX001', 'Elizabeth', 'Harrington', 'e.harrington@email.com', '+44-7700-200001', 'PLATINUM', 285000, NULL),
('PAX002', 'Ahmed', 'Al-Rashid', 'a.alrashid@email.com', '+971-50-200002', 'GOLD', 120000, 'Wheelchair assistance'),
('PAX003', 'Maria', 'Gonzalez', 'm.gonzalez@email.com', '+34-600-200003', 'SILVER', 45000, NULL),
('PAX004', 'John', 'Smith', 'j.smith@email.com', '+1-555-200004', 'STANDARD', 5000, NULL),
('PAX005', 'Yuki', 'Tanaka', 'y.tanaka@email.com', '+81-90-200005', 'PLATINUM', 310000, 'Kosher meals'),
('PAX006', 'Pierre', 'Dubois', 'p.dubois@email.com', '+33-6-200006', 'GOLD', 98000, NULL),
('PAX007', 'Olga', 'Petrova', 'o.petrova@email.com', '+7-916-200007', 'STANDARD', 2000, 'Unaccompanied minor'),
('PAX008', 'William', 'Chang', 'w.chang@email.com', '+86-138-200008', 'SILVER', 52000, NULL),
('PAX009', 'Fatima', 'Hassan', 'f.hassan@email.com', '+20-100-200009', 'GOLD', 115000, 'Halal meals'),
('PAX010', 'Carlos', 'Silva', 'c.silva@email.com', '+55-11-200010', 'STANDARD', 8000, NULL);

-- Bookings
INSERT INTO bookings (booking_id, passenger_id, flight_id, seat_number, booking_class, status) VALUES
('BK001', 'PAX001', 'FL001', '1A', 'FIRST', 'CONFIRMED'),
('BK002', 'PAX002', 'FL001', '12C', 'BUSINESS', 'CONFIRMED'),
('BK003', 'PAX003', 'FL001', '25A', 'PREMIUM_ECONOMY', 'CONFIRMED'),
('BK004', 'PAX004', 'FL001', '38F', 'ECONOMY', 'CONFIRMED'),
('BK005', 'PAX005', 'FL002', '2A', 'BUSINESS', 'CONFIRMED'),
('BK006', 'PAX006', 'FL002', '14D', 'ECONOMY', 'CONFIRMED'),
('BK007', 'PAX007', 'FL004', '30B', 'ECONOMY', 'CONFIRMED'),
('BK008', 'PAX008', 'FL004', '18A', 'PREMIUM_ECONOMY', 'CONFIRMED'),
('BK009', 'PAX009', 'FL005', '8C', 'BUSINESS', 'CONFIRMED'),
('BK010', 'PAX010', 'FL006', '42E', 'ECONOMY', 'CONFIRMED');

-- Seat Inventory (real-time tracking — booked_seats should match booking counts)
INSERT INTO seat_inventory (flight_id, seat_class, total_seats, booked_seats) VALUES
-- FL001: Boeing 777-300ER (LHR→JFK) — 4 bookings
('FL001', 'FIRST', 14, 1),
('FL001', 'BUSINESS', 48, 1),
('FL001', 'PREMIUM_ECONOMY', 40, 1),
('FL001', 'ECONOMY', 235, 1),
-- FL002: Airbus A320 (LHR→CDG) — 2 bookings
('FL002', 'BUSINESS', 12, 1),
('FL002', 'PREMIUM_ECONOMY', 18, 0),
('FL002', 'ECONOMY', 150, 1),
-- FL003: Airbus A320 (LHR→CDG) — AVAILABLE, no bookings
('FL003', 'BUSINESS', 12, 0),
('FL003', 'PREMIUM_ECONOMY', 18, 0),
('FL003', 'ECONOMY', 150, 0),
-- FL004: Airbus A321 (LHR→FRA) — 2 bookings
('FL004', 'BUSINESS', 20, 0),
('FL004', 'PREMIUM_ECONOMY', 24, 1),
('FL004', 'ECONOMY', 175, 1),
-- FL005: Boeing 737-800 (LHR→MAD) — 1 booking
('FL005', 'BUSINESS', 16, 1),
('FL005', 'ECONOMY', 162, 0),
-- FL006: Boeing 777-300ER (LHR→JFK) — 1 booking
('FL006', 'FIRST', 14, 0),
('FL006', 'BUSINESS', 48, 0),
('FL006', 'PREMIUM_ECONOMY', 40, 0),
('FL006', 'ECONOMY', 235, 1),
-- FL007: Boeing 787-9 (LHR→DXB) — no bookings
('FL007', 'FIRST', 8, 0),
('FL007', 'BUSINESS', 42, 0),
('FL007', 'PREMIUM_ECONOMY', 21, 0),
('FL007', 'ECONOMY', 216, 0),
-- FL008: UNSCHEDULED Boeing 777-300ER
('FL008', 'FIRST', 14, 0),
('FL008', 'BUSINESS', 48, 0),
('FL008', 'PREMIUM_ECONOMY', 40, 0),
('FL008', 'ECONOMY', 235, 0),
-- FL009: UNSCHEDULED Airbus A320
('FL009', 'BUSINESS', 12, 0),
('FL009', 'PREMIUM_ECONOMY', 18, 0),
('FL009', 'ECONOMY', 150, 0),
-- FL010: AVAILABLE Airbus A321
('FL010', 'BUSINESS', 20, 0),
('FL010', 'PREMIUM_ECONOMY', 24, 0),
('FL010', 'ECONOMY', 175, 0);

-- Flight Crew Requirements (tracks required vs assigned crew per flight)
INSERT INTO flight_crew_requirements (flight_id, role, required_count, assigned_count) VALUES
-- FL001: Boeing 777 long-haul — 3 assigned (CRW001, CRW002, CRW003)
('FL001', 'CAPTAIN', 1, 1),
('FL001', 'FIRST_OFFICER', 1, 1),
('FL001', 'CABIN_CREW_LEAD', 2, 1),
('FL001', 'CABIN_CREW', 10, 0),
-- FL002: Airbus A320 short-haul — 2 assigned (CRW006, CRW007)
('FL002', 'CAPTAIN', 1, 1),
('FL002', 'FIRST_OFFICER', 1, 1),
('FL002', 'CABIN_CREW_LEAD', 1, 0),
('FL002', 'CABIN_CREW', 3, 0),
-- FL003: AVAILABLE, no crew yet
('FL003', 'CAPTAIN', 1, 0),
('FL003', 'FIRST_OFFICER', 1, 0),
('FL003', 'CABIN_CREW_LEAD', 1, 0),
('FL003', 'CABIN_CREW', 3, 0),
-- FL004: Airbus A321 medium-haul
('FL004', 'CAPTAIN', 1, 0),
('FL004', 'FIRST_OFFICER', 1, 0),
('FL004', 'CABIN_CREW_LEAD', 1, 0),
('FL004', 'CABIN_CREW', 4, 0),
-- FL005: Boeing 737-800
('FL005', 'CAPTAIN', 1, 0),
('FL005', 'FIRST_OFFICER', 1, 0),
('FL005', 'CABIN_CREW_LEAD', 1, 0),
('FL005', 'CABIN_CREW', 3, 0),
-- FL006: Boeing 777 long-haul
('FL006', 'CAPTAIN', 1, 0),
('FL006', 'FIRST_OFFICER', 1, 0),
('FL006', 'CABIN_CREW_LEAD', 2, 0),
('FL006', 'CABIN_CREW', 10, 0),
-- FL007: Boeing 787-9
('FL007', 'CAPTAIN', 1, 0),
('FL007', 'FIRST_OFFICER', 1, 0),
('FL007', 'CABIN_CREW_LEAD', 2, 0),
('FL007', 'CABIN_CREW', 8, 0);

-- Passenger Flight History (initial bookings)
INSERT INTO passenger_flight_history (passenger_id, flight_id, booking_id, action, seat_class, seat_number, notes) VALUES
('PAX001', 'FL001', 'BK001', 'BOOKED', 'FIRST', '1A', 'Initial booking'),
('PAX002', 'FL001', 'BK002', 'BOOKED', 'BUSINESS', '12C', 'Initial booking'),
('PAX003', 'FL001', 'BK003', 'BOOKED', 'PREMIUM_ECONOMY', '25A', 'Initial booking'),
('PAX004', 'FL001', 'BK004', 'BOOKED', 'ECONOMY', '38F', 'Initial booking'),
('PAX005', 'FL002', 'BK005', 'BOOKED', 'BUSINESS', '2A', 'Initial booking'),
('PAX006', 'FL002', 'BK006', 'BOOKED', 'ECONOMY', '14D', 'Initial booking'),
('PAX007', 'FL004', 'BK007', 'BOOKED', 'ECONOMY', '30B', 'Initial booking'),
('PAX008', 'FL004', 'BK008', 'BOOKED', 'PREMIUM_ECONOMY', '18A', 'Initial booking'),
('PAX009', 'FL005', 'BK009', 'BOOKED', 'BUSINESS', '8C', 'Initial booking'),
('PAX010', 'FL006', 'BK010', 'BOOKED', 'ECONOMY', '42E', 'Initial booking');

-- Gates at LHR
INSERT INTO gates (gate_id, airport, terminal, gate_type, status, assigned_flight_id) VALUES
('A14', 'LHR', 'T5', 'WIDE_BODY', 'OCCUPIED', 'FL001'),
('B07', 'LHR', 'T5', 'NARROW_BODY', 'OCCUPIED', 'FL002'),
('B12', 'LHR', 'T5', 'NARROW_BODY', 'OCCUPIED', 'FL003'),
('C03', 'LHR', 'T5', 'NARROW_BODY', 'OCCUPIED', 'FL004'),
('A09', 'LHR', 'T5', 'WIDE_BODY', 'OCCUPIED', 'FL005'),
('A22', 'LHR', 'T5', 'WIDE_BODY', 'OCCUPIED', 'FL006'),
('A18', 'LHR', 'T5', 'WIDE_BODY', 'OCCUPIED', 'FL007'),
('D01', 'LHR', 'T5', 'NARROW_BODY', 'AVAILABLE', NULL),
('D05', 'LHR', 'T5', 'WIDE_BODY', 'AVAILABLE', NULL),
('E02', 'LHR', 'T5', 'NARROW_BODY', 'AVAILABLE', NULL),
('E08', 'LHR', 'T3', 'WIDE_BODY', 'AVAILABLE', NULL),
('F03', 'LHR', 'T3', 'NARROW_BODY', 'MAINTENANCE', NULL);

-- Catering Orders
INSERT INTO catering_orders (order_id, flight_id, meal_count, special_meals, status, delivery_gate, notes) VALUES
('CAT001', 'FL001', 312, 28, 'PREPARING', 'A14', 'Includes 8 kosher, 12 halal, 8 vegetarian'),
('CAT002', 'FL002', 156, 12, 'PREPARING', 'B07', 'Includes 5 halal, 7 vegetarian'),
('CAT003', 'FL004', 198, 15, 'READY', 'C03', 'Standard mix'),
('CAT004', 'FL005', 145, 10, 'PREPARING', 'A09', 'Includes 6 halal, 4 gluten-free'),
('CAT005', 'FL006', 205, 18, 'PREPARING', 'A22', 'Includes 10 kosher, 8 vegetarian');

-- Ground Handling Tasks
INSERT INTO ground_handling_tasks (task_id, flight_id, task_type, assigned_team, status, gate, notes) VALUES
('GH001', 'FL001', 'FUELING', 'Team Alpha', 'IN_PROGRESS', 'A14', 'Boeing 777 — full fuel load'),
('GH002', 'FL001', 'BAGGAGE_TRANSFER', 'Team Beta', 'PENDING', 'A14', '312 passengers, 28 connections'),
('GH003', 'FL002', 'CLEANING', 'Team Gamma', 'IN_PROGRESS', 'B07', 'Quick turnaround'),
('GH004', 'FL004', 'FUELING', 'Team Delta', 'COMPLETED', 'C03', NULL),
('GH005', 'FL001', 'PUSHBACK', 'Team Alpha', 'PENDING', 'A14', 'Scheduled 07:45');

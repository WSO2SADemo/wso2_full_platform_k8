// Autonomous Disruption Recovery — Passenger Service
// Handles intelligent passenger rebooking, VIP-aware compensation, and proactive notifications.
// Separated into: Data APIs | Reasoning APIs | Action APIs (for future AI/MCP integration)

import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerina/uuid;
import ballerina/time;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

// Database configuration
configurable string username = ?;
configurable string password = ?;
configurable string host = ?;
configurable int port = ?;
configurable string database = ?;

mysql:Options mysqlOptions = {
    ssl: {
        mode: mysql:SSL_DISABLED,
        allowPublicKeyRetrieval: true
    }
};

final mysql:Client dbClient = check new (host, username, password, database, port, options = mysqlOptions);

// Helper: record current timestamp
function getCurrentTimestamp() returns string {
    time:Utc now = time:utcNow();
    time:Civil civil = time:utcToCivil(now);
    return string `${civil.year}-${civil.month < 10 ? "0" : ""}${civil.month}-${civil.day < 10 ? "0" : ""}${civil.day} ${civil.hour < 10 ? "0" : ""}${civil.hour}:${civil.minute < 10 ? "0" : ""}${civil.minute}:${<int>civil.second < 10 ? "0" : ""}${<int>civil.second}`;
}

service /passenger on new http:Listener(9092) {

    // =====================================================================
    // DATA APIs — Pure read operations (future: MCP tools for LLM context)
    // =====================================================================

    // GET /passenger/bookings/{flightId} — Get all passengers on a flight
    resource function get bookings/[string flightId]() returns BookingWithPassenger[]|error {
        log:printInfo("Fetching passengers for flight: " + flightId);
        sql:ParameterizedQuery query = `SELECT b.booking_id, b.passenger_id, b.flight_id, b.seat_number,
            b.booking_class, b.status, p.first_name, p.last_name, p.loyalty_tier, p.loyalty_points, p.special_needs
            FROM bookings b JOIN passengers p ON b.passenger_id = p.passenger_id
            WHERE b.flight_id = ${flightId} AND b.status IN ('CONFIRMED', 'CHECKED_IN')
            ORDER BY FIELD(p.loyalty_tier, 'PLATINUM', 'GOLD', 'SILVER', 'STANDARD'), 
                     FIELD(b.booking_class, 'FIRST', 'BUSINESS', 'PREMIUM_ECONOMY', 'ECONOMY')`;
        stream<BookingWithPassenger, sql:Error?> resultStream = dbClient->query(query);
        BookingWithPassenger[] bookings = [];
        check from BookingWithPassenger booking in resultStream
            do {
                bookings.push(booking);
            };
        return bookings;
    }

    // GET /passenger/all-bookings — Get all bookings across all flights
    resource function get all\-bookings() returns BookingWithPassenger[]|error {
        log:printInfo("Fetching all bookings");
        sql:ParameterizedQuery query = `SELECT b.booking_id, b.passenger_id, b.flight_id, b.seat_number,
            b.booking_class, b.status, p.first_name, p.last_name, p.loyalty_tier, p.loyalty_points, p.special_needs
            FROM bookings b JOIN passengers p ON b.passenger_id = p.passenger_id
            ORDER BY b.flight_id, FIELD(p.loyalty_tier, 'PLATINUM', 'GOLD', 'SILVER', 'STANDARD')`;
        stream<BookingWithPassenger, sql:Error?> resultStream = dbClient->query(query);
        BookingWithPassenger[] bookings = [];
        check from BookingWithPassenger booking in resultStream
            do {
                bookings.push(booking);
            };
        return bookings;
    }

    // GET /passenger/{id} — Get passenger details
    resource function get [string id]() returns Passenger|http:Response|error {
        log:printInfo("Fetching passenger: " + id);
        sql:ParameterizedQuery query = `SELECT passenger_id, first_name, last_name, email, phone,
            loyalty_tier, loyalty_points, special_needs FROM passengers WHERE passenger_id = ${id}`;
        Passenger|sql:Error result = dbClient->queryRow(query);
        if result is sql:NoRowsError {
            http:Response notFound = new;
            notFound.statusCode = 404;
            notFound.setJsonPayload({message: string `Passenger '${id}' not found. Passenger IDs use the format PAX001, PAX002, etc.`});
            return notFound;
        }
        return result;
    }

    // GET /passenger/history/{passengerId} — Get passenger flight history
    resource function get history/[string passengerId]() returns PassengerFlightHistory[]|error {
        log:printInfo("Fetching flight history for passenger: " + passengerId);
        sql:ParameterizedQuery query = `SELECT id, passenger_id, flight_id, booking_id, action, 
            seat_class, seat_number, notes, created_at
            FROM passenger_flight_history WHERE passenger_id = ${passengerId} ORDER BY created_at DESC`;
        stream<PassengerFlightHistory, sql:Error?> resultStream = dbClient->query(query);
        PassengerFlightHistory[] history = [];
        check from PassengerFlightHistory h in resultStream
            do {
                history.push(h);
            };
        return history;
    }

    // GET /passenger/alternatives/{flightId} — Find alternative flights with REAL seat availability
    resource function get alternatives/[string flightId]() returns AlternativeFlight[]|error {
        log:printInfo("Finding alternative flights for: " + flightId);

        // Get the disrupted flight's route
        sql:ParameterizedQuery flightQuery = `SELECT origin, destination FROM flights WHERE flight_id = ${flightId}`;
        record {|string origin; string destination;|} route = check dbClient->queryRow(flightQuery);

        // Find alternative flights using seat_inventory for accurate availability
        sql:ParameterizedQuery query = `SELECT f.flight_id, f.airline, f.flight_number, f.origin, f.destination,
            f.scheduled_departure, f.scheduled_arrival, f.passenger_count,
            CAST(COALESCE(SUM(si.total_seats - si.booked_seats), 0) AS SIGNED) as available_seats,
            f.status
            FROM flights f 
            LEFT JOIN seat_inventory si ON f.flight_id = si.flight_id
            WHERE f.origin = ${route.origin} AND f.destination = ${route.destination} 
            AND f.flight_id != ${flightId}
            AND f.status IN ('SCHEDULED', 'AVAILABLE', 'BOARDING')
            GROUP BY f.flight_id, f.airline, f.flight_number, f.origin, f.destination,
                     f.scheduled_departure, f.scheduled_arrival, f.passenger_count, f.status
            HAVING available_seats > 0
            ORDER BY f.scheduled_departure`;

        stream<AlternativeFlight, sql:Error?> resultStream = dbClient->query(query);
        AlternativeFlight[] alternatives = [];
        check from AlternativeFlight alt in resultStream
            do {
                alternatives.push(alt);
            };
        return alternatives;
    }

    // GET /passenger/alternatives-detailed/{flightId} — Find alternatives with per-class seat breakdown
    resource function get alternatives\-detailed/[string flightId]() returns json|error {
        log:printInfo("Finding detailed alternatives for: " + flightId);

        sql:ParameterizedQuery flightQuery = `SELECT origin, destination FROM flights WHERE flight_id = ${flightId}`;
        record {|string origin; string destination;|} route = check dbClient->queryRow(flightQuery);

        // Get alternative flights
        sql:ParameterizedQuery altQuery = `SELECT f.flight_id, f.airline, f.flight_number, f.origin, f.destination,
            f.scheduled_departure, f.scheduled_arrival, f.status
            FROM flights f 
            WHERE f.origin = ${route.origin} AND f.destination = ${route.destination} 
            AND f.flight_id != ${flightId}
            AND f.status IN ('SCHEDULED', 'AVAILABLE', 'BOARDING')
            ORDER BY f.scheduled_departure`;

        stream<record {|string flight_id; string airline; string flight_number; string origin; string destination; string scheduled_departure; string scheduled_arrival; string status;|}, sql:Error?> altStream = dbClient->query(altQuery);

        json[] alternatives = [];
        check from var alt in altStream
            do {
                // Get seat inventory for this flight
                sql:ParameterizedQuery seatQuery = `SELECT seat_class, total_seats, booked_seats, 
                    (total_seats - booked_seats) as available_seats 
                    FROM seat_inventory WHERE flight_id = ${alt.flight_id}`;
                stream<record {|string seat_class; int total_seats; int booked_seats; int available_seats;|}, sql:Error?> seatStream = dbClient->query(seatQuery);
                json[] seatClasses = [];
                int totalAvail = 0;
                check from var s in seatStream
                    do {
                        seatClasses.push({
                            "seat_class": s.seat_class,
                            "total_seats": s.total_seats,
                            "booked_seats": s.booked_seats,
                            "available_seats": s.available_seats
                        });
                        totalAvail += s.available_seats;
                    };
                if totalAvail > 0 {
                    alternatives.push({
                        "flight_id": alt.flight_id,
                        "airline": alt.airline,
                        "flight_number": alt.flight_number,
                        "origin": alt.origin,
                        "destination": alt.destination,
                        "scheduled_departure": alt.scheduled_departure,
                        "scheduled_arrival": alt.scheduled_arrival,
                        "status": alt.status,
                        "seat_classes": seatClasses,
                        "total_available_seats": totalAvail
                    });
                }
            };
        return alternatives;
    }

    // =====================================================================
    // REASONING APIs — Decision/evaluation logic (future: replaceable by LLM)
    // =====================================================================

    // GET /passenger/evaluate-rebook/{passengerId}/{flightId} — Evaluate rebooking options
    resource function get evaluate\-rebook/[string passengerId]/[string flightId]() returns RebookingEvaluation|error {
        log:printInfo(string `Evaluating rebooking for passenger ${passengerId} on flight ${flightId}`);

        // Get passenger
        sql:ParameterizedQuery passengerQuery = `SELECT passenger_id, first_name, last_name, email, phone,
            loyalty_tier, loyalty_points, special_needs FROM passengers WHERE passenger_id = ${passengerId}`;
        Passenger passenger = check dbClient->queryRow(passengerQuery);

        // Get their current booking class
        sql:ParameterizedQuery bookingQuery = `SELECT booking_class FROM bookings 
            WHERE passenger_id = ${passengerId} AND flight_id = ${flightId} AND status IN ('CONFIRMED', 'CHECKED_IN') LIMIT 1`;
        record {|string booking_class;|}|sql:Error bookingResult = dbClient->queryRow(bookingQuery);
        string currentClass = "ECONOMY";
        if bookingResult is record {|string booking_class;|} {
            currentClass = bookingResult.booking_class;
        }

        // Get disrupted flight route
        sql:ParameterizedQuery flightQuery = `SELECT origin, destination FROM flights WHERE flight_id = ${flightId}`;
        record {|string origin; string destination;|} route = check dbClient->queryRow(flightQuery);

        // Find alternatives with seat availability
        sql:ParameterizedQuery altQuery = `SELECT f.flight_id, f.flight_number, f.scheduled_departure
            FROM flights f 
            WHERE f.origin = ${route.origin} AND f.destination = ${route.destination} 
            AND f.flight_id != ${flightId}
            AND f.status IN ('SCHEDULED', 'AVAILABLE', 'BOARDING')
            ORDER BY f.scheduled_departure`;

        stream<record {|string flight_id; string flight_number; string scheduled_departure;|}, sql:Error?> altStream = dbClient->query(altQuery);

        RebookOption[] options = [];
        boolean anyAvailable = false;

        check from var alt in altStream
            do {
                // Determine recommended class based on loyalty tier
                string recClass = currentClass;
                if passenger.loyalty_tier == "PLATINUM" && (currentClass == "ECONOMY" || currentClass == "PREMIUM_ECONOMY") {
                    recClass = "BUSINESS";
                } else if passenger.loyalty_tier == "GOLD" && currentClass == "ECONOMY" {
                    recClass = "PREMIUM_ECONOMY";
                }

                // Check seat availability in recommended class
                sql:ParameterizedQuery seatQuery = `SELECT (total_seats - booked_seats) as available 
                    FROM seat_inventory WHERE flight_id = ${alt.flight_id} AND seat_class = ${recClass}`;
                record {|int available;|}|sql:Error seatResult = dbClient->queryRow(seatQuery);
                int availInClass = 0;
                if seatResult is record {|int available;|} {
                    availInClass = seatResult.available;
                }

                if availInClass > 0 {
                    anyAvailable = true;
                }

                string priority = "LOW";
                if availInClass > 10 {
                    priority = "HIGH";
                } else if availInClass > 0 {
                    priority = "MEDIUM";
                }

                options.push({
                    flight_id: alt.flight_id,
                    flight_number: alt.flight_number,
                    scheduled_departure: alt.scheduled_departure,
                    recommended_class: recClass,
                    available_in_class: availInClass,
                    priority_score: priority
                });
            };

        string recommendation;
        boolean compensationNeeded = false;
        string compensationReason = "";

        if options.length() == 0 {
            recommendation = "No alternative flights available on this route. Full compensation recommended.";
            compensationNeeded = true;
            compensationReason = "No alternative flights exist for this route.";
        } else if !anyAvailable {
            recommendation = "Alternative flights exist but all seats are fully booked. Full compensation recommended.";
            compensationNeeded = true;
            compensationReason = "All alternative flights are fully booked.";
        } else {
            recommendation = string `${options.length()} alternative(s) found. Rebook to earliest available flight.`;
        }

        string passengerName = passenger.first_name + " " + passenger.last_name;
        return {
            passenger_id: passengerId,
            passenger_name: passengerName,
            loyalty_tier: passenger.loyalty_tier,
            original_flight_id: flightId,
            options: options,
            recommendation: recommendation,
            compensation_needed: compensationNeeded,
            compensation_reason: compensationReason
        };
    }

    // =====================================================================
    // ACTION APIs — State-changing operations (future: MCP tools for LLM)
    // =====================================================================

    // POST /passenger/rebook — Rebook a passenger with seat inventory tracking
    resource function post rebook(@http:Payload RebookRequest request) returns RebookResult|error {
        log:printInfo(string `Rebooking passenger ${request.passenger_id} from ${request.original_flight_id} to ${request.new_flight_id}`);

        // Get passenger info
        sql:ParameterizedQuery passengerQuery = `SELECT passenger_id, first_name, last_name, email, phone,
            loyalty_tier, loyalty_points, special_needs FROM passengers WHERE passenger_id = ${request.passenger_id}`;
        Passenger passenger = check dbClient->queryRow(passengerQuery);

        // Determine booking class — VIPs get upgrade consideration
        string bookingClass = request.preferred_class ?: "ECONOMY";
        if request.preferred_class is () {
            if passenger.loyalty_tier == "PLATINUM" {
                bookingClass = "BUSINESS";
            } else if passenger.loyalty_tier == "GOLD" {
                bookingClass = "PREMIUM_ECONOMY";
            }
        }

        // CHECK SEAT AVAILABILITY before rebooking
        sql:ParameterizedQuery seatCheckQuery = `SELECT (total_seats - booked_seats) as available 
            FROM seat_inventory WHERE flight_id = ${request.new_flight_id} AND seat_class = ${bookingClass}`;
        record {|int available;|}|sql:Error seatResult = dbClient->queryRow(seatCheckQuery);
        
        boolean seatConfirmed = false;
        if seatResult is record {|int available;|} && seatResult.available > 0 {
            seatConfirmed = true;
            // Decrement available seats
            _ = check dbClient->execute(`UPDATE seat_inventory SET booked_seats = booked_seats + 1 
                WHERE flight_id = ${request.new_flight_id} AND seat_class = ${bookingClass}`);
        } else {
            // Try to find ANY available class on this flight
            sql:ParameterizedQuery anyClassQuery = `SELECT seat_class, (total_seats - booked_seats) as available 
                FROM seat_inventory WHERE flight_id = ${request.new_flight_id} AND (total_seats - booked_seats) > 0 
                ORDER BY FIELD(seat_class, 'FIRST', 'BUSINESS', 'PREMIUM_ECONOMY', 'ECONOMY') LIMIT 1`;
            record {|string seat_class; int available;|}|sql:Error anyResult = dbClient->queryRow(anyClassQuery);
            if anyResult is record {|string seat_class; int available;|} {
                bookingClass = anyResult.seat_class;
                seatConfirmed = true;
                _ = check dbClient->execute(`UPDATE seat_inventory SET booked_seats = booked_seats + 1 
                    WHERE flight_id = ${request.new_flight_id} AND seat_class = ${bookingClass}`);
            }
        }

        // Release seat on original flight
        sql:ParameterizedQuery origBookingQuery = `SELECT booking_class FROM bookings 
            WHERE passenger_id = ${request.passenger_id} AND flight_id = ${request.original_flight_id} 
            AND status IN ('CONFIRMED', 'CHECKED_IN') LIMIT 1`;
        record {|string booking_class;|}|sql:Error origResult = dbClient->queryRow(origBookingQuery);
        if origResult is record {|string booking_class;|} {
            _ = check dbClient->execute(`UPDATE seat_inventory SET booked_seats = GREATEST(booked_seats - 1, 0) 
                WHERE flight_id = ${request.original_flight_id} AND seat_class = ${origResult.booking_class}`);
        }

        // Update old booking status
        string rebookedAt = getCurrentTimestamp();
        sql:ParameterizedQuery updateQuery = `UPDATE bookings SET status = 'REBOOKED', rebooked_at = ${rebookedAt}
            WHERE passenger_id = ${request.passenger_id} AND flight_id = ${request.original_flight_id} 
            AND status IN ('CONFIRMED', 'CHECKED_IN')`;
        _ = check dbClient->execute(updateQuery);

        // Create new booking
        string newBookingId = uuid:createType1AsString();
        sql:ParameterizedQuery insertQuery = `INSERT INTO bookings 
            (booking_id, passenger_id, flight_id, booking_class, status, original_flight_id, rebooked_at)
            VALUES (${newBookingId}, ${request.passenger_id}, ${request.new_flight_id}, 
                    ${bookingClass}, 'CONFIRMED', ${request.original_flight_id}, ${rebookedAt})`;
        _ = check dbClient->execute(insertQuery);

        // Update passenger count on new flight
        _ = check dbClient->execute(`UPDATE flights SET passenger_count = passenger_count + 1 
            WHERE flight_id = ${request.new_flight_id}`);

        // Record in flight history
        _ = check dbClient->execute(`INSERT INTO passenger_flight_history 
            (passenger_id, flight_id, booking_id, action, seat_class, notes)
            VALUES (${request.passenger_id}, ${request.new_flight_id}, ${newBookingId}, 'REBOOKED', 
                    ${bookingClass}, ${string `Rebooked from ${request.original_flight_id}`})`);

        string passengerName = passenger.first_name + " " + passenger.last_name;
        string seatMsg = seatConfirmed ? "Seat confirmed" : "No seat confirmed — standby";
        string message = string `${passengerName} (${passenger.loyalty_tier}) rebooked from ${request.original_flight_id} ` +
            string `to ${request.new_flight_id} in ${bookingClass}. ${seatMsg}`;
        log:printInfo(message);

        return {
            passenger_id: passenger.passenger_id,
            passenger_name: passengerName,
            original_flight_id: request.original_flight_id,
            new_flight_id: request.new_flight_id,
            new_booking_id: newBookingId,
            booking_class: bookingClass,
            loyalty_tier: passenger.loyalty_tier,
            status: "REBOOKED",
            message: message,
            seat_confirmed: seatConfirmed
        };
    }

    // POST /passenger/notify — Send notification to a passenger
    resource function post notify(@http:Payload NotifyRequest request) returns NotifyResult|error {
        log:printInfo(string `Sending ${request.notification_type} notification to passenger ${request.passenger_id}`);

        // Get passenger info
        sql:ParameterizedQuery passengerQuery = `SELECT passenger_id, first_name, last_name, email, phone,
            loyalty_tier, loyalty_points, special_needs FROM passengers WHERE passenger_id = ${request.passenger_id}`;
        Passenger passenger = check dbClient->queryRow(passengerQuery);

        // Create notification record
        string notificationId = uuid:createType1AsString();
        sql:ParameterizedQuery insertQuery = `INSERT INTO notifications 
            (notification_id, passenger_id, notification_type, message, status)
            VALUES (${notificationId}, ${request.passenger_id}, ${request.notification_type}, 
                    ${request.message}, 'SENT')`;
        _ = check dbClient->execute(insertQuery);

        string passengerName = passenger.first_name + " " + passenger.last_name;
        log:printInfo(string `Notification sent to ${passengerName} via ${request.notification_type}`);

        return {
            notification_id: notificationId,
            passenger_id: passenger.passenger_id,
            passenger_name: passengerName,
            notification_type: request.notification_type,
            status: "SENT",
            message: request.message
        };
    }

    // POST /passenger/compensation — Smart VIP-aware compensation
    // Only issues FULL compensation when no flights/seats available.
    // Otherwise provides standard delay amenities.
    resource function post compensation(@http:Payload CompensationRequest request) returns CompensationResult|error {
        log:printInfo(string `Determining compensation for passenger ${request.passenger_id} on flight ${request.flight_id}`);

        // Get passenger info
        sql:ParameterizedQuery passengerQuery = `SELECT passenger_id, first_name, last_name, email, phone,
            loyalty_tier, loyalty_points, special_needs FROM passengers WHERE passenger_id = ${request.passenger_id}`;
        Passenger passenger = check dbClient->queryRow(passengerQuery);

        CompensationItem[] compensations = [];
        string reasoning = "";
        decimal totalValue = 0.0;

        string passengerName = passenger.first_name + " " + passenger.last_name;
        boolean isLateNight = request.current_hour >= 22 || request.current_hour <= 5;
        boolean isLongDelay = request.delay_minutes >= 120;
        boolean isVeryLongDelay = request.delay_minutes >= 240;
        boolean noAlternatives = request.no_alternatives_available ?: false;

        // If no alternatives available — trigger FULL compensation
        if noAlternatives {
            reasoning += "NO ALTERNATIVE FLIGHTS/SEATS AVAILABLE — full compensation triggered. ";

            // Full refund
            decimal refundAmount = 600.0;
            compensations.push({
                compensation_type: "REFUND",
                amount: refundAmount,
                currency: "EUR",
                description: "EU261/2004 mandatory compensation — no alternative available"
            });
            totalValue += refundAmount;

            // Hotel for everyone when there's no alternative
            decimal hotelAmount = passenger.loyalty_tier == "PLATINUM" ? 350.0 : 
                                  passenger.loyalty_tier == "GOLD" ? 250.0 : 
                                  passenger.loyalty_tier == "SILVER" ? 200.0 : 150.0;
            compensations.push({
                compensation_type: "HOTEL",
                amount: hotelAmount,
                currency: "USD",
                description: string `Hotel accommodation — no alternative flights available`
            });
            totalValue += hotelAmount;

            // Taxi
            compensations.push({
                compensation_type: "TAXI",
                amount: 75.0,
                currency: "USD",
                description: "Taxi to hotel"
            });
            totalValue += 75.0d;

            // Meal
            decimal mealAmount = passenger.loyalty_tier == "PLATINUM" ? 50.0d : 
                                 passenger.loyalty_tier == "GOLD" ? 35.0d : 25.0d;
            compensations.push({
                compensation_type: "MEAL",
                amount: mealAmount,
                currency: "USD",
                description: "Meal voucher"
            });
            totalValue += mealAmount;

            // Bonus miles
            int bonusMiles = passenger.loyalty_tier == "PLATINUM" ? 15000 : 
                             passenger.loyalty_tier == "GOLD" ? 10000 : 
                             passenger.loyalty_tier == "SILVER" ? 5000 : 2000;
            compensations.push({
                compensation_type: "MILES",
                amount: <decimal>bonusMiles,
                currency: "USD",
                description: string `${bonusMiles} bonus miles — no alternative available`
            });
            reasoning += string `Full compensation package issued for ${passenger.loyalty_tier} member. `;

        } else {
            // Standard delay amenities (passenger IS being rebooked)
            reasoning += "Passenger is being rebooked — standard delay amenities only. ";

            // 1. Meal for delays > 60min
            if request.delay_minutes >= 60 && !isLateNight {
                decimal mealAmount = passenger.loyalty_tier == "PLATINUM" ? 50.0 : 
                                     passenger.loyalty_tier == "GOLD" ? 35.0 : 
                                     passenger.loyalty_tier == "SILVER" ? 25.0 : 15.0;
                compensations.push({
                    compensation_type: "MEAL",
                    amount: mealAmount,
                    currency: "USD",
                    description: string `Meal voucher for ${passenger.loyalty_tier} member during wait`
                });
                totalValue += mealAmount;
                reasoning += string `Meal voucher issued for ${request.delay_minutes}min delay. `;
            }

            // 2. Late-night: hotel + taxi for long delays
            if isLateNight && isLongDelay {
                if passenger.loyalty_tier == "PLATINUM" || passenger.loyalty_tier == "GOLD" || isVeryLongDelay {
                    decimal hotelAmount = passenger.loyalty_tier == "PLATINUM" ? 350.0 : 
                                          passenger.loyalty_tier == "GOLD" ? 250.0 : 150.0;
                    compensations.push({
                        compensation_type: "HOTEL",
                        amount: hotelAmount,
                        currency: "USD",
                        description: "Hotel accommodation — next flight not until morning"
                    });
                    totalValue += hotelAmount;
                    reasoning += "Late night, next flight delayed — hotel arranged. ";
                }
                compensations.push({
                    compensation_type: "TAXI",
                    amount: 75.0,
                    currency: "USD",
                    description: "Taxi — public transport unavailable"
                });
                totalValue += 75.0d;
            } else if isLateNight {
                if passenger.loyalty_tier == "PLATINUM" || passenger.loyalty_tier == "GOLD" {
                    compensations.push({
                        compensation_type: "LOUNGE_ACCESS",
                        amount: 0.0,
                        currency: "USD",
                        description: "Complimentary lounge access during wait"
                    });
                    reasoning += "Lounge access during late-night wait. ";
                }
            }

            // 3. Bonus miles for long delays
            if isLongDelay {
                int bonusMiles = passenger.loyalty_tier == "PLATINUM" ? 5000 : 
                                 passenger.loyalty_tier == "GOLD" ? 3000 : 
                                 passenger.loyalty_tier == "SILVER" ? 1500 : 500;
                compensations.push({
                    compensation_type: "MILES",
                    amount: <decimal>bonusMiles,
                    currency: "USD",
                    description: string `${bonusMiles} bonus miles for inconvenience`
                });
                reasoning += string `${bonusMiles} bonus miles as goodwill. `;
            }

            // 4. EU261 only for very long delays even when rebooked
            if isVeryLongDelay {
                compensations.push({
                    compensation_type: "REFUND",
                    amount: 300.0d,
                    currency: "EUR",
                    description: "EU261/2004 partial compensation for delay > 4 hours (rebooked)"
                });
                totalValue += 300.0d;
                reasoning += "EU261 partial compensation (rebooked). ";
            }
        }

        // Special needs note
        if passenger.special_needs is string && passenger.special_needs != "" {
            reasoning += string `Special needs noted (${passenger.special_needs ?: ""}): additional care arranged. `;
        }

        // Store compensations in DB
        foreach CompensationItem comp in compensations {
            string compId = uuid:createType1AsString();
            _ = check dbClient->execute(`INSERT INTO compensations 
                (compensation_id, passenger_id, flight_id, compensation_type, amount, currency, description, status)
                VALUES (${compId}, ${request.passenger_id}, ${request.flight_id}, ${comp.compensation_type}, 
                        ${comp.amount}, ${comp.currency}, ${comp.description}, 'APPROVED')`);
        }

        // Record compensation in flight history
        _ = check dbClient->execute(`INSERT INTO passenger_flight_history 
            (passenger_id, flight_id, action, notes)
            VALUES (${request.passenger_id}, ${request.flight_id}, 'COMPENSATED', 
                    ${string `Compensation: ${reasoning}`})`);

        log:printInfo(string `Compensation for ${passengerName}: ${reasoning}`);

        return {
            passenger_id: passenger.passenger_id,
            passenger_name: passengerName,
            loyalty_tier: passenger.loyalty_tier,
            flight_id: request.flight_id,
            compensations: compensations,
            reasoning: reasoning,
            total_value: totalValue,
            triggered_by_no_availability: noAlternatives
        };
    }
}

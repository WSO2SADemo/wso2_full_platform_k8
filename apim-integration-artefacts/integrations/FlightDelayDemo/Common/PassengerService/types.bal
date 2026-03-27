// Types for the Passenger Service

public type Passenger record {|
    string passenger_id;
    string first_name;
    string last_name;
    string? email;
    string? phone;
    string loyalty_tier;
    int loyalty_points;
    string? special_needs;
|};

public type Booking record {|
    string booking_id;
    string passenger_id;
    string flight_id;
    string? seat_number;
    string booking_class;
    string status;
    string? original_flight_id;
    string? rebooked_at;
|};

public type BookingWithPassenger record {|
    string booking_id;
    string passenger_id;
    string flight_id;
    string? seat_number;
    string booking_class;
    string status;
    string first_name;
    string last_name;
    string loyalty_tier;
    int loyalty_points;
    string? special_needs;
|};

public type RebookRequest record {|
    string passenger_id;
    string original_flight_id;
    string new_flight_id;
    string? preferred_class;
|};

public type RebookResult record {|
    string passenger_id;
    string passenger_name;
    string original_flight_id;
    string new_flight_id;
    string new_booking_id;
    string booking_class;
    string loyalty_tier;
    string status;
    string message;
    boolean seat_confirmed;
|};

public type NotifyRequest record {|
    string passenger_id;
    string notification_type;
    string message;
|};

public type NotifyResult record {|
    string notification_id;
    string passenger_id;
    string passenger_name;
    string notification_type;
    string status;
    string message;
|};

public type CompensationRequest record {|
    string passenger_id;
    string flight_id;
    int delay_minutes;
    int current_hour;
    boolean? no_alternatives_available;
|};

public type CompensationResult record {|
    string passenger_id;
    string passenger_name;
    string loyalty_tier;
    string flight_id;
    CompensationItem[] compensations;
    string reasoning;
    decimal total_value;
    boolean triggered_by_no_availability;
|};

public type CompensationItem record {|
    string compensation_type;
    decimal amount;
    string currency;
    string description;
|};

public type AlternativeFlight record {|
    string flight_id;
    string airline;
    string flight_number;
    string origin;
    string destination;
    string scheduled_departure;
    string scheduled_arrival;
    int passenger_count;
    int available_seats;
    string status;
|};

// --- Seat-Aware Alternative (from seat_inventory) ---

public type SeatAvailableAlternative record {|
    string flight_id;
    string airline;
    string flight_number;
    string origin;
    string destination;
    string scheduled_departure;
    string scheduled_arrival;
    string status;
    SeatClassAvailability[] seat_classes;
    int total_available_seats;
|};

public type SeatClassAvailability record {|
    string seat_class;
    int total_seats;
    int booked_seats;
    int available_seats;
|};

// --- Passenger Flight History ---

public type PassengerFlightHistory record {|
    int id;
    string passenger_id;
    string flight_id;
    string? booking_id;
    string action;
    string? seat_class;
    string? seat_number;
    string? notes;
    string created_at;
|};

// --- Rebooking Evaluation (Reasoning) ---

public type RebookingEvaluation record {|
    string passenger_id;
    string passenger_name;
    string loyalty_tier;
    string original_flight_id;
    RebookOption[] options;
    string recommendation;
    boolean compensation_needed;
    string compensation_reason;
|};

public type RebookOption record {|
    string flight_id;
    string flight_number;
    string scheduled_departure;
    string recommended_class;
    int available_in_class;
    string priority_score;
|};

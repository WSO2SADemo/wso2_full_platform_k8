// Types for the Disruption Detection Service

public type Flight record {|
    string flight_id;
    string airline;
    string flight_number;
    string origin;
    string destination;
    string scheduled_departure;
    string scheduled_arrival;
    string? actual_departure;
    string? actual_arrival;
    string? aircraft_type;
    string? gate;
    string status;
    int passenger_count;
    int seats_first;
    int seats_business;
    int seats_premium_economy;
    int seats_economy;
    int required_captains;
    int required_first_officers;
    int required_cabin_crew_leads;
    int required_cabin_crew;
|};

public type FlightInput record {|
    string? flight_id;
    string airline;
    string flight_number;
    string origin;
    string destination;
    string scheduled_departure;
    string scheduled_arrival;
    string? aircraft_type;
    string? gate;
    string? status;
    int? passenger_count;
    int? seats_first;
    int? seats_business;
    int? seats_premium_economy;
    int? seats_economy;
    int? required_captains;
    int? required_first_officers;
    int? required_cabin_crew_leads;
    int? required_cabin_crew;
|};

public type DelayReport record {|
    int delayMinutes;
    string reason;
|};

public type Disruption record {|
    string disruption_id;
    string flight_id;
    string disruption_type;
    int delay_minutes;
    string? reason;
    string severity;
    string status;
    string detected_at;
    string? resolved_at;
|};

// --- Seat Inventory ---

public type SeatInventory record {|
    int id;
    string flight_id;
    string seat_class;
    int total_seats;
    int booked_seats;
|};

public type SeatAvailability record {|
    string flight_id;
    SeatClassInfo[] classes;
    int total_capacity;
    int total_booked;
    int total_available;
|};

public type SeatClassInfo record {|
    string seat_class;
    int total_seats;
    int booked_seats;
    int available_seats;
|};

// --- Flight Crew Requirements ---

public type FlightCrewRequirement record {|
    int id;
    string flight_id;
    string role;
    int required_count;
    int assigned_count;
|};

public type CrewRequirementSummary record {|
    string flight_id;
    FlightCrewRequirement[] requirements;
    boolean fully_staffed;
    int total_required;
    int total_assigned;
|};

// --- Status Change ---

public type StatusChangeRequest record {|
    string new_status;
    string? gate = ();
|};

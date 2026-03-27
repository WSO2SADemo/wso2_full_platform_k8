// Types for the ADR Orchestrator Service

public type RecoveryRequest record {|
    string flightId;
    string disruptionType;
|};

public type RecoveryPlan record {|
    string plan_id;
    string disruption_id;
    string flight_id;
    string status;
    int total_passengers_affected;
    int passengers_rebooked;
    int crew_reassignments;
    int gate_changes;
    decimal estimated_cost;
    decimal total_compensations;
    json? negotiation_log;
|};

public type NegotiationStep record {|
    string agent;
    string action;
    string result;
    string timestamp;
|};

public type RecoverySummary record {|
    string plan_id;
    string flight_id;
    string disruption_id;
    string status;
    DisruptionSummary disruption;
    CrewSummary crew;
    PassengerSummary passengers;
    LogisticsSummary logistics;
    NegotiationStep[] negotiation_log;
    decimal estimated_cost;
    string message;
|};

public type DisruptionSummary record {|
    string flight_id;
    string flight_number;
    int delay_minutes;
    string severity;
    string reason;
|};

public type CrewSummary record {|
    int compliance_checks;
    int non_compliant_crew;
    int reassignments;
    string[] details;
|};

public type PassengerSummary record {|
    int total_affected;
    int rebooked;
    int compensated_no_alternatives;
    int notified;
    int compensations_issued;
    decimal total_compensation_value;
    string[] details;
|};

public type LogisticsSummary record {|
    int gate_changes;
    int catering_redirections;
    int ground_tasks_created;
    string[] details;
|};

// Types for upstream service responses

public type FlightInfo record {
    string flight_id;
    string airline;
    string flight_number;
    string origin;
    string destination;
    string status;
    int passenger_count;
    string? gate;
    int seats_first;
    int seats_business;
    int seats_premium_economy;
    int seats_economy;
};

public type DisruptionInfo record {
    string disruption_id;
    string flight_id;
    string disruption_type;
    int delay_minutes;
    string? reason;
    string severity;
    string status;
};

public type CrewAssignmentInfo record {
    string assignment_id;
    string crew_id;
    string flight_id;
    string role;
    string status;
};

public type ComplianceResult record {
    string crew_id;
    string crew_name;
    string flight_id;
    boolean compliant;
    decimal current_duty_hours;
    decimal max_duty_hours;
    string message;
};

public type AvailableCrewInfo record {
    string crew_id;
    string first_name;
    string last_name;
    string role;
    decimal duty_hours_today;
    decimal max_duty_hours;
    string status;
};

public type BookingInfo record {
    string booking_id;
    string passenger_id;
    string flight_id;
    string booking_class;
    string status;
    string first_name;
    string last_name;
    string loyalty_tier;
    int loyalty_points;
    string? special_needs;
};

public type AlternativeFlightInfo record {
    string flight_id;
    string airline;
    string flight_number;
    int available_seats;
    string status;
};

public type RebookResultInfo record {
    string passenger_id;
    string passenger_name;
    string new_flight_id;
    string booking_class;
    string status;
    boolean seat_confirmed;
};

public type CompensationResultInfo record {
    string passenger_id;
    string passenger_name;
    string reasoning;
    decimal total_value;
    boolean triggered_by_no_availability;
};

public type GateInfo record {
    string gate_id;
    string terminal;
    string gate_type;
    string status;
};

public type GateAssignResultInfo record {
    string gate_id;
    string flight_id;
    string message;
};

public type CateringRedirectResultInfo record {
    string flight_id;
    int orders_redirected;
    string message;
};

public type GroundHandlingResultInfo record {
    string task_id;
    string flight_id;
    string task_type;
    string message;
};

// Seat availability from disruption service
public type SeatAvailabilityInfo record {
    string flight_id;
    int total_capacity;
    int total_booked;
    int total_available;
};

// Crew requirement summary from crew service
public type CrewRequirementInfo record {
    string flight_id;
    boolean fully_staffed;
    int total_required;
    int total_assigned;
    int gaps;
};

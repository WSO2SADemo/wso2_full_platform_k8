// Types for the Crew Service

public type CrewMember record {|
    string crew_id;
    string first_name;
    string last_name;
    string role;
    string base_airport;
    decimal duty_hours_today;
    decimal max_duty_hours;
    string status;
    string? phone;
    string? email;
    string? certification;
|};

public type CrewMemberInput record {|
    string? crew_id;
    string first_name;
    string last_name;
    string role;
    string base_airport;
    decimal? duty_hours_today;
    decimal? max_duty_hours;
    string? status;
    string? phone;
    string? email;
    string? certification;
|};

public type CrewAssignment record {|
    string assignment_id;
    string crew_id;
    string flight_id;
    string role;
    string? duty_start;
    string? duty_end;
    string status;
|};

public type ComplianceCheckRequest record {|
    string crew_id;
    string flight_id;
    decimal additional_hours;
|};

public type ComplianceCheckResult record {|
    string crew_id;
    string crew_name;
    string flight_id;
    boolean compliant;
    decimal current_duty_hours;
    decimal max_duty_hours;
    decimal requested_additional_hours;
    decimal projected_total;
    string message;
|};

public type ReassignRequest record {|
    string crew_id;
    string from_flight_id;
    string to_flight_id;
    string role;
|};

public type ReassignResult record {|
    string crew_id;
    string crew_name;
    string from_flight_id;
    string to_flight_id;
    string new_assignment_id;
    string status;
    string message;
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
    int gaps;
|};

// --- Assign Crew Request ---

public type AssignCrewRequest record {|
    string crew_id;
    string flight_id;
    string role;
    string? duty_start;
    string? duty_end;
|};

public type AssignCrewResult record {|
    string assignment_id;
    string crew_id;
    string crew_name;
    string flight_id;
    string role;
    string status;
    string message;
|};

// --- Crew Fitness Evaluation (Reasoning) ---

public type CrewFitnessEvaluation record {|
    string flight_id;
    CrewCandidate[] candidates;
    string[] gaps;
    string recommendation;
|};

public type CrewCandidate record {|
    string crew_id;
    string name;
    string role;
    decimal duty_hours_remaining;
    boolean compliant;
    string fitness_score;
|};

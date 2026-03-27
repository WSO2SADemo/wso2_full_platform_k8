// Types for the Logistics Service

public type Gate record {|
    string gate_id;
    string airport;
    string terminal;
    string gate_type;
    string status;
    string? assigned_flight_id;
|};

public type GateAssignRequest record {|
    string flight_id;
    string gate_id;
|};

public type GateAssignResult record {|
    string gate_id;
    string flight_id;
    string terminal;
    string gate_type;
    string status;
    string message;
|};

public type CateringOrder record {|
    string order_id;
    string flight_id;
    int meal_count;
    int special_meals;
    string status;
    string? delivery_gate;
    string? notes;
|};

public type CateringRedirectRequest record {|
    string flight_id;
    string new_gate;
    string? notes;
|};

public type CateringRedirectResult record {|
    string flight_id;
    string new_gate;
    int orders_redirected;
    string status;
    string message;
|};

public type GroundHandlingTask record {|
    string task_id;
    string flight_id;
    string task_type;
    string? assigned_team;
    string status;
    string? gate;
    string? notes;
|};

public type GroundHandlingNotifyRequest record {|
    string flight_id;
    string task_type;
    string? gate;
    string? assigned_team;
    string? notes;
|};

public type GroundHandlingNotifyResult record {|
    string task_id;
    string flight_id;
    string task_type;
    string? assigned_team;
    string status;
    string message;
|};

public type AirportResources record {|
    string airport;
    int total_gates;
    int available_gates;
    int occupied_gates;
    int maintenance_gates;
    int active_catering_orders;
    int pending_ground_tasks;
|};

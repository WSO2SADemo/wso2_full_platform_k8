// ─── Patient Registry Types ────────────────────────────────────────────────────

public type Patient record {|
    string patientId;
    string firstName;
    string lastName;
    string dateOfBirth;
    string gender;
    string bloodType;
    string[] allergies;
    string[] chronicConditions;
    string primaryDoctorId;
    string registeredSince;
|};

// ─── Appointment Types ─────────────────────────────────────────────────────────

public type Appointment record {|
    string appointmentId;
    string patientId;
    string doctorId;
    string doctorName;
    string specialty;
    string dateTime;
    string status;   // SCHEDULED | COMPLETED | CANCELLED
    string location;
    string notes;
|};

public type AppointmentRequest record {|
    string patientId;
    string doctorId;
    string preferredDateTime;
    string reason;
|};

// ─── Prescription Types ────────────────────────────────────────────────────────

public type Prescription record {|
    string prescriptionId;
    string patientId;
    string doctorId;
    string doctorName;
    string issuedDate;
    string expiryDate;
    string status;   // ACTIVE | EXPIRED | DISPENSED
    PrescriptionItem[] items;
|};

public type PrescriptionItem record {|
    string medicationName;
    string dosage;
    string frequency;
    int durationDays;
    string instructions;
|};

// ─── Lab Results Types ─────────────────────────────────────────────────────────

public type LabResult record {|
    string resultId;
    string patientId;
    string orderedBy;
    string testName;
    string category;     // BLOOD | URINE | IMAGING | PATHOLOGY
    string orderedDate;
    string resultDate;
    string status;       // PENDING | COMPLETED | REVIEWED
    LabTestItem[] results;
|};

public type LabTestItem record {|
    string parameterName;
    string value;
    string unit;
    string referenceRange;
    string flag;         // NORMAL | HIGH | LOW | CRITICAL
|};

// ─── Pharmacy Types ────────────────────────────────────────────────────────────

public type Medication record {|
    string medicationId;
    string name;
    string genericName;
    string category;
    string form;         // TABLET | CAPSULE | LIQUID | INJECTION
    string strength;
    boolean requiresPrescription;
    int stockQuantity;
    string manufacturer;
|};

public type DispenseRequest record {|
    string prescriptionId;
    string patientId;
    string pharmacyId;
|};

public type DispenseResponse record {|
    boolean success;
    string dispenseId;
    string prescriptionId;
    string dispensedAt;
    string message;
|};

// ─── Doctor / Hospital Types ───────────────────────────────────────────────────

public type Doctor record {|
    string doctorId;
    string firstName;
    string lastName;
    string specialty;
    string[] qualifications;
    string hospitalId;
    string hospitalName;
    boolean acceptingPatients;
    string[] availableDays;
|};

public type Hospital record {|
    string hospitalId;
    string name;
    string address;
    string city;
    string phone;
    string[] specialties;
    int bedCapacity;
    boolean hasEmergency;
|};

// ─── Medical Insurance Types ───────────────────────────────────────────────────

public type InsuranceCoverage record {|
    string coverageId;
    string patientId;
    string insurerId;
    string insurerName;
    string planName;
    string validFrom;
    string validTo;
    string status;           // ACTIVE | EXPIRED | SUSPENDED
    float coveragePercent;
    float annualDeductible;
    float deductibleMet;
    string[] coveredServices;
|};

// ─── Common ────────────────────────────────────────────────────────────────────

public type ErrorResponse record {|
    string code;
    string message;
|};

public type DeleteResponse record {|
    boolean success;
    string message;
|};

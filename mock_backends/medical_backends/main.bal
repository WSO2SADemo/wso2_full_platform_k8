// ─── Shared in-memory data stores and counters ─────────────────────────────────
// Port 9201 → patient_services.bal  (Patient Registry, Appointments, Prescriptions, Lab Results)
// Port 9205 → provider_services.bal (Pharmacy, Doctors & Hospitals, Medical Insurance)

map<Patient> patientDb = {
    "P001": {patientId: "P001", firstName: "Erik", lastName: "Svensson", dateOfBirth: "1985-04-12", gender: "MALE", bloodType: "A+", allergies: ["Penicillin"], chronicConditions: ["Hypertension"], primaryDoctorId: "D001", registeredSince: "2018-01-10"},
    "P002": {patientId: "P002", firstName: "Anna", lastName: "Lindqvist", dateOfBirth: "1992-07-23", gender: "FEMALE", bloodType: "O-", allergies: [], chronicConditions: [], primaryDoctorId: "D002", registeredSince: "2020-05-14"},
    "P003": {patientId: "P003", firstName: "Lars", lastName: "Johansson", dateOfBirth: "1968-11-05", gender: "MALE", bloodType: "B+", allergies: ["Sulfa", "Aspirin"], chronicConditions: ["Type 2 Diabetes", "High Cholesterol"], primaryDoctorId: "D001", registeredSince: "2015-03-22"},
    "P004": {patientId: "P004", firstName: "Maria", lastName: "Nilsson", dateOfBirth: "2001-02-18", gender: "FEMALE", bloodType: "AB+", allergies: ["Latex"], chronicConditions: ["Asthma"], primaryDoctorId: "D003", registeredSince: "2021-09-01"}
};

map<Appointment> appointmentDb = {
    "APT001": {appointmentId: "APT001", patientId: "P001", doctorId: "D001", doctorName: "Dr. Karl Berg", specialty: "General Practice", dateTime: "2026-04-05T09:30:00", status: "SCHEDULED", location: "Room 101, Stockholm Medical Center", notes: "Annual checkup"},
    "APT002": {appointmentId: "APT002", patientId: "P001", doctorId: "D004", doctorName: "Dr. Sofia Holm", specialty: "Cardiology", dateTime: "2026-03-15T14:00:00", status: "COMPLETED", location: "Cardiology Wing, Floor 3", notes: "Follow-up on blood pressure"},
    "APT003": {appointmentId: "APT003", patientId: "P002", doctorId: "D002", doctorName: "Dr. Ingrid Strand", specialty: "Dermatology", dateTime: "2026-04-10T11:00:00", status: "SCHEDULED", location: "Dermatology Clinic", notes: "Skin rash evaluation"},
    "APT004": {appointmentId: "APT004", patientId: "P003", doctorId: "D001", doctorName: "Dr. Karl Berg", specialty: "General Practice", dateTime: "2026-04-02T08:00:00", status: "SCHEDULED", location: "Room 101, Stockholm Medical Center", notes: "Diabetes management review"},
    "APT005": {appointmentId: "APT005", patientId: "P003", doctorId: "D005", doctorName: "Dr. Mikael Ek", specialty: "Endocrinology", dateTime: "2026-03-20T10:30:00", status: "COMPLETED", location: "Endocrinology Dept", notes: "HbA1c results review"},
    "APT006": {appointmentId: "APT006", patientId: "P004", doctorId: "D003", doctorName: "Dr. Lena Frost", specialty: "Pulmonology", dateTime: "2026-04-08T15:30:00", status: "SCHEDULED", location: "Pulmonology Clinic, Room 5", notes: "Asthma management"}
};

map<Prescription> prescriptionDb = {
    "RX001": {prescriptionId: "RX001", patientId: "P001", doctorId: "D001", doctorName: "Dr. Karl Berg", issuedDate: "2026-03-01", expiryDate: "2026-09-01", status: "ACTIVE", items: [{medicationName: "Amlodipine", dosage: "5mg", frequency: "Once daily", durationDays: 90, instructions: "Take in the morning with water"}]},
    "RX002": {prescriptionId: "RX002", patientId: "P001", doctorId: "D004", doctorName: "Dr. Sofia Holm", issuedDate: "2026-03-15", expiryDate: "2026-06-15", status: "ACTIVE", items: [{medicationName: "Atorvastatin", dosage: "20mg", frequency: "Once daily at night", durationDays: 90, instructions: "Take at bedtime"}]},
    "RX003": {prescriptionId: "RX003", patientId: "P003", doctorId: "D001", doctorName: "Dr. Karl Berg", issuedDate: "2026-02-15", expiryDate: "2026-08-15", status: "ACTIVE", items: [{medicationName: "Metformin", dosage: "500mg", frequency: "Twice daily", durationDays: 180, instructions: "Take with meals"}, {medicationName: "Rosuvastatin", dosage: "10mg", frequency: "Once daily", durationDays: 180, instructions: "Take at night"}]},
    "RX004": {prescriptionId: "RX004", patientId: "P003", doctorId: "D001", doctorName: "Dr. Karl Berg", issuedDate: "2025-12-01", expiryDate: "2026-03-01", status: "EXPIRED", items: [{medicationName: "Lisinopril", dosage: "10mg", frequency: "Once daily", durationDays: 90, instructions: "Monitor blood pressure"}]},
    "RX005": {prescriptionId: "RX005", patientId: "P004", doctorId: "D003", doctorName: "Dr. Lena Frost", issuedDate: "2026-03-10", expiryDate: "2026-09-10", status: "ACTIVE", items: [{medicationName: "Salbutamol Inhaler", dosage: "100mcg", frequency: "As needed", durationDays: 180, instructions: "2 puffs when needed, max 8 puffs/day"}, {medicationName: "Fluticasone Inhaler", dosage: "250mcg", frequency: "Twice daily", durationDays: 180, instructions: "Rinse mouth after use"}]}
};

map<LabResult> labDb = {
    "LB001": {resultId: "LB001", patientId: "P001", orderedBy: "Dr. Karl Berg", testName: "Complete Blood Count", category: "BLOOD", orderedDate: "2026-03-01", resultDate: "2026-03-02", status: "REVIEWED", results: [{parameterName: "Hemoglobin", value: "14.5", unit: "g/dL", referenceRange: "13.5-17.5", flag: "NORMAL"}, {parameterName: "WBC", value: "7.2", unit: "10^9/L", referenceRange: "4.5-11.0", flag: "NORMAL"}, {parameterName: "Platelets", value: "220", unit: "10^9/L", referenceRange: "150-400", flag: "NORMAL"}]},
    "LB002": {resultId: "LB002", patientId: "P001", orderedBy: "Dr. Sofia Holm", testName: "Lipid Panel", category: "BLOOD", orderedDate: "2026-03-15", resultDate: "2026-03-16", status: "REVIEWED", results: [{parameterName: "Total Cholesterol", value: "210", unit: "mg/dL", referenceRange: "<200", flag: "HIGH"}, {parameterName: "LDL", value: "135", unit: "mg/dL", referenceRange: "<130", flag: "HIGH"}, {parameterName: "HDL", value: "52", unit: "mg/dL", referenceRange: ">40", flag: "NORMAL"}]},
    "LB003": {resultId: "LB003", patientId: "P003", orderedBy: "Dr. Mikael Ek", testName: "HbA1c", category: "BLOOD", orderedDate: "2026-03-18", resultDate: "2026-03-19", status: "REVIEWED", results: [{parameterName: "HbA1c", value: "7.8", unit: "%", referenceRange: "<7.0", flag: "HIGH"}, {parameterName: "Fasting Glucose", value: "142", unit: "mg/dL", referenceRange: "70-100", flag: "HIGH"}]},
    "LB004": {resultId: "LB004", patientId: "P003", orderedBy: "Dr. Karl Berg", testName: "Kidney Function", category: "BLOOD", orderedDate: "2026-03-01", resultDate: "2026-03-02", status: "COMPLETED", results: [{parameterName: "Creatinine", value: "0.95", unit: "mg/dL", referenceRange: "0.7-1.3", flag: "NORMAL"}, {parameterName: "eGFR", value: "78", unit: "mL/min/1.73m2", referenceRange: ">60", flag: "NORMAL"}]},
    "LB005": {resultId: "LB005", patientId: "P004", orderedBy: "Dr. Lena Frost", testName: "Spirometry", category: "IMAGING", orderedDate: "2026-03-10", resultDate: "2026-03-10", status: "REVIEWED", results: [{parameterName: "FEV1", value: "72", unit: "%predicted", referenceRange: ">80", flag: "LOW"}, {parameterName: "FVC", value: "85", unit: "%predicted", referenceRange: ">80", flag: "NORMAL"}, {parameterName: "FEV1/FVC", value: "68", unit: "%", referenceRange: ">70", flag: "LOW"}]}
};

map<Medication> medicationDb = {
    "MED001": {medicationId: "MED001", name: "Amlodipine 5mg", genericName: "Amlodipine", category: "Antihypertensive", form: "TABLET", strength: "5mg", requiresPrescription: true, stockQuantity: 250, manufacturer: "AstraZeneca"},
    "MED002": {medicationId: "MED002", name: "Atorvastatin 20mg", genericName: "Atorvastatin", category: "Statin", form: "TABLET", strength: "20mg", requiresPrescription: true, stockQuantity: 180, manufacturer: "Pfizer"},
    "MED003": {medicationId: "MED003", name: "Metformin 500mg", genericName: "Metformin HCl", category: "Antidiabetic", form: "TABLET", strength: "500mg", requiresPrescription: true, stockQuantity: 400, manufacturer: "Teva"},
    "MED004": {medicationId: "MED004", name: "Salbutamol Inhaler 100mcg", genericName: "Salbutamol", category: "Bronchodilator", form: "INJECTION", strength: "100mcg/dose", requiresPrescription: true, stockQuantity: 60, manufacturer: "GSK"},
    "MED005": {medicationId: "MED005", name: "Paracetamol 500mg", genericName: "Paracetamol", category: "Analgesic", form: "TABLET", strength: "500mg", requiresPrescription: false, stockQuantity: 1000, manufacturer: "Apoteket"},
    "MED006": {medicationId: "MED006", name: "Ibuprofen 400mg", genericName: "Ibuprofen", category: "NSAID", form: "TABLET", strength: "400mg", requiresPrescription: false, stockQuantity: 800, manufacturer: "Apoteket"}
};

map<Doctor> doctorDb = {
    "D001": {doctorId: "D001", firstName: "Karl", lastName: "Berg", specialty: "General Practice", qualifications: ["MD", "MSc Internal Medicine"], hospitalId: "H001", hospitalName: "Stockholm Medical Center", acceptingPatients: true, availableDays: ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]},
    "D002": {doctorId: "D002", firstName: "Ingrid", lastName: "Strand", specialty: "Dermatology", qualifications: ["MD", "PhD Dermatology"], hospitalId: "H001", hospitalName: "Stockholm Medical Center", acceptingPatients: true, availableDays: ["MONDAY", "WEDNESDAY", "FRIDAY"]},
    "D003": {doctorId: "D003", firstName: "Lena", lastName: "Frost", specialty: "Pulmonology", qualifications: ["MD", "Specialist Pulmonology"], hospitalId: "H002", hospitalName: "Karolinska University Hospital", acceptingPatients: true, availableDays: ["TUESDAY", "THURSDAY"]},
    "D004": {doctorId: "D004", firstName: "Sofia", lastName: "Holm", specialty: "Cardiology", qualifications: ["MD", "MSc Cardiology", "FESC"], hospitalId: "H002", hospitalName: "Karolinska University Hospital", acceptingPatients: false, availableDays: ["MONDAY", "TUESDAY", "THURSDAY"]},
    "D005": {doctorId: "D005", firstName: "Mikael", lastName: "Ek", specialty: "Endocrinology", qualifications: ["MD", "PhD Endocrinology"], hospitalId: "H003", hospitalName: "Gothenburg General Hospital", acceptingPatients: true, availableDays: ["WEDNESDAY", "FRIDAY"]}
};

map<Hospital> hospitalDb = {
    "H001": {hospitalId: "H001", name: "Stockholm Medical Center", address: "Solnavägen 1", city: "Stockholm", phone: "+46-8-517-700-00", specialties: ["General Practice", "Dermatology", "Orthopaedics", "Oncology"], bedCapacity: 450, hasEmergency: true},
    "H002": {hospitalId: "H002", name: "Karolinska University Hospital", address: "Anna Steckséns gata 53", city: "Stockholm", phone: "+46-8-517-700-01", specialties: ["Cardiology", "Pulmonology", "Neurology", "Transplant"], bedCapacity: 1500, hasEmergency: true},
    "H003": {hospitalId: "H003", name: "Gothenburg General Hospital", address: "Blå stråket 5", city: "Gothenburg", phone: "+46-31-342-10-00", specialties: ["Endocrinology", "Nephrology", "Rheumatology"], bedCapacity: 650, hasEmergency: true}
};

map<InsuranceCoverage> insuranceDb = {
    "P001": {coverageId: "COV001", patientId: "P001", insurerId: "INS001", insurerName: "Folksam Health", planName: "Premium Plus", validFrom: "2026-01-01", validTo: "2026-12-31", status: "ACTIVE", coveragePercent: 80.0, annualDeductible: 5000.0, deductibleMet: 1200.0, coveredServices: ["GP Visits", "Specialist Visits", "Lab Tests", "Imaging", "Prescriptions", "Hospital Stays"]},
    "P002": {coverageId: "COV002", patientId: "P002", insurerId: "INS002", insurerName: "If Health Insurance", planName: "Standard", validFrom: "2026-01-01", validTo: "2026-12-31", status: "ACTIVE", coveragePercent: 60.0, annualDeductible: 3000.0, deductibleMet: 0.0, coveredServices: ["GP Visits", "Lab Tests", "Prescriptions"]},
    "P003": {coverageId: "COV003", patientId: "P003", insurerId: "INS001", insurerName: "Folksam Health", planName: "Chronic Care", validFrom: "2025-06-01", validTo: "2026-05-31", status: "ACTIVE", coveragePercent: 90.0, annualDeductible: 2000.0, deductibleMet: 1800.0, coveredServices: ["GP Visits", "Specialist Visits", "Lab Tests", "Imaging", "Prescriptions", "Hospital Stays", "Diabetes Management", "Physiotherapy"]},
    "P004": {coverageId: "COV004", patientId: "P004", insurerId: "INS003", insurerName: "Trygg-Hansa Health", planName: "Young & Healthy", validFrom: "2026-01-01", validTo: "2026-12-31", status: "ACTIVE", coveragePercent: 70.0, annualDeductible: 1500.0, deductibleMet: 500.0, coveredServices: ["GP Visits", "Specialist Visits", "Prescriptions", "Preventive Care"]}
};

// ─── ID counters ───────────────────────────────────────────────────────────────

int patientCounter      = 5;
int appointmentCounter  = 7;
int prescriptionCounter = 6;
int labCounter          = 6;
int medicationCounter   = 7;
int doctorCounter       = 6;
int hospitalCounter     = 4;
int coverageCounter     = 5;

import ballerina/http;
import ballerina/log;
import ballerina/lang.runtime;

// ─── Port 9201: Patient-related services ───────────────────────────────────────
// Hosts: /patients, /appointments, /prescriptions, /labs

listener http:Listener patientSvcListener = check new http:Listener(9201);

// ─── Patient Registry ──────────────────────────────────────────────────────────

service /patients on patientSvcListener {
    function init() {
        log:printInfo("Patient Registry service started on port 9201");
    }

    resource function get health() returns string {
        return "Patient services are running on port 9201";
    }

    resource function get .() returns Patient[] {
        return patientDb.toArray();
    }

    resource function get [string patientId]() returns Patient|http:NotFound {
        Patient? p = patientDb[patientId];
        if p is Patient {
            return p;
        }
        return <http:NotFound>{body: <ErrorResponse>{code: "PATIENT_NOT_FOUND", message: string `Patient ${patientId} not found`}};
    }

    resource function post .(@http:Payload Patient patient) returns Patient|http:Conflict {
        if patientDb.hasKey(patient.patientId) {
            return <http:Conflict>{body: <ErrorResponse>{code: "PATIENT_EXISTS", message: string `Patient ${patient.patientId} already exists`}};
        }
        string newId = string `P${patientCounter}`;
        patientCounter += 1;
        Patient newPatient = {patientId: newId, firstName: patient.firstName, lastName: patient.lastName, dateOfBirth: patient.dateOfBirth, gender: patient.gender, bloodType: patient.bloodType, allergies: patient.allergies, chronicConditions: patient.chronicConditions, primaryDoctorId: patient.primaryDoctorId, registeredSince: patient.registeredSince};
        patientDb[newId] = newPatient;
        log:printInfo(string `Created patient ${newId}`);
        return newPatient;
    }

    resource function put [string patientId](@http:Payload Patient patient) returns Patient|http:NotFound {
        if !patientDb.hasKey(patientId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "PATIENT_NOT_FOUND", message: string `Patient ${patientId} not found`}};
        }
        Patient updated = {patientId: patientId, firstName: patient.firstName, lastName: patient.lastName, dateOfBirth: patient.dateOfBirth, gender: patient.gender, bloodType: patient.bloodType, allergies: patient.allergies, chronicConditions: patient.chronicConditions, primaryDoctorId: patient.primaryDoctorId, registeredSince: patient.registeredSince};
        patientDb[patientId] = updated;
        log:printInfo(string `Updated patient ${patientId}`);
        return updated;
    }

    resource function delete [string patientId]() returns DeleteResponse|http:NotFound {
        if !patientDb.hasKey(patientId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "PATIENT_NOT_FOUND", message: string `Patient ${patientId} not found`}};
        }
        _ = patientDb.remove(patientId);
        log:printInfo(string `Deleted patient ${patientId}`);
        return {success: true, message: string `Patient ${patientId} deleted`};
    }
}

// ─── Appointments ──────────────────────────────────────────────────────────────

service /appointments on patientSvcListener {
    function init() {
        log:printInfo("Appointments service started on port 9201");
    }

    resource function get .() returns Appointment[] {
        return appointmentDb.toArray();
    }

    resource function get patient/[string patientId]() returns Appointment[] {
        return appointmentDb.toArray().filter(a => a.patientId == patientId);
    }

    resource function get [string appointmentId]() returns Appointment|http:NotFound {
        Appointment? apt = appointmentDb[appointmentId];
        if apt is Appointment {
            return apt;
        }
        return <http:NotFound>{body: <ErrorResponse>{code: "APPOINTMENT_NOT_FOUND", message: string `Appointment ${appointmentId} not found`}};
    }

    resource function post .(@http:Payload AppointmentRequest req) returns Appointment|http:BadRequest {
        Doctor? doc = doctorDb[req.doctorId];
        if doc is () {
            return <http:BadRequest>{body: <ErrorResponse>{code: "DOCTOR_NOT_FOUND", message: string `Doctor ${req.doctorId} not found`}};
        }
        runtime:sleep(0.3d);
        string newId = string `APT${appointmentCounter}`;
        appointmentCounter += 1;
        Appointment newApt = {
            appointmentId: newId,
            patientId: req.patientId,
            doctorId: req.doctorId,
            doctorName: string `Dr. ${doc.firstName} ${doc.lastName}`,
            specialty: doc.specialty,
            dateTime: req.preferredDateTime,
            status: "SCHEDULED",
            location: doc.hospitalName,
            notes: req.reason
        };
        appointmentDb[newId] = newApt;
        log:printInfo(string `Created appointment ${newId}`);
        return newApt;
    }

    resource function put [string appointmentId](@http:Payload Appointment apt) returns Appointment|http:NotFound {
        if !appointmentDb.hasKey(appointmentId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "APPOINTMENT_NOT_FOUND", message: string `Appointment ${appointmentId} not found`}};
        }
        Appointment updated = {appointmentId: appointmentId, patientId: apt.patientId, doctorId: apt.doctorId, doctorName: apt.doctorName, specialty: apt.specialty, dateTime: apt.dateTime, status: apt.status, location: apt.location, notes: apt.notes};
        appointmentDb[appointmentId] = updated;
        log:printInfo(string `Updated appointment ${appointmentId}`);
        return updated;
    }

    resource function delete [string appointmentId]() returns DeleteResponse|http:NotFound {
        if !appointmentDb.hasKey(appointmentId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "APPOINTMENT_NOT_FOUND", message: string `Appointment ${appointmentId} not found`}};
        }
        _ = appointmentDb.remove(appointmentId);
        log:printInfo(string `Deleted appointment ${appointmentId}`);
        return {success: true, message: string `Appointment ${appointmentId} deleted`};
    }
}

// ─── Prescriptions ─────────────────────────────────────────────────────────────

service /prescriptions on patientSvcListener {
    function init() {
        log:printInfo("Prescriptions service started on port 9201");
    }

    resource function get .() returns Prescription[] {
        return prescriptionDb.toArray();
    }

    resource function get patient/[string patientId]() returns Prescription[] {
        return prescriptionDb.toArray().filter(rx => rx.patientId == patientId);
    }

    resource function get patient/[string patientId]/active() returns Prescription[] {
        return prescriptionDb.toArray().filter(rx => rx.patientId == patientId && rx.status == "ACTIVE");
    }

    resource function get [string prescriptionId]() returns Prescription|http:NotFound {
        Prescription? rx = prescriptionDb[prescriptionId];
        if rx is Prescription {
            return rx;
        }
        return <http:NotFound>{body: <ErrorResponse>{code: "PRESCRIPTION_NOT_FOUND", message: string `Prescription ${prescriptionId} not found`}};
    }

    resource function post .(@http:Payload Prescription rx) returns Prescription|http:Conflict {
        if prescriptionDb.hasKey(rx.prescriptionId) {
            return <http:Conflict>{body: <ErrorResponse>{code: "PRESCRIPTION_EXISTS", message: string `Prescription ${rx.prescriptionId} already exists`}};
        }
        string newId = string `RX${prescriptionCounter}`;
        prescriptionCounter += 1;
        Prescription newRx = {prescriptionId: newId, patientId: rx.patientId, doctorId: rx.doctorId, doctorName: rx.doctorName, issuedDate: rx.issuedDate, expiryDate: rx.expiryDate, status: rx.status, items: rx.items};
        prescriptionDb[newId] = newRx;
        log:printInfo(string `Created prescription ${newId}`);
        return newRx;
    }

    resource function put [string prescriptionId](@http:Payload Prescription rx) returns Prescription|http:NotFound {
        if !prescriptionDb.hasKey(prescriptionId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "PRESCRIPTION_NOT_FOUND", message: string `Prescription ${prescriptionId} not found`}};
        }
        Prescription updated = {prescriptionId: prescriptionId, patientId: rx.patientId, doctorId: rx.doctorId, doctorName: rx.doctorName, issuedDate: rx.issuedDate, expiryDate: rx.expiryDate, status: rx.status, items: rx.items};
        prescriptionDb[prescriptionId] = updated;
        log:printInfo(string `Updated prescription ${prescriptionId}`);
        return updated;
    }

    resource function delete [string prescriptionId]() returns DeleteResponse|http:NotFound {
        if !prescriptionDb.hasKey(prescriptionId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "PRESCRIPTION_NOT_FOUND", message: string `Prescription ${prescriptionId} not found`}};
        }
        _ = prescriptionDb.remove(prescriptionId);
        log:printInfo(string `Deleted prescription ${prescriptionId}`);
        return {success: true, message: string `Prescription ${prescriptionId} deleted`};
    }
}

// ─── Lab Results ───────────────────────────────────────────────────────────────

service /labs on patientSvcListener {
    function init() {
        log:printInfo("Lab Results service started on port 9201");
    }

    resource function get .() returns LabResult[] {
        return labDb.toArray();
    }

    resource function get patient/[string patientId]() returns LabResult[] {
        return labDb.toArray().filter(l => l.patientId == patientId);
    }

    resource function get patient/[string patientId]/abnormal() returns LabResult[] {
        return labDb.toArray().filter(l =>
            l.patientId == patientId &&
            l.results.some(item => item.flag == "HIGH" || item.flag == "LOW" || item.flag == "CRITICAL")
        );
    }

    resource function get [string resultId]() returns LabResult|http:NotFound {
        LabResult? lab = labDb[resultId];
        if lab is LabResult {
            return lab;
        }
        return <http:NotFound>{body: <ErrorResponse>{code: "LAB_RESULT_NOT_FOUND", message: string `Lab result ${resultId} not found`}};
    }

    resource function post .(@http:Payload LabResult lab) returns LabResult|http:Conflict {
        if labDb.hasKey(lab.resultId) {
            return <http:Conflict>{body: <ErrorResponse>{code: "LAB_RESULT_EXISTS", message: string `Lab result ${lab.resultId} already exists`}};
        }
        string newId = string `LB${labCounter}`;
        labCounter += 1;
        LabResult newLab = {resultId: newId, patientId: lab.patientId, orderedBy: lab.orderedBy, testName: lab.testName, category: lab.category, orderedDate: lab.orderedDate, resultDate: lab.resultDate, status: lab.status, results: lab.results};
        labDb[newId] = newLab;
        log:printInfo(string `Created lab result ${newId}`);
        return newLab;
    }

    resource function put [string resultId](@http:Payload LabResult lab) returns LabResult|http:NotFound {
        if !labDb.hasKey(resultId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "LAB_RESULT_NOT_FOUND", message: string `Lab result ${resultId} not found`}};
        }
        LabResult updated = {resultId: resultId, patientId: lab.patientId, orderedBy: lab.orderedBy, testName: lab.testName, category: lab.category, orderedDate: lab.orderedDate, resultDate: lab.resultDate, status: lab.status, results: lab.results};
        labDb[resultId] = updated;
        log:printInfo(string `Updated lab result ${resultId}`);
        return updated;
    }

    resource function delete [string resultId]() returns DeleteResponse|http:NotFound {
        if !labDb.hasKey(resultId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "LAB_RESULT_NOT_FOUND", message: string `Lab result ${resultId} not found`}};
        }
        _ = labDb.remove(resultId);
        log:printInfo(string `Deleted lab result ${resultId}`);
        return {success: true, message: string `Lab result ${resultId} deleted`};
    }
}

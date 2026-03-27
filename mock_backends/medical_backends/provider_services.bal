import ballerina/http;
import ballerina/log;
import ballerina/lang.runtime;

// ─── Port 9205: Provider-related services ──────────────────────────────────────
// Hosts: /pharmacy, /doctors (+ /hospitals), /insurance

listener http:Listener providerSvcListener = check new http:Listener(9205);

// ─── Pharmacy ──────────────────────────────────────────────────────────────────

service /pharmacy on providerSvcListener {
    function init() {
        log:printInfo("Pharmacy service started on port 9205");
    }

    resource function get health() returns string {
        return "Provider services are running on port 9205";
    }

    resource function get medications() returns Medication[] {
        return medicationDb.toArray();
    }

    resource function get medications/[string medicationId]() returns Medication|http:NotFound {
        Medication? med = medicationDb[medicationId];
        if med is Medication {
            return med;
        }
        return <http:NotFound>{body: <ErrorResponse>{code: "MEDICATION_NOT_FOUND", message: string `Medication ${medicationId} not found`}};
    }

    resource function post medications(@http:Payload Medication med) returns Medication|http:Conflict {
        if medicationDb.hasKey(med.medicationId) {
            return <http:Conflict>{body: <ErrorResponse>{code: "MEDICATION_EXISTS", message: string `Medication ${med.medicationId} already exists`}};
        }
        string newId = string `MED${medicationCounter}`;
        medicationCounter += 1;
        Medication newMed = {medicationId: newId, name: med.name, genericName: med.genericName, category: med.category, form: med.form, strength: med.strength, requiresPrescription: med.requiresPrescription, stockQuantity: med.stockQuantity, manufacturer: med.manufacturer};
        medicationDb[newId] = newMed;
        log:printInfo(string `Created medication ${newId}`);
        return newMed;
    }

    resource function put medications/[string medicationId](@http:Payload Medication med) returns Medication|http:NotFound {
        if !medicationDb.hasKey(medicationId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "MEDICATION_NOT_FOUND", message: string `Medication ${medicationId} not found`}};
        }
        Medication updated = {medicationId: medicationId, name: med.name, genericName: med.genericName, category: med.category, form: med.form, strength: med.strength, requiresPrescription: med.requiresPrescription, stockQuantity: med.stockQuantity, manufacturer: med.manufacturer};
        medicationDb[medicationId] = updated;
        log:printInfo(string `Updated medication ${medicationId}`);
        return updated;
    }

    resource function delete medications/[string medicationId]() returns DeleteResponse|http:NotFound {
        if !medicationDb.hasKey(medicationId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "MEDICATION_NOT_FOUND", message: string `Medication ${medicationId} not found`}};
        }
        _ = medicationDb.remove(medicationId);
        log:printInfo(string `Deleted medication ${medicationId}`);
        return {success: true, message: string `Medication ${medicationId} deleted`};
    }

    resource function post dispense(@http:Payload DispenseRequest req) returns DispenseResponse|http:BadRequest {
        if !prescriptionDb.hasKey(req.prescriptionId) {
            return <http:BadRequest>{body: <ErrorResponse>{code: "PRESCRIPTION_NOT_FOUND", message: string `Prescription ${req.prescriptionId} not found`}};
        }
        runtime:sleep(0.2d);
        Prescription rx = <Prescription>prescriptionDb[req.prescriptionId];
        prescriptionDb[req.prescriptionId] = {prescriptionId: rx.prescriptionId, patientId: rx.patientId, doctorId: rx.doctorId, doctorName: rx.doctorName, issuedDate: rx.issuedDate, expiryDate: rx.expiryDate, status: "DISPENSED", items: rx.items};
        return {
            success: true,
            dispenseId: string `DSP-${req.prescriptionId}-${req.pharmacyId}`,
            prescriptionId: req.prescriptionId,
            dispensedAt: "2026-03-21T10:00:00",
            message: "Prescription dispensed successfully"
        };
    }
}

// ─── Doctors & Hospitals ───────────────────────────────────────────────────────

service /doctors on providerSvcListener {
    function init() {
        log:printInfo("Doctors & Hospitals service started on port 9205");
    }

    resource function get .() returns Doctor[] {
        return doctorDb.toArray();
    }

    resource function get [string doctorId]() returns Doctor|http:NotFound {
        Doctor? doc = doctorDb[doctorId];
        if doc is Doctor {
            return doc;
        }
        return <http:NotFound>{body: <ErrorResponse>{code: "DOCTOR_NOT_FOUND", message: string `Doctor ${doctorId} not found`}};
    }

    resource function post .(@http:Payload Doctor doc) returns Doctor|http:Conflict {
        if doctorDb.hasKey(doc.doctorId) {
            return <http:Conflict>{body: <ErrorResponse>{code: "DOCTOR_EXISTS", message: string `Doctor ${doc.doctorId} already exists`}};
        }
        string newId = string `D${doctorCounter}`;
        doctorCounter += 1;
        Doctor newDoc = {doctorId: newId, firstName: doc.firstName, lastName: doc.lastName, specialty: doc.specialty, qualifications: doc.qualifications, hospitalId: doc.hospitalId, hospitalName: doc.hospitalName, acceptingPatients: doc.acceptingPatients, availableDays: doc.availableDays};
        doctorDb[newId] = newDoc;
        log:printInfo(string `Created doctor ${newId}`);
        return newDoc;
    }

    resource function put [string doctorId](@http:Payload Doctor doc) returns Doctor|http:NotFound {
        if !doctorDb.hasKey(doctorId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "DOCTOR_NOT_FOUND", message: string `Doctor ${doctorId} not found`}};
        }
        Doctor updated = {doctorId: doctorId, firstName: doc.firstName, lastName: doc.lastName, specialty: doc.specialty, qualifications: doc.qualifications, hospitalId: doc.hospitalId, hospitalName: doc.hospitalName, acceptingPatients: doc.acceptingPatients, availableDays: doc.availableDays};
        doctorDb[doctorId] = updated;
        log:printInfo(string `Updated doctor ${doctorId}`);
        return updated;
    }

    resource function delete [string doctorId]() returns DeleteResponse|http:NotFound {
        if !doctorDb.hasKey(doctorId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "DOCTOR_NOT_FOUND", message: string `Doctor ${doctorId} not found`}};
        }
        _ = doctorDb.remove(doctorId);
        log:printInfo(string `Deleted doctor ${doctorId}`);
        return {success: true, message: string `Doctor ${doctorId} deleted`};
    }

    resource function get hospitals() returns Hospital[] {
        return hospitalDb.toArray();
    }

    resource function get hospitals/[string hospitalId]() returns Hospital|http:NotFound {
        Hospital? h = hospitalDb[hospitalId];
        if h is Hospital {
            return h;
        }
        return <http:NotFound>{body: <ErrorResponse>{code: "HOSPITAL_NOT_FOUND", message: string `Hospital ${hospitalId} not found`}};
    }

    resource function post hospitals(@http:Payload Hospital h) returns Hospital|http:Conflict {
        if hospitalDb.hasKey(h.hospitalId) {
            return <http:Conflict>{body: <ErrorResponse>{code: "HOSPITAL_EXISTS", message: string `Hospital ${h.hospitalId} already exists`}};
        }
        string newId = string `H${hospitalCounter}`;
        hospitalCounter += 1;
        Hospital newH = {hospitalId: newId, name: h.name, address: h.address, city: h.city, phone: h.phone, specialties: h.specialties, bedCapacity: h.bedCapacity, hasEmergency: h.hasEmergency};
        hospitalDb[newId] = newH;
        log:printInfo(string `Created hospital ${newId}`);
        return newH;
    }

    resource function put hospitals/[string hospitalId](@http:Payload Hospital h) returns Hospital|http:NotFound {
        if !hospitalDb.hasKey(hospitalId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "HOSPITAL_NOT_FOUND", message: string `Hospital ${hospitalId} not found`}};
        }
        Hospital updated = {hospitalId: hospitalId, name: h.name, address: h.address, city: h.city, phone: h.phone, specialties: h.specialties, bedCapacity: h.bedCapacity, hasEmergency: h.hasEmergency};
        hospitalDb[hospitalId] = updated;
        log:printInfo(string `Updated hospital ${hospitalId}`);
        return updated;
    }

    resource function delete hospitals/[string hospitalId]() returns DeleteResponse|http:NotFound {
        if !hospitalDb.hasKey(hospitalId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "HOSPITAL_NOT_FOUND", message: string `Hospital ${hospitalId} not found`}};
        }
        _ = hospitalDb.remove(hospitalId);
        log:printInfo(string `Deleted hospital ${hospitalId}`);
        return {success: true, message: string `Hospital ${hospitalId} deleted`};
    }
}

// ─── Medical Insurance ─────────────────────────────────────────────────────────

service /insurance on providerSvcListener {
    function init() {
        log:printInfo("Medical Insurance service started on port 9205");
    }

    resource function get .() returns InsuranceCoverage[] {
        return insuranceDb.toArray();
    }

    resource function get [string patientId]() returns InsuranceCoverage|http:NotFound {
        InsuranceCoverage? cov = insuranceDb[patientId];
        if cov is InsuranceCoverage {
            return cov;
        }
        return <http:NotFound>{body: <ErrorResponse>{code: "NO_COVERAGE", message: string `No insurance coverage found for patient ${patientId}`}};
    }

    resource function post .(@http:Payload InsuranceCoverage cov) returns InsuranceCoverage|http:Conflict {
        if insuranceDb.hasKey(cov.patientId) {
            return <http:Conflict>{body: <ErrorResponse>{code: "COVERAGE_EXISTS", message: string `Coverage for patient ${cov.patientId} already exists`}};
        }
        string newCovId = string `COV${coverageCounter}`;
        coverageCounter += 1;
        InsuranceCoverage newCov = {coverageId: newCovId, patientId: cov.patientId, insurerId: cov.insurerId, insurerName: cov.insurerName, planName: cov.planName, validFrom: cov.validFrom, validTo: cov.validTo, status: cov.status, coveragePercent: cov.coveragePercent, annualDeductible: cov.annualDeductible, deductibleMet: cov.deductibleMet, coveredServices: cov.coveredServices};
        insuranceDb[cov.patientId] = newCov;
        log:printInfo(string `Created coverage ${newCovId} for patient ${cov.patientId}`);
        return newCov;
    }

    resource function put [string patientId](@http:Payload InsuranceCoverage cov) returns InsuranceCoverage|http:NotFound {
        if !insuranceDb.hasKey(patientId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "NO_COVERAGE", message: string `No coverage found for patient ${patientId}`}};
        }
        InsuranceCoverage updated = {coverageId: cov.coverageId, patientId: patientId, insurerId: cov.insurerId, insurerName: cov.insurerName, planName: cov.planName, validFrom: cov.validFrom, validTo: cov.validTo, status: cov.status, coveragePercent: cov.coveragePercent, annualDeductible: cov.annualDeductible, deductibleMet: cov.deductibleMet, coveredServices: cov.coveredServices};
        insuranceDb[patientId] = updated;
        log:printInfo(string `Updated coverage for patient ${patientId}`);
        return updated;
    }

    resource function delete [string patientId]() returns DeleteResponse|http:NotFound {
        if !insuranceDb.hasKey(patientId) {
            return <http:NotFound>{body: <ErrorResponse>{code: "NO_COVERAGE", message: string `No coverage found for patient ${patientId}`}};
        }
        _ = insuranceDb.remove(patientId);
        log:printInfo(string `Deleted coverage for patient ${patientId}`);
        return {success: true, message: string `Coverage for patient ${patientId} deleted`};
    }
}

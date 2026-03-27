// Mock policy database
// All policies are HealthGuard health insurance plans (GRP-HG-2024).
// Plan tiers per policy document:
//   Basic    – POL-HEALTH-00x – $100,000 coverage – $120.00/month
//   Standard – POL-HEALTH-00x – $150,000 coverage – $145.00/month
//   Enhanced – POL-HEALTH-00x – $250,000 coverage – $180.00/month
//   Premier  – POL-HEALTH-00x – $500,000 coverage – $350.00/month
map<InsurancePolicy> policyDatabase = {
    "john_doe": {
        username: "john_doe",
        policyNumber: "POL-HEALTH-001",
        policyType: "HEALTH",
        coverageAmount: 100000.00,
        premiumAmount: 120.00,
        startDate: "2024-01-01",
        endDate: "2025-01-01",
        status: "ACTIVE"
    },
    "emma_premier": {
        username: "emma_premier",
        policyNumber: "POL-HEALTH-002",
        policyType: "HEALTH",
        coverageAmount: 500000.00,
        premiumAmount: 350.00,
        startDate: "2024-01-01",
        endDate: "2025-01-01",
        status: "ACTIVE"
    },
    "alex_cashier": {
        username: "alex_cashier",
        policyNumber: "POL-HEALTH-006",
        policyType: "HEALTH",
        coverageAmount: 150000.00,
        premiumAmount: 145.00,
        startDate: "2024-03-01",
        endDate: "2025-03-01",
        status: "ACTIVE"
    },
    "sarah_williams": {
        username: "sarah_williams",
        policyNumber: "POL-HEALTH-007",
        policyType: "HEALTH",
        coverageAmount: 100000.00,
        premiumAmount: 120.00,
        startDate: "2023-06-01",
        endDate: "2024-06-01",
        status: "EXPIRED"
    },
    "michael_brown": {
        username: "michael_brown",
        policyNumber: "POL-HEALTH-008",
        policyType: "HEALTH",
        coverageAmount: 500000.00,
        premiumAmount: 350.00,
        startDate: "2024-01-15",
        endDate: "2025-01-15",
        status: "ACTIVE"
    },
    "rami.desilva@auth0.com": {
        username: "rami.desilva@auth0.com",
        policyNumber: "POL-HEALTH-003",
        policyType: "HEALTH",
        coverageAmount: 150000.00,
        premiumAmount: 145.00,
        startDate: "2024-02-01",
        endDate: "2025-02-01",
        status: "ACTIVE"
    },
    "rami.desilva.pri@auth0.com": {
        username: "rami.desilva.pri@auth0.com",
        policyNumber: "POL-HEALTH-004",
        policyType: "HEALTH",
        coverageAmount: 500000.00,
        premiumAmount: 350.00,
        startDate: "2024-02-01",
        endDate: "2025-02-01",
        status: "ACTIVE"
    },
    "sam": {
        username: "sam",
        policyNumber: "POL-HEALTH-009",
        policyType: "HEALTH",
        coverageAmount: 250000.00,
        premiumAmount: 180.00,
        startDate: "2024-01-15",
        endDate: "2025-01-15",
        status: "ACTIVE"
    },
    "pri_sam": {
        username: "pri_sam",
        policyNumber: "POL-HEALTH-005",
        policyType: "HEALTH",
        coverageAmount: 250000.00,
        premiumAmount: 180.00,
        startDate: "2024-03-01",
        endDate: "2025-03-01",
        status: "ACTIVE"
    },
    "employee_jack": {
        username: "employee_jack",
        policyNumber: "POL-HEALTH-010",
        policyType: "HEALTH",
        coverageAmount: 150000.00,
        premiumAmount: 145.00,
        startDate: "2024-02-10",
        endDate: "2025-02-10",
        status: "ACTIVE"
    }
};

// Mock claims database
// Valid claim types per HealthGuard policy document:
//   Outpatient    – doctor visits, specialist, lab, imaging, mental health outpatient
//   Hospitalization – inpatient hospital stay, surgery, mental health inpatient
//   Emergency     – emergency room visit
//   Pharmacy      – prescription drug (out-of-network pharmacy)
//   DME           – durable medical equipment purchase
//   Medical       – other medical services
map<Claim[]> claimsDatabase = {
    "john_doe": [
        {
            claimId: "CLM-001",
            claimType: "Hospitalization",
            amount: 3200.00,
            description: "Emergency appendix surgery and inpatient recovery",
            submittedDate: "2024-03-10",
            status: "APPROVED"
        },
        {
            claimId: "CLM-002",
            claimType: "Outpatient",
            amount: 450.00,
            description: "Specialist consultation and diagnostic lab tests",
            submittedDate: "2024-05-22",
            status: "PENDING"
        }
    ],
    "emma_premier": [
        {
            claimId: "CLM-003",
            claimType: "Hospitalization",
            amount: 12000.00,
            description: "Knee replacement surgery and inpatient rehabilitation",
            submittedDate: "2024-02-18",
            status: "APPROVED"
        }
    ],
    "alex_cashier": [
        {
            claimId: "CLM-004",
            claimType: "Outpatient",
            amount: 280.00,
            description: "Urgent care visit for acute respiratory infection",
            submittedDate: "2024-04-05",
            status: "APPROVED"
        },
        {
            claimId: "CLM-005",
            claimType: "Pharmacy",
            amount: 95.00,
            description: "Prescription medication - antibiotics and inhaler (out-of-network pharmacy)",
            submittedDate: "2024-06-01",
            status: "APPROVED"
        }
    ],
    "sarah_williams": [
        {
            claimId: "CLM-011",
            claimType: "Outpatient",
            amount: 150.00,
            description: "Annual wellness exam and routine blood panel",
            submittedDate: "2024-03-20",
            status: "APPROVED"
        }
    ],
    "michael_brown": [
        {
            claimId: "CLM-012",
            claimType: "Hospitalization",
            amount: 18500.00,
            description: "Cardiac catheterization and coronary stent placement",
            submittedDate: "2024-04-10",
            status: "APPROVED"
        },
        {
            claimId: "CLM-013",
            claimType: "Outpatient",
            amount: 640.00,
            description: "Cardiac rehabilitation outpatient sessions (8 sessions)",
            submittedDate: "2024-06-15",
            status: "APPROVED"
        }
    ],
    "rami.desilva@auth0.com": [
        {
            claimId: "CLM-006",
            claimType: "Outpatient",
            amount: 320.00,
            description: "Annual health screening and lipid panel",
            submittedDate: "2024-07-14",
            status: "APPROVED"
        }
    ],
    "sam": [
        {
            claimId: "CLM-007",
            claimType: "Outpatient",
            amount: 560.00,
            description: "Orthopedic specialist consultation and X-ray imaging",
            submittedDate: "2024-06-20",
            status: "APPROVED"
        }
    ],
    "pri_sam": [
        {
            claimId: "CLM-008",
            claimType: "Hospitalization",
            amount: 8500.00,
            description: "Laparoscopic cholecystectomy (gallbladder removal) and recovery",
            submittedDate: "2024-05-15",
            status: "APPROVED"
        },
        {
            claimId: "CLM-009",
            claimType: "Outpatient",
            amount: 180.00,
            description: "Post-operative follow-up consultation",
            submittedDate: "2024-06-10",
            status: "APPROVED"
        }
    ],
    "employee_jack": [
        {
            claimId: "CLM-010",
            claimType: "Medical",
            amount: 1200.00,
            description: "Comprehensive health screening and diagnostic tests",
            submittedDate: "2024-04-25",
            status: "APPROVED"
        },
        {
            claimId: "CLM-014",
            claimType: "DME",
            amount: 420.00,
            description: "CPAP device for diagnosed sleep apnea",
            submittedDate: "2024-07-08",
            status: "PENDING"
        }
    ]
};

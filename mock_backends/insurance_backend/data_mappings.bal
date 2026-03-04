// Mock policy database
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
        policyNumber: "POL-AUTO-001",
        policyType: "AUTO",
        coverageAmount: 50000.00,
        premiumAmount: 80.00,
        startDate: "2024-03-01",
        endDate: "2025-03-01",
        status: "ACTIVE"
    },
    "sarah_williams": {
        username: "sarah_williams",
        policyNumber: "POL-HOME-001",
        policyType: "HOME",
        coverageAmount: 250000.00,
        premiumAmount: 95.00,
        startDate: "2023-06-01",
        endDate: "2024-06-01",
        status: "EXPIRED"
    },
    "michael_brown": {
        username: "michael_brown",
        policyNumber: "POL-LIFE-001",
        policyType: "LIFE",
        coverageAmount: 1000000.00,
        premiumAmount: 200.00,
        startDate: "2024-01-15",
        endDate: "2044-01-15",
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
        policyNumber: "POL-AUTO-002",
        policyType: "AUTO",
        coverageAmount: 75000.00,
        premiumAmount: 95.00,
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
        policyNumber: "POL-LIFE-002",
        policyType: "LIFE",
        coverageAmount: 500000.00,
        premiumAmount: 150.00,
        startDate: "2024-02-10",
        endDate: "2044-02-10",
        status: "ACTIVE"
    }
};

// Mock claims database
map<Claim[]> claimsDatabase = {
    "john_doe": [
        {
            claimId: "CLM-001",
            claimType: "Hospitalization",
            amount: 3200.00,
            description: "Emergency appendix surgery",
            submittedDate: "2024-03-10",
            status: "APPROVED"
        },
        {
            claimId: "CLM-002",
            claimType: "Outpatient",
            amount: 450.00,
            description: "Specialist consultation and lab tests",
            submittedDate: "2024-05-22",
            status: "PENDING"
        }
    ],
    "emma_premier": [
        {
            claimId: "CLM-003",
            claimType: "Hospitalization",
            amount: 12000.00,
            description: "Knee replacement surgery",
            submittedDate: "2024-02-18",
            status: "APPROVED"
        }
    ],
    "alex_cashier": [
        {
            claimId: "CLM-004",
            claimType: "Accident",
            amount: 5500.00,
            description: "Vehicle collision repair",
            submittedDate: "2024-04-05",
            status: "APPROVED"
        },
        {
            claimId: "CLM-005",
            claimType: "Theft",
            amount: 800.00,
            description: "Stolen car accessories",
            submittedDate: "2024-06-01",
            status: "REJECTED"
        }
    ],
    "rami.desilva@auth0.com": [
        {
            claimId: "CLM-006",
            claimType: "Outpatient",
            amount: 320.00,
            description: "Annual health screening",
            submittedDate: "2024-07-14",
            status: "APPROVED"
        }
    ],
    "sam": [
        {
            claimId: "CLM-007",
            claimType: "Accident",
            amount: 2500.00,
            description: "Minor fender bender repair",
            submittedDate: "2024-06-20",
            status: "APPROVED"
        }
    ],
    "pri_sam": [
        {
            claimId: "CLM-008",
            claimType: "Hospitalization",
            amount: 8500.00,
            description: "Surgery and recovery",
            submittedDate: "2024-05-15",
            status: "APPROVED"
        },
        {
            claimId: "CLM-009",
            claimType: "Outpatient",
            amount: 180.00,
            description: "Follow-up consultation",
            submittedDate: "2024-06-10",
            status: "APPROVED"
        }
    ],
    "employee_jack": [
        {
            claimId: "CLM-010",
            claimType: "Medical",
            amount: 1200.00,
            description: "Routine medical examination",
            submittedDate: "2024-04-25",
            status: "APPROVED"
        }
    ]
};

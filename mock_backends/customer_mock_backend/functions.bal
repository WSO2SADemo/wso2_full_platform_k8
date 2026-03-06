// Business logic functions

// Calculate daily allowance based on previous salary (80% up to ceiling)
function calculateDailyAllowance(decimal monthlySalary) returns decimal {
    decimal dailyRate = monthlySalary / 30.0;
    decimal allowanceRate = dailyRate * 0.8;
    
    // Apply ceiling (example: max 1200 SEK/day)
    decimal maxAllowance = 1200.0;
    if allowanceRate > maxAllowance {
        return maxAllowance;
    }
    
    return allowanceRate;
}

// Validate work certificates (simplified validation)
function validateWorkCertificates(string[] certificates) returns boolean {
    if certificates.length() == 0 {
        return false;
    }
    
    // In real system, would validate certificate authenticity
    return true;
}

// Determine income base category
function determineIncomeBase(decimal monthlySalary) returns string {
    if monthlySalary >= 30000.0d {
        return "HIGH";
    } else if monthlySalary >= 20000.0d {
        return "MEDIUM";
    } else {
        return "LOW";
    }
}

// Calculate total benefit days (standard is 300 days)
function calculateTotalDays(string incomeBase) returns int {
    // Standard benefit period
    return 300;
}

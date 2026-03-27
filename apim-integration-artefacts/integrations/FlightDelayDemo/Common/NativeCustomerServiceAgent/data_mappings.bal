// NativeCustomerServiceAgent — Data Mappings & Formatting
// Utility functions for response formatting and text extraction.

// ── Tool result formatting ────────────────────────────────────────────────
function formatToolResult(string toolName, json result) returns string {
    json|error errField = result.'error;
    if errField is string {
        return string `Error executing ${toolName}: ${errField}`;
    }

    string resultStr = result.toJsonString();
    if resultStr.length() > 3000 {
        resultStr = resultStr.substring(0, 3000) + "... (truncated)";
    }

    string lower = toolName.toLowerAscii();
    string label = toolName;
    if lower == "getflights" || lower == "getallflights" {
        label = "Flight Status";
    } else if lower == "getflightbyid" {
        label = "Flight Details";
    } else if lower == "getactivedisruptions" {
        label = "Active Disruptions";
    } else if lower == "getpassengerbyid" {
        label = "Passenger Details";
    } else if lower.includes("booking") {
        label = "Booking Information";
    } else if lower.includes("alternative") {
        label = "Alternative Flights";
    } else if lower == "rebookpassenger" {
        label = "Rebooking Result";
    } else if lower.includes("compensation") {
        label = "Compensation";
    } else if lower.includes("notify") {
        label = "Notification";
    }

    return string `**${label}** (via ${toolName}):\n\n${resultStr}`;
}

// ── Helper: Extract ID-like value from text ───────────────────────────────
function extractIdFromText(string message) returns string? {
    string[] words = splitWords(message);
    foreach string word in words {
        string w = word.trim();
        if w.length() >= 2 && w.length() <= 10 {
            boolean hasLetter = false;
            boolean hasDigit = false;
            foreach string:Char c in w {
                if c >= "A" && c <= "Z" {
                    hasLetter = true;
                } else if c >= "0" && c <= "9" {
                    hasDigit = true;
                }
            }
            if hasLetter && hasDigit {
                return w;
            }
        }
    }
    return ();
}

// ── Helper: Split string by common delimiters ────────────────────────────
function splitWords(string s) returns string[] {
    string[] result = [];
    string current = "";
    foreach string:Char c in s {
        if c == " " || c == "," || c == "." || c == "?" || c == "!" {
            if current.length() > 0 {
                result.push(current);
                current = "";
            }
        } else {
            current = current + c;
        }
    }
    if current.length() > 0 {
        result.push(current);
    }
    return result;
}

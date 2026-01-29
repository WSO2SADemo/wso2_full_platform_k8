// Data transformation and mapping utilities

// Transform external customer format to internal format
function transformCustomerData(json externalCustomer) returns Customer|error {
    Customer customer = check externalCustomer.cloneWithType();
    return customer;
}

// Transform booking to notification message
function createBookingConfirmationMessage(Booking booking, Flight flight, Customer customer) returns string {
    string message = string `Dear ${customer.firstName} ${customer.lastName},

Your flight booking has been confirmed!

Booking Details:
- Booking ID: ${booking.bookingId}
- Flight: ${flight.flightNumber}
- Route: ${flight.origin} to ${flight.destination}
- Departure: ${flight.departureTime}
- Arrival: ${flight.arrivalTime}
- Seat: ${booking.seatNumber}
- Total Amount: ${booking.totalAmount.toString()}

Thank you for choosing our airline!`;
    
    return message;
}

// Map booking status to user-friendly message
function getStatusMessage(string status) returns string {
    match status {
        "CONFIRMED" => {
            return "Your booking is confirmed";
        }
        "PENDING" => {
            return "Your booking is pending confirmation";
        }
        "CANCELLED" => {
            return "Your booking has been cancelled";
        }
        "COMPLETED" => {
            return "Your flight has been completed";
        }
        _ => {
            return "Unknown status";
        }
    }
}

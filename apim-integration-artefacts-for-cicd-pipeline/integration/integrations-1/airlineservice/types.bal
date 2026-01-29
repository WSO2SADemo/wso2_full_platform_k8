// Airline domain types

type Customer record {|
    string customerId;
    string firstName;
    string lastName;
    string email;
    string phoneNumber;
    string loyaltyTier?;
|};

type Flight record {|
    string flightNumber;
    string origin;
    string destination;
    string departureTime;
    string arrivalTime;
    decimal price;
    int availableSeats;
|};

type BookingRequest record {|
    string customerId;
    string flightNumber;
    string seatPreference;
    string mealPreference?;
|};

type Booking record {|
    string bookingId;
    string customerId;
    string flightNumber;
    string seatNumber;
    string status;
    decimal totalAmount;
    string bookingDate;
|};

type PaymentRequest record {|
    string bookingId;
    string customerId;
    decimal amount;
    string paymentMethod;
    string cardNumber?;
|};

type PaymentResponse record {|
    string transactionId;
    string status;
    string message;
|};

type NotificationRequest record {|
    string customerId;
    string email;
    string subject;
    string message;
|};

type ApiResponse record {|
    boolean success;
    string message;
    json data?;
|};

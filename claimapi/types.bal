
// Domain types for the Claims backend (README.md section 3).

public type Customer record {|
    string customerId;
    string name;
    string email;
    string phone;
|};

public type Claim record {|
    string claimId;
    string customerId;
    string claimType;
    string description;
    decimal amount;
    string status;
    string[] documentsReceived;
    string[] missingDocuments;
    string? decision;
    string paymentStatus;
    string createdAt;
    string updatedAt;
|};

public type JourneyStep record {|
    int id;
    string claimId;
    string stepName;
    string status;
    string? detail;
    string occurredAt;
|};

public type RequestDocumentsRequest record {|
    string[] missingDocuments;
|};

public type DocumentsReceivedRequest record {|
    string[] documents;
|};

public type DecisionRequest record {|
    string decision;
    string? reason = ();
|};

public type ErrorResponse record {|
    string message;
|};

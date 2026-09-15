// MySQL access for the Claims backend, using ballerinax/mysql + ballerina/sql.

import ballerina/sql;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

configurable string dbHost = "127.0.0.1";
configurable int dbPort = 3307;
configurable string dbUser = "claims_app";
configurable string dbPassword = "claims_app_pw";
configurable string dbName = "claims_db";

final mysql:Client claimsDb = check new (
    host = dbHost,
    port = dbPort,
    user = dbUser,
    password = dbPassword,
    database = dbName
);

type ClaimRow record {|
    string claim_id;
    string customer_id;
    string claim_type;
    string description;
    decimal amount;
    string status;
    json documents_received;
    json missing_documents;
    string? decision;
    string payment_status;
    string created_at;
    string updated_at;
|};

type CustomerRow record {|
    string customer_id;
    string name;
    string email;
    string phone;
|};

type StepRow record {|
    int id;
    string claim_id;
    string step_name;
    string status;
    string? detail;
    string occurred_at;
|};

function toClaim(ClaimRow row) returns Claim|error {
    string[] documentsReceived = check row.documents_received.cloneWithType();
    string[] missingDocuments = check row.missing_documents.cloneWithType();
    return {
        claimId: row.claim_id,
        customerId: row.customer_id,
        claimType: row.claim_type,
        description: row.description,
        amount: row.amount,
        status: row.status,
        documentsReceived,
        missingDocuments,
        decision: row.decision,
        paymentStatus: row.payment_status,
        createdAt: row.created_at,
        updatedAt: row.updated_at
    };
}

function toCustomer(CustomerRow row) returns Customer => {
    customerId: row.customer_id,
    name: row.name,
    email: row.email,
    phone: row.phone
};

function toStep(StepRow row) returns JourneyStep => {
    id: row.id,
    claimId: row.claim_id,
    stepName: row.step_name,
    status: row.status,
    detail: row.detail,
    occurredAt: row.occurred_at
};

public function getAllClaims() returns Claim[]|error {
    stream<ClaimRow, sql:Error?> rs = claimsDb->query(`SELECT * FROM claims ORDER BY claim_id`);
    Claim[] claims = [];
    check from ClaimRow row in rs
        do {
            claims.push(check toClaim(row));
        };
    check rs.close();
    return claims;
}

public function getClaim(string claimId) returns Claim|error? {
    ClaimRow|sql:Error row = claimsDb->queryRow(`SELECT * FROM claims WHERE claim_id = ${claimId}`);
    if row is sql:NoRowsError {
        return ();
    }
    if row is sql:Error {
        return row;
    }
    return check toClaim(row);
}

public function getCustomer(string customerId) returns Customer|error? {
    CustomerRow|sql:Error row = claimsDb->queryRow(`SELECT * FROM customers WHERE customer_id = ${customerId}`);
    if row is sql:NoRowsError {
        return ();
    }
    if row is sql:Error {
        return row;
    }
    return toCustomer(row);
}

public function getJourneySteps(string claimId) returns JourneyStep[]|error {
    stream<StepRow, sql:Error?> rs = claimsDb->query(`SELECT * FROM claim_journey_steps WHERE claim_id = ${claimId} ORDER BY id`);
    JourneyStep[] steps = [];
    check from StepRow row in rs
        do {
            steps.push(toStep(row));
        };
    check rs.close();
    return steps;
}

public function addJourneyStep(string claimId, string stepName, string status, string? detail = ()) returns error? {
    _ = check claimsDb->execute(`
        INSERT INTO claim_journey_steps (claim_id, step_name, status, detail)
        VALUES (${claimId}, ${stepName}, ${status}, ${detail})
    `);
}

public function requestDocuments(string claimId, string[] missingDocuments) returns error? {
    string missingJson = missingDocuments.toJsonString();
    sql:ExecutionResult result = check claimsDb->execute(`
        UPDATE claims SET status = 'MISSING_DOCUMENTS', missing_documents = ${missingJson}
        WHERE claim_id = ${claimId}
    `);
    if result.affectedRowCount == 0 {
        return error(string `Claim ${claimId} not found`);
    }
    check addJourneyStep(claimId, "Documents requested", "DONE", "Notification sent to customer (mock)");
    check addJourneyStep(claimId, "Waiting for customer", "ACTIVE");
}

public function documentsReceived(string claimId, string[] documents) returns error? {
    Claim? existing = check getClaim(claimId);
    if existing is () {
        return error(string `Claim ${claimId} not found`);
    }
    string[] merged = existing.documentsReceived.clone();
    foreach string doc in documents {
        if merged.indexOf(doc) is () {
            merged.push(doc);
        }
    }
    string mergedJson = merged.toJsonString();
    string emptyMissing = (<string[]>[]).toJsonString();
    _ = check claimsDb->execute(`
        UPDATE claims
        SET documents_received = ${mergedJson}, missing_documents = ${emptyMissing}, status = 'READY'
        WHERE claim_id = ${claimId}
    `);
    check addJourneyStep(claimId, "Documents received", "DONE", "Customer submitted the requested documents");
}

public function submitDecision(string claimId, string decision) returns error? {
    sql:ExecutionResult result = check claimsDb->execute(`
        UPDATE claims SET decision = ${decision}, status = 'DECIDED' WHERE claim_id = ${claimId}
    `);
    if result.affectedRowCount == 0 {
        return error(string `Claim ${claimId} not found`);
    }
    check addJourneyStep(claimId, "Claim decision recorded", "DONE", "Decision: " + decision);
}

public function processPayment(string claimId) returns error? {
    sql:ExecutionResult result = check claimsDb->execute(`
        UPDATE claims SET payment_status = 'PAID', status = 'PAID' WHERE claim_id = ${claimId}
    `);
    if result.affectedRowCount == 0 {
        return error(string `Claim ${claimId} not found`);
    }
    check addJourneyStep(claimId, "Payment processed", "DONE");
    check addJourneyStep(claimId, "Customer notified", "DONE", "Notification sent to customer (mock)");
}

// Fixed seed values used to restore a demo claim to its original state.
// Only the three deterministic sample claims (README.md section 3) can be reset.
type SeedClaim record {|
    string claimType;
    string description;
    decimal amount;
    string status;
    string[] documentsReceived;
    string[] missingDocuments;
|};

final map<SeedClaim> seedClaims = {
    "CLM-1041": {
        claimType: "Water damage",
        description: "Minor water damage to kitchen ceiling following a burst pipe.",
        amount: 450.00,
        status: "READY",
        documentsReceived: ["incident_report.pdf", "photos.zip"],
        missingDocuments: []
    },
    "CLM-1042": {
        claimType: "Water damage",
        description: "Water damage to living room flooring and furniture after storm flooding.",
        amount: 2500.00,
        status: "MISSING_DOCUMENTS",
        documentsReceived: ["incident_report.pdf"],
        missingDocuments: ["proof_of_ownership.pdf", "repair_estimate.pdf"]
    },
    "CLM-1043": {
        claimType: "Accidental damage",
        description: "Accidental damage to a laptop dropped during a house move.",
        amount: 800.00,
        status: "READY",
        documentsReceived: ["incident_report.pdf", "purchase_receipt.pdf"],
        missingDocuments: []
    }
};

public function resetClaim(string claimId) returns error? {
    SeedClaim? seed = seedClaims[claimId];
    if seed is () {
        return error(string `Reset is only supported for the sample claims: ${seedClaims.keys().toBalString()}`);
    }
    string documentsJson = seed.documentsReceived.toJsonString();
    string missingJson = seed.missingDocuments.toJsonString();
    _ = check claimsDb->execute(`
        UPDATE claims
        SET claim_type = ${seed.claimType},
            description = ${seed.description},
            amount = ${seed.amount},
            status = ${seed.status},
            documents_received = ${documentsJson},
            missing_documents = ${missingJson},
            decision = NULL,
            payment_status = 'NOT_STARTED'
        WHERE claim_id = ${claimId}
    `);
    _ = check claimsDb->execute(`DELETE FROM claim_journey_steps WHERE claim_id = ${claimId}`);
    check addJourneyStep(claimId, "Claim received", "DONE", "Claim submitted by customer");
    check addJourneyStep(claimId, "Claim validated", "DONE", "All required fields present");
    if seed.missingDocuments.length() > 0 {
        check addJourneyStep(claimId, "Claim data retrieved", "DONE", "Claim and customer data loaded");
        check addJourneyStep(claimId, "Missing documents identified", "DONE",
            string:'join(", ", ...seed.missingDocuments) + " missing");
        check addJourneyStep(claimId, "Documents requested", "DONE", "Notification sent to customer (mock)");
    }
}

// Non-agentic durable Claims Workflow (README.md section 7):
//
//   Receive claim -> Validate -> Check documents
//       -> [missing?] -> request documents -> WAIT for external event -> resume
//       -> Process claim (decision + payment) -> Notify customer
//
// Built on the real `ballerina/workflow` module (verified on Ballerina
// Central, v0.9.0 - a Temporal-based durable workflow engine), run in
// IN_MEMORY mode (see Config.toml.example). Activities call the Claims
// backend's REST API rather than touching the database directly, so this
// service and claims-backend stay independently deployable.
//
// External events are declared as a dedicated events record (`ClaimWorkflowEvents`)
// on the workflow function signature; `workflow:sendData(...)` delivers data to the
// named field, and the workflow suspends on `wait events.<field>` until it arrives.

import ballerina/http;
import ballerina/workflow;

configurable string backendUrl = "http://localhost:8080";

final http:Client backendClient = check new (backendUrl);

// claimId -> workflow status shown in the Claims Portal. Tracked directly
// alongside the engine's own (in-memory, non-persisted) execution state.
public final map<string> workflowStatusByClaim = {};

function recordStatus(string claimId, string status) {
    workflowStatusByClaim[claimId] = status;
}

public type ClaimWorkflowInput record {|
    string claimId;
|};

public type DocumentsReceivedEvent record {|
    string[] documents;
|};

type ClaimWorkflowEvents record {|
    future<DocumentsReceivedEvent> documentsReceived;
|};

@workflow:Activity
function validateClaim(string claimId) returns boolean|error {
    json claim = check backendClient->get(string `/claims/${claimId}`);
    map<json> claimMap = check claim.ensureType();
    return claimMap.hasKey("claimId");
}

@workflow:Activity
function checkDocuments(string claimId) returns string[]|error {
    json claim = check backendClient->get(string `/claims/${claimId}`);
    map<json> claimMap = check claim.ensureType();
    return check claimMap.get("missingDocuments").cloneWithType();
}

@workflow:Activity
function requestMissingDocuments(string claimId, string[] missingDocuments) returns error? {
    http:Response _ = check backendClient->post(string `/claims/${claimId}/request-documents`,
        {missingDocuments: missingDocuments});
}

@workflow:Activity
function recordDocumentsReceived(string claimId, string[] documents) returns error? {
    http:Response _ = check backendClient->post(string `/claims/${claimId}/documents-received`,
        {documents: documents});
}

@workflow:Activity
function decideAndPay(string claimId) returns error? {
    http:Response _ = check backendClient->post(string `/claims/${claimId}/decision`,
        {decision: "APPROVED"});
    http:Response _ = check backendClient->post(string `/claims/${claimId}/payment`, {});
}

@workflow:Workflow
function claimsWorkflow(workflow:Context ctx, ClaimWorkflowInput input, ClaimWorkflowEvents events) returns json|error {
    string claimId = input.claimId;
    recordStatus(claimId, "RUNNING");

    do {
        boolean valid = check ctx->callActivity(validateClaim, args = {"claimId": claimId});
        if !valid {
            return error(string `claim ${claimId} failed validation`);
        }

        string[] missingDocuments = check ctx->callActivity(checkDocuments, args = {"claimId": claimId});

        if missingDocuments.length() > 0 {
            () _ = check ctx->callActivity(requestMissingDocuments,
                args = {"claimId": claimId, "missingDocuments": missingDocuments});

            recordStatus(claimId, "WAITING_FOR_DOCS");

            // Durable wait: suspends here until the external "documentsReceived"
            // event arrives via workflow:sendData(...), triggered by the Claims
            // Portal's "Submit missing documents" action through the
            // /workflows/{claimId}/documents-received control endpoint
            // (see control.bal). This is the pause -> external event -> resume
            // behaviour demonstrated in the portal's Claim Journey Timeline.
            DocumentsReceivedEvent received = check wait events.documentsReceived;

            recordStatus(claimId, "RUNNING");
            () _ = check ctx->callActivity(recordDocumentsReceived,
                args = {"claimId": claimId, "documents": received.documents});
        }

        () _ = check ctx->callActivity(decideAndPay, args = {"claimId": claimId});

        recordStatus(claimId, "COMPLETED");
        return {claimId: claimId, status: "COMPLETED"};
    } on fail error e {
        recordStatus(claimId, "FAILED");
        return e;
    }
}

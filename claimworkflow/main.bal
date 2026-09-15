
// Small HTTP control API the Claims Portal drives (README.md section 4.5/4.3):
// start a claim's durable workflow, deliver the "documents received" external
// event to resume it, and poll its status.

import ballerina/http;
import ballerina/log;
import ballerina/workflow;

configurable int servicePort = 8082;

listener http:Listener workflowListener = check new (servicePort);

// claimId -> the workflow engine's own instance id, so the resume/status
// calls below know which running workflow instance to talk to.
final map<string> workflowIdByClaim = {};

public type DocumentsReceivedRequest record {|
    string[] documents;
|};

service /workflows on workflowListener {

    resource function post [string claimId]/'start() returns json|http:InternalServerError {
        string|error workflowId = workflow:run(claimsWorkflow, {claimId: claimId});
        if workflowId is error {
            log:printError("failed to start claim workflow", workflowId, claimId = claimId);
            return <http:InternalServerError>{body: {message: workflowId.message()}};
        }
        workflowIdByClaim[claimId] = workflowId;
        return {claimId, workflowId, status: workflowStatusByClaim[claimId] ?: "RUNNING"};
    }

    resource function post [string claimId]/documents\-received(@http:Payload DocumentsReceivedRequest payload)
            returns json|http:NotFound|http:InternalServerError {
        string? workflowId = workflowIdByClaim[claimId];
        if workflowId is () {
            return <http:NotFound>{body: {message: string `no running workflow for claim ${claimId}; start it first`}};
        }
        error? result = workflow:sendData(claimsWorkflow, workflowId, "documentsReceived",
            {documents: payload.documents});
        if result is error {
            log:printError("failed to resume claim workflow", result, claimId = claimId);
            return <http:InternalServerError>{body: {message: result.message()}};
        }
        return {claimId, status: "RUNNING"};
    }

    resource function get [string claimId]/status() returns json {
        string status = workflowStatusByClaim[claimId] ?: "NOT_STARTED";
        return {claimId, status};
    }

    resource function post [string claimId]/reset() returns json {
        _ = workflowStatusByClaim.removeIfHasKey(claimId);
        _ = workflowIdByClaim.removeIfHasKey(claimId);
        return {claimId, status: "NOT_STARTED"};
    }

    resource function get health() returns json {
        return {status: "UP"};
    }
}

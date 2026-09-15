// Small HTTP control API the Claims Portal drives (README.md section 4.5/4.3),
// mirroring claimworkflow/main.bal one-for-one but backed by the agentic
// implementation in agent.bal: start a claim's durable agent, deliver the
// "documents received" external event to resume it, and poll its status.

import ballerina/http;
import ballerina/log;
import ballerina/workflow;

configurable int servicePort = 8083;

listener http:Listener agentListener = check new (servicePort);

// claimId -> the DurableAgent's own instance id, so the resume/status calls
// below know which running agent instance to talk to.
final map<string> agentInstanceIdByClaim = {};

service /agents on agentListener {

    resource function post [string claimId]/'start() returns json|http:InternalServerError {
        string|error instanceId = claimsProcessingAgent.run(
            string `Process insurance claim ${claimId} end to end.`);
        if instanceId is error {
            log:printError("failed to start claims processing agent", instanceId, claimId = claimId);
            return <http:InternalServerError>{body: {message: instanceId.message()}};
        }
        agentInstanceIdByClaim[claimId] = instanceId;
        setClaimAgentStatus(claimId, "RUNNING");
        return {claimId, instanceId, status: "RUNNING"};
    }

    resource function post [string claimId]/documents\-received(@http:Payload DocumentsReceivedRequest payload)
            returns json|http:NotFound|http:InternalServerError {
        string? instanceId = agentInstanceIdByClaim[claimId];
        if instanceId is () {
            return <http:NotFound>{body: {message: string `no running agent for claim ${claimId}; start it first`}};
        }
        // One-way data-event channel (no `response` type declared): the
        // returned correlation token isn't a readable turn result, so it is
        // intentionally discarded here rather than bound to a variable.
        do {
            _ = check claimsProcessingAgent.sendData(instanceId, "documentsReceived",
                {documents: payload.documents});
        } on fail error sendError {
            log:printError("failed to resume claims processing agent", sendError, claimId = claimId);
            return <http:InternalServerError>{body: {message: sendError.message()}};
        }
        setClaimAgentStatus(claimId, "RUNNING");
        return {claimId, status: "RUNNING"};
    }

    resource function get [string claimId]/status() returns json {
        string? instanceId = agentInstanceIdByClaim[claimId];
        if instanceId is () {
            return {claimId, status: "NOT_STARTED"};
        }

        // Non-blocking poll: AgentBusyError means still reasoning/suspended,
        // so fall back to the status markWaitingForDocuments (or start) set.
        string|error result = claimsProcessingAgent.getResult(instanceId);
        if result is string {
            setClaimAgentStatus(claimId, "COMPLETED");
            return {claimId, status: "COMPLETED", result};
        }
        if result is workflow:AgentBusyError {
            return {claimId, status: getClaimAgentStatus(claimId) ?: "RUNNING"};
        }
        setClaimAgentStatus(claimId, "FAILED");
        return {claimId, status: "FAILED", message: result.message()};
    }

    resource function post [string claimId]/reset() returns json {
        clearClaimAgentStatus(claimId);
        _ = agentInstanceIdByClaim.removeIfHasKey(claimId);
        return {claimId, status: "NOT_STARTED"};
    }

    resource function get health() returns json {
        return {status: "UP"};
    }
}

// Durable AI agent equivalent of the non-agentic Claims Workflow in
// claimworkflow/workflow.bal (README.md section 7) - this package implements
// README.md section 13 "Tutorial 2 Durable Agent":
//
//   Start assessment -> Retrieve claim -> Check documents
//       -> [missing?] -> request documents -> SUSPEND durable agent execution
//       -> external "documents received" event -> RESUME -> continue assessment
//       -> Generate recommendation
//
// Same business outcome as claimsWorkflow, but driven by an LLM reasoning loop
// instead of hand-written control flow. Built on the real, Ballerina-Central
// packages `ballerina/workflow:0.9.0` (`workflow:DurableAgent`,
// `workflow:DurableAgentConfig` - the object-model form used in the module's
// own "agent-order-processing" and "agent-object-model" examples) and
// `ballerina/ai:1.15.0` (`ai:McpToolKit`, `ai:getDefaultModelProvider`,
// `@ai:AgentTool`). Tools come straight from the Claims MCP server (claimmcp) -
// the same getClaim/getCustomer/requestMissingDocuments/submitClaimDecision/
// processPayment tools listed for the "Claims Processing Agent" in
// README.md section 11.1 - so this agent, claimmcp, and claims-backend stay
// independently deployable, exactly like the non-agentic workflow.
//
// One behaviour below is inferred rather than confirmed against a worked
// example: none of the workflow module's published examples drive a
// non-conversational, one-shot agent event mid-reasoning, so it is not
// independently confirmed that declaring `documentsReceived` in `events`
// alone makes the model durably suspend on it (only that a MULTI_EVENT `chat`
// channel does this for conversation turns). To make the suspend point
// unambiguous - and independently verifiable from the Claims Portal either
// way - the system prompt also requires the model to call the local
// `markWaitingForDocuments` tool right before it waits; that call is what
// actually drives the portal's "Waiting for documents" status. Verify the
// suspend/resume behaviour with `bal run` before demoing.

import ballerina/ai;
import ballerina/workflow;

configurable string mcpServerUrl = "http://localhost:9090/mcp";

// claimId -> status shown in the Claims Portal, mirroring claimworkflow's
// workflowStatusByClaim so the portal can poll either implementation the
// same way. Kept module-private and isolated so it can be safely read/written
// from both the isolated agent tool below and the control API (control.bal)
// via the accessor functions.
isolated map<string> claimAgentStatusByClaim = {};

# Records the status for a claim, used both by the agent tool below and by
# the control API (control.bal) to reflect start/resume/completion states.
#
# + claimId - The claim to update
# + status - The new status value
public isolated function setClaimAgentStatus(string claimId, string status) {
    lock {
        claimAgentStatusByClaim[claimId] = status;
    }
}

# Reads the current status recorded for a claim, if any.
#
# + claimId - The claim to look up
# + return - The recorded status, or () if none has been recorded
public isolated function getClaimAgentStatus(string claimId) returns string? {
    lock {
        return claimAgentStatusByClaim[claimId];
    }
}

# Removes any recorded status for a claim.
#
# + claimId - The claim to clear
public isolated function clearClaimAgentStatus(string claimId) {
    lock {
        _ = claimAgentStatusByClaim.removeIfHasKey(claimId);
    }
}

# Marks a claim as waiting for the customer to submit missing documents.
# Called by the Claims Processing Agent itself (see systemPrompt below) right
# before it durably suspends on the `documentsReceived` event, so the Claims
# Portal can show "Waiting for documents" without needing to introspect the
# agent's internal reasoning state.
#
# + claimId - The claim awaiting documents
# + return - A short confirmation the model can use in its own reasoning
@ai:AgentTool
isolated function markWaitingForDocuments(string claimId) returns string {
    setClaimAgentStatus(claimId, "WAITING_FOR_DOCS");
    return string `Recorded claim ${claimId} as waiting for documents.`;
}

final ai:Wso2ModelProvider claimsModel = check ai:getDefaultModelProvider();

// All five Claims MCP tools (getClaim, getCustomer, requestMissingDocuments,
// submitClaimDecision, processPayment - see claimmcp/main.bal) become
// available to the agent as-is.
final ai:McpToolKit claimsMcpToolkit = check new (mcpServerUrl);

public final workflow:DurableAgent claimsProcessingAgent = check new ({
    systemPrompt: {
        role: "Claims Processing Agent",
        instructions: string `You process a single insurance claim end to end.
                Steps: 1) call getClaim to load the claim; if the result has no
                claimId, stop and report that it failed validation. 2) look at
                missingDocuments on the claim. 3) if there are missing documents:
                call requestMissingDocuments, then call markWaitingForDocuments
                with the claimId, then wait for the documentsReceived event -
                do not submit a decision or process payment until that event
                arrives. 4) once documents are available (or none were
                missing), call submitClaimDecision with decision "APPROVED",
                then call processPayment. 5) finish with a short summary of
                what you did and why.`
    },
    model: claimsModel,
    tools: [claimsMcpToolkit, markWaitingForDocuments],
    events: {
        documentsReceived: {request: DocumentsReceivedEvent, cardinality: workflow:SINGLE_EVENT}
    },
    maxIter: 16
});

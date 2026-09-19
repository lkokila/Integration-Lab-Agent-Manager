// Amani General Insurance - Claims Chat Agent.
//
// A conversational agent fronting the Amani-Insurance-Claim-MCP-Tools (claimtools)
// toolset: getClaimAssessment, getCustomerProfile, requestMissingDocuments,
// recordDocumentsReceived, decideClaim, escalateToAdjuster, and settleClaim.

import ballerina/ai;
import ballerinax/amp as _;

configurable string claimsToolsServerUrl = "http://localhost:9091/mcp";

final ai:Wso2ModelProvider claimsChatModel = check ai:getDefaultModelProvider();

final ai:McpToolKit claimsToolKit = check new (claimsToolsServerUrl);

final ai:Agent claimsChatAgent = check new (
    systemPrompt = {
        role: string `Amani General Insurance Claims Assistant`,
        instructions: string `You help handle household insurance claims for Amani General Insurance.
Call getClaimAssessment first for any claim you are asked about; it returns the claim, the policy,
the coverage finding, the claimant's history, and any blockers in one call.
Call getCustomerProfile before deciding or escalating to see the claimant's other claims, open and closed.
Tools refuse with a status of REFUSED and a remedy rather than failing - read the remedy and follow it.
Never decide a claim that still has outstanding documents.
Always explain your reasoning and cite the coverage basis or policy clause when you approve, reject, or escalate a claim.`
    },
    model = claimsChatModel,
    tools = [claimsToolKit]
);

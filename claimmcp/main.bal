import ballerina/mcp;
import ballerina/http;

configurable string backendUrl = "http://localhost:8080";

listener mcp:StreamableHttpListener mcpListener = new (9090);
final http:Client backendClient = check new (backendUrl);

@mcp:StreamableHttpServiceConfig {info: {name: "MCP Service", version: "1.0.0"}}
service mcp:StreamableHttpService /mcp on mcpListener {
    @mcp:Tool {
        description: "Fetch a claim's current status, amount, documents received/missing, and decision by claim ID."
    }
    remote function getClaim(string claimId) returns json|error {
        return backendClient->get(string `/claims/${claimId}`);
    }

    @mcp:Tool {
        description: "Fetch a customer's contact details by customer ID."
    }
    remote function getCustomer(string customerId) returns json|error {
        return backendClient->get(string `/customers/${customerId}`);
    }

    @mcp:Tool {
        description: "Request the documents currently missing on a claim, sending a (mock) notification to the customer."
    }
    remote function requestMissingDocuments(string claimId) returns json|error {
        json claim = check backendClient->get(string `/claims/${claimId}`);
        map<json> claimMap = check claim.ensureType();
        string[] missingDocuments = check claimMap.get("missingDocuments").cloneWithType();
        return backendClient->post(string `/claims/${claimId}/request-documents`, {missingDocuments});
    }

    @mcp:Tool {
        description: "Submit a decision for a claim. decision must be either APPROVED or REJECTED."
    }
    remote function submitClaimDecision(string claimId, string decision) returns json|error {
        return backendClient->post(string `/claims/${claimId}/decision`, {decision});
    }

    @mcp:Tool {
        description: "Process payment for a claim that has already been decided."
    }
    remote function processPayment(string claimId) returns json|error {
        return backendClient->post(string `/claims/${claimId}/payment`, {});
    }

}

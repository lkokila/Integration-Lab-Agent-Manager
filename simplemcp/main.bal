// Minimal MCP server, kept deliberately as small as possible, to test
// deployment on Devant in isolation from the claimtools server. One tool,
// one string parameter, no backend calls, no extra config.

import ballerina/mcp;

configurable int mcpServerPort = 9092;

listener mcp:StreamableHttpListener mcpListener = check new (mcpServerPort);

@mcp:StreamableHttpServiceConfig {
    info: {
        name: "Simple MCP Server",
        version: "1.0.0"
    },
    sessionMode: mcp:STATELESS
}
service mcp:StreamableHttpService /mcp on mcpListener {

    # Says hello back to the given name.
    #
    # + name - The name to greet
    # + return - A greeting message
    @mcp:Tool {
        description: "Says hello back to the given name."
    }
    isolated remote function sayHello(string name) returns string {
        return string `Hello, ${name}!`;
    }
}

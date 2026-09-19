import ballerina/ai;
import ballerina/http;

listener http:Listener claimsChatHttpListener = check new (8000);
listener ai:Listener claimsChatAgentListener = new (listenOn = claimsChatHttpListener);

service /chat on claimsChatAgentListener {
    resource function post chat(@http:Payload ai:ChatReqMessage request) returns ai:ChatRespMessage|error {
        string stringResult = check claimsChatAgent.run(request.message, request.sessionId);
        return {message: stringResult};
    }
}

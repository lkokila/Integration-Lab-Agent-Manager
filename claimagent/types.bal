// Same event payload shape as claimworkflow's non-agentic DocumentsReceivedEvent
// (README.md section 7), so both implementations can be driven by the same
// Claims Portal "Submit missing documents" action.
public type DocumentsReceivedEvent record {|
    string[] documents;
|};

public type DocumentsReceivedRequest record {|
    string[] documents;
|};

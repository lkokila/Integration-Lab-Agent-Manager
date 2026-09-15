import { useCallback, useEffect, useState } from "react";
import { backend, workflow } from "../api";
import JourneyTimeline from "./JourneyTimeline";

const WORKFLOW_STATUS_LABELS = {
  NOT_STARTED: "Not started",
  RUNNING: "Processing",
  WAITING_FOR_DOCS: "Waiting for documents",
  COMPLETED: "Complete",
  FAILED: "Failed",
};

export default function ClaimDetail({ claimId, onBack }) {
  const [claim, setClaim] = useState(null);
  const [customer, setCustomer] = useState(null);
  const [steps, setSteps] = useState([]);
  const [workflowStatus, setWorkflowStatus] = useState("NOT_STARTED");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  const refresh = useCallback(async () => {
    const claimData = await backend.getClaim(claimId);
    setClaim(claimData);
    const [customerData, journeySteps] = await Promise.all([
      backend.getCustomer(claimData.customerId),
      backend.getJourney(claimId),
    ]);
    setCustomer(customerData);
    setSteps(journeySteps);
    try {
      const wf = await workflow.status(claimId);
      setWorkflowStatus(wf.status);
    } catch {
      setWorkflowStatus("NOT_STARTED");
    }
  }, [claimId]);

  useEffect(() => {
    refresh().catch((err) => setError(err.message));
    const interval = setInterval(() => refresh().catch(() => {}), 3000);
    return () => clearInterval(interval);
  }, [refresh]);

  async function run(action) {
    setBusy(true);
    setError(null);
    try {
      await action();
      await refresh();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  if (error && !claim) return <p className="error">Failed to load claim: {error}</p>;
  if (!claim) return <p>Loading claim...</p>;

  const canSubmitDocuments =
    workflowStatus === "WAITING_FOR_DOCS" || claim.status === "MISSING_DOCUMENTS";

  return (
    <div className="claim-detail">
      <button className="link-button" onClick={onBack}>
        &larr; Back to claims
      </button>

      <h2>{claim.claimId}</h2>
      {error && <p className="error">{error}</p>}

      <div className="claim-grid">
        <div>
          <dl>
            <dt>Customer</dt>
            <dd>{customer ? `${customer.name} (${customer.customerId})` : claim.customerId}</dd>
            <dt>Claim type</dt>
            <dd>{claim.claimType}</dd>
            <dt>Description</dt>
            <dd>{claim.description}</dd>
            <dt>Amount</dt>
            <dd>${Number(claim.amount).toLocaleString()}</dd>
            <dt>Status</dt>
            <dd>{claim.status}</dd>
            <dt>Documents received</dt>
            <dd>{claim.documentsReceived.join(", ") || "none"}</dd>
            <dt>Missing documents</dt>
            <dd>{claim.missingDocuments.join(", ") || "none"}</dd>
            <dt>Decision</dt>
            <dd>{claim.decision ?? "pending"}</dd>
            <dt>Payment status</dt>
            <dd>{claim.paymentStatus}</dd>
            <dt>Workflow state</dt>
            <dd className={`workflow-state workflow-${workflowStatus.toLowerCase()}`}>
              {WORKFLOW_STATUS_LABELS[workflowStatus] ?? workflowStatus}
            </dd>
          </dl>

          <div className="actions">
            <button
              disabled={busy || workflowStatus === "RUNNING" || workflowStatus === "COMPLETED"}
              onClick={() => run(() => workflow.start(claimId))}
            >
              Start claim processing
            </button>
            <button
              disabled={busy || !canSubmitDocuments}
              onClick={() => run(() => workflow.submitDocuments(claimId, claim.missingDocuments))}
            >
              Submit missing documents
            </button>
            <button
              disabled={busy}
              onClick={() =>
                run(async () => {
                  await backend.resetClaim(claimId);
                  await workflow.reset(claimId).catch(() => {});
                })
              }
            >
              Reset claim
            </button>
          </div>
        </div>

        <div>
          <h3>Claim journey</h3>
          <JourneyTimeline steps={steps} />
        </div>
      </div>
    </div>
  );
}

import { useEffect, useState } from "react";
import { backend } from "../api";

const STATUS_LABELS = {
  READY: "Ready",
  MISSING_DOCUMENTS: "Missing documents",
  DECIDED: "Decided",
  PAID: "Paid",
};

export default function ClaimsList({ onSelectClaim }) {
  const [claims, setClaims] = useState([]);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    backend
      .listClaims()
      .then(setClaims)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>Loading claims...</p>;
  if (error) return <p className="error">Failed to load claims: {error}</p>;

  return (
    <table className="claims-table">
      <thead>
        <tr>
          <th>Claim ID</th>
          <th>Type</th>
          <th>Amount</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        {claims.map((claim) => (
          <tr key={claim.claimId} onClick={() => onSelectClaim(claim.claimId)}>
            <td>{claim.claimId}</td>
            <td>{claim.claimType}</td>
            <td>${Number(claim.amount).toLocaleString()}</td>
            <td>
              <span className={`badge badge-${claim.status.toLowerCase()}`}>
                {STATUS_LABELS[claim.status] ?? claim.status}
              </span>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

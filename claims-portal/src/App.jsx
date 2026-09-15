import { useState } from "react";
import ClaimsList from "./components/ClaimsList";
import ClaimDetail from "./components/ClaimDetail";
import "./App.css";

export default function App() {
  const [selectedClaimId, setSelectedClaimId] = useState(null);

  return (
    <div className="app">
      <header className="app-header">
        <h1>Claims Portal</h1>
        <p className="muted">WSO2Con Africa 2026 &middot; Tutorial 1</p>
      </header>
      <main>
        {selectedClaimId ? (
          <ClaimDetail claimId={selectedClaimId} onBack={() => setSelectedClaimId(null)} />
        ) : (
          <ClaimsList onSelectClaim={setSelectedClaimId} />
        )}
      </main>
    </div>
  );
}

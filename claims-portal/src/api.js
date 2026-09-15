const BACKEND_URL = import.meta.env.VITE_BACKEND_URL ?? "http://localhost:8080";
const WORKFLOW_URL = import.meta.env.VITE_WORKFLOW_URL ?? "http://localhost:8082";

async function request(url, options) {
  const res = await fetch(url, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  const text = await res.text();
  const body = text ? JSON.parse(text) : undefined;
  if (!res.ok) {
    throw new Error(body?.message ?? `request to ${url} failed with ${res.status}`);
  }
  return body;
}

export const backend = {
  listClaims: () => request(`${BACKEND_URL}/claims`),
  getClaim: (claimId) => request(`${BACKEND_URL}/claims/${claimId}`),
  getCustomer: (customerId) => request(`${BACKEND_URL}/customers/${customerId}`),
  getJourney: (claimId) => request(`${BACKEND_URL}/claims/${claimId}/journey`),
  resetClaim: (claimId) =>
    request(`${BACKEND_URL}/claims/${claimId}/reset`, { method: "POST" }),
};

export const workflow = {
  start: (claimId) =>
    request(`${WORKFLOW_URL}/workflows/${claimId}/start`, { method: "POST" }),
  submitDocuments: (claimId, documents) =>
    request(`${WORKFLOW_URL}/workflows/${claimId}/documents-received`, {
      method: "POST",
      body: JSON.stringify({ documents }),
    }),
  status: (claimId) => request(`${WORKFLOW_URL}/workflows/${claimId}/status`),
  reset: (claimId) =>
    request(`${WORKFLOW_URL}/workflows/${claimId}/reset`, { method: "POST" }),
};

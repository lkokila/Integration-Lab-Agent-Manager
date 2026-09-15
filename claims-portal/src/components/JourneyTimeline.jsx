const ICONS = {
  DONE: "✓",
  ACTIVE: "◉",
  PENDING: "○",
};

export default function JourneyTimeline({ steps }) {
  if (!steps || steps.length === 0) {
    return <p className="muted">No journey steps recorded yet.</p>;
  }
  return (
    <ul className="timeline">
      {steps.map((step) => (
        <li key={step.id} className={`timeline-${step.status.toLowerCase()}`}>
          <span className="timeline-icon">{ICONS[step.status] ?? "?"}</span>
          <span className="timeline-label">{step.stepName}</span>
          {step.detail && <span className="timeline-detail">{step.detail}</span>}
        </li>
      ))}
    </ul>
  );
}

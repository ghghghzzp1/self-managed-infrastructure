import './LoadTestDashboard.css';

export default function LoadTestDashboard() {
  return (
    <main className="dashboard">
      <header className="dashboard__header">
        <h1 className="dashboard__title">Load Test Control Dashboard</h1>
        <p className="dashboard__subtitle">
          Control load tests and monitor circuit breaker status
        </p>
      </header>

      <div className="dashboard__actions">
        <button type="button" className="btn btn--read" disabled aria-label="Start READ load test">
          <span className="btn__icon btn__icon--play" aria-hidden />
          Start READ Load Test
        </button>
        <button type="button" className="btn btn--write" disabled aria-label="Start WRITE load test">
          <span className="btn__icon btn__icon--write" aria-hidden />
          Start WRITE Load Test
        </button>
      </div>

      <section className="circuit-breaker" aria-label="Circuit breaker status">
        <h2 className="circuit-breaker__title">Circuit Breaker Status</h2>
        <div className="circuit-breaker__indicator">
          <span className="circuit-breaker__glow" aria-hidden />
        </div>
        <div className="circuit-breaker__status">
          <span className="circuit-breaker__dot" aria-hidden />
          <strong>GREEN - NORMAL</strong>
        </div>
        <p className="circuit-breaker__description">System is operating normally</p>
        <p className="circuit-breaker__note">UI only - API not connected.</p>
      </section>
    </main>
  );
}

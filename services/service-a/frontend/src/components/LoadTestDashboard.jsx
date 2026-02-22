import { useEffect, useMemo, useRef, useState } from 'react';
import './LoadTestDashboard.css';

const SNAPSHOT_POLL_MS = 1500;
const REQUESTS_POLL_MS = 1200;

// JMeter 부하 테스트에서 사용하는 공격 시뮬레이션 IP 목록
// services/service-a/jmeter/ 테스트 설정과 동기화 필요
const ATTACK_IPS = new Set(['10.10.10.10']);

function safeJsonParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

async function fetchDefaultData(path, init) {
  const res = await fetch(path, {
    ...init,
    headers: {
      Accept: 'application/json',
      ...(init?.headers ?? {}),
    },
  });

  const text = await res.text();
  const json = safeJsonParse(text);

  if (!json || typeof json !== 'object') {
    throw new Error(`API 응답 파싱 실패: ${path}`);
  }

  const httpCode = json.httpCode;
  const error = json.error;

  if (!res.ok || (typeof httpCode === 'number' && httpCode >= 400) || error) {
    const msg = error?.message || `HTTP ${res.status}`;
    throw new Error(msg);
  }

  return json.data;
}

function formatClock(value) {
  if (!value) return '—';

  // Instant (2026-...Z) is safe with Date.
  if (typeof value === 'string') {
    // ZonedDateTime from Java can include: ...+09:00[Asia/Seoul]
    const cleaned = value.replace(/\[.*\]$/, '');
    const d = new Date(cleaned);
    if (!Number.isNaN(d.getTime())) {
      return d.toLocaleTimeString('ko-KR', { hour12: false });
    }
    // fallback: keep HH:mm:ss if possible
    const t = cleaned.split('T')[1];
    return t ? t.slice(0, 8) : cleaned;
  }

  const d = new Date(value);
  return Number.isNaN(d.getTime())
    ? '—'
    : d.toLocaleTimeString('ko-KR', { hour12: false });
}

function pct(n, d) {
  if (!d) return 0;
  return Math.max(0, Math.min(100, Math.round((n / d) * 100)));
}

function cbMeta(state) {
  switch (state) {
    case 'OPEN':
      return { label: 'OPEN', tone: 'danger' };
    case 'HALF_OPEN':
      return { label: 'HALF_OPEN', tone: 'warn' };
    case 'CLOSED':
      return { label: 'CLOSED', tone: 'ok' };
    default:
      return { label: state || '—', tone: 'default' };
  }
}

function statusTone(status) {
  if (status === 429) return 'blocked';
  if (status === 503) return 'circuit';
  if (status >= 500) return 'error';
  if (status >= 200 && status < 300) return 'ok';
  return 'default';
}

function trimLoadPath(path) {
  if (!path) return '—';
  return path.startsWith('/api/load') ? path.replace('/api/load', '') || '/' : path;
}

function buildIpSummary(events) {
  const map = new Map();

  for (const e of events) {
    const ip = e?.ip;
    const status = e?.status;
    if (!ip || typeof status !== 'number') continue;

    const cur = map.get(ip) || { ip, total: 0, ok: 0, blocked: 0, err5xx: 0 };
    cur.total += 1;
    if (status === 429) cur.blocked += 1;
    else if (status >= 500) cur.err5xx += 1;
    else if (status >= 200 && status < 300) cur.ok += 1;
    map.set(ip, cur);
  }

  return [...map.values()].sort((a, b) => b.total - a.total);
}

function StatusChip({ title, value, sub, tone }) {
  return (
    <div className={`chip chip--${tone || 'default'}`}>
      <div className="chip__top">
        <span className="chip__dot" aria-hidden />
        <span className="chip__title">{title}</span>
      </div>
      <div className="chip__value">{value}</div>
      {sub ? <div className="chip__sub">{sub}</div> : <div className="chip__sub chip__sub--empty" />}
    </div>
  );
}

function ToggleChip({ enabled, busy, onClick }) {
  return (
    <button
      type="button"
      className={`chip chip--toggle ${enabled ? 'chip--ok' : 'chip--danger'}`}
      onClick={onClick}
      disabled={busy}
      aria-label="Toggle rate limit"
    >
      <div className="chip__top">
        <span className="chip__dot" aria-hidden />
        <span className="chip__title">Rate Limit</span>
      </div>
      <div className="chip__value">{enabled ? 'ON' : 'OFF'}</div>
      <div className="chip__sub">{busy ? 'toggling…' : 'click to toggle'}</div>
    </button>
  );
}

function Card({ title, children, right }) {
  return (
    <section className="card">
      <header className="card__header">
        <h2 className="card__title">{title}</h2>
        {right ? <div className="card__right">{right}</div> : null}
      </header>
      <div className="card__body">{children}</div>
    </section>
  );
}

function RealtimeRequestFeed({ events }) {
  return (
    <div className="feed">
      <div className="feed__table" role="table" aria-label="Realtime request feed">
        <div className="feed__row feed__row--head" role="row">
          <div className="feed__cell" role="columnheader">Time</div>
          <div className="feed__cell" role="columnheader">IP</div>
          <div className="feed__cell" role="columnheader">Path</div>
          <div className="feed__cell feed__cell--num" role="columnheader">Status</div>
          <div className="feed__cell" role="columnheader">Event</div>
        </div>

        {events.map((e, idx) => {
          const key = e.traceId || `${e.timestamp}-${idx}`;
          const tone = statusTone(e.status);
          const ipTone = ATTACK_IPS.has(e.ip) ? 'attack' : 'normal';

          return (
            <div key={key} className={`feed__row feed__row--${tone}`} role="row">
              <div className="feed__cell feed__cell--mono" role="cell">{formatClock(e.timestamp)}</div>
              <div className={`feed__cell feed__cell--mono ip ip--${ipTone}`} role="cell">{e.ip || '—'}</div>
              <div className="feed__cell feed__cell--mono" role="cell">{trimLoadPath(e.path)}</div>
              <div className="feed__cell feed__cell--mono feed__cell--num" role="cell">{typeof e.status === 'number' ? e.status : '—'}</div>
              <div className="feed__cell feed__cell--mono" role="cell">{e.event || '—'}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function IpSummary({ summary }) {
  if (!summary.length) {
    return <div className="muted">No data.</div>;
  }

  const top = summary.slice(0, 6);

  return (
    <div className="ipSummary">
      {top.map((row) => {
        const attack = ATTACK_IPS.has(row.ip);
        const okPct = pct(row.ok, row.total);
        const blockedPct = pct(row.blocked, row.total);
        const errPct = pct(row.err5xx, row.total);

        return (
          <div key={row.ip} className="ipSummary__item">
            <div className="ipSummary__title">
              <span className={`ipDot ${attack ? 'ipDot--attack' : 'ipDot--normal'}`} aria-hidden />
              <span className="ipSummary__ip">{row.ip}</span>
              <span className="ipSummary__tag">{attack ? 'Attack' : 'Normal'}</span>
            </div>
            <div className="ipSummary__line">
              <span className="muted">Total</span>
              <strong>{row.total}</strong>
            </div>
            <div className="ipSummary__line">
              <span className="muted">Success (200)</span>
              <span>{row.ok} ({okPct}%)</span>
            </div>
            <div className="ipSummary__line">
              <span className="muted">Blocked (429)</span>
              <span className={row.blocked ? 'bad' : ''}>{row.blocked} ({blockedPct}%)</span>
            </div>
            <div className="ipSummary__line">
              <span className="muted">Errors (5xx)</span>
              <span className={row.err5xx ? 'bad' : ''}>{row.err5xx} ({errPct}%)</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function CbAndStatusDistribution({ snapshotHistory, events }) {
  const points = useMemo(() => {
    const raw = snapshotHistory
      .filter((s) => s && s.circuitBreakerState && s.timestamp)
      .slice(0, 260)
      .reverse(); // oldest -> newest

    return raw.map((s) => ({
      ts: s.timestamp,
      state: s.circuitBreakerState,
      tone: cbMeta(s.circuitBreakerState).tone,
    }));
  }, [snapshotHistory]);

  const oldestLabel = points.length ? formatClock(points[0].ts) : '—';
  const newestLabel = points.length ? formatClock(points[points.length - 1].ts) : '—';

  const [slide, setSlide] = useState(false);
  const newestTsRef = useRef(null);
  const timelineRef = useRef(null);
  const [stickToEnd, setStickToEnd] = useState(true);

  useEffect(() => {
    const newestTs = points.length ? points[points.length - 1].ts : null;
    if (!newestTs) return;
    if (newestTsRef.current === newestTs) return;
    newestTsRef.current = newestTs;

    setSlide(true);
    const t = window.setTimeout(() => setSlide(false), 220);
    return () => window.clearTimeout(t);
  }, [points]);

  useEffect(() => {
    if (!stickToEnd) return;
    const el = timelineRef.current;
    if (!el) return;
    el.scrollTo({ left: el.scrollWidth, behavior: 'smooth' });
  }, [stickToEnd, points]);

  const onTimelineScroll = (e) => {
    const el = e.currentTarget;
    const remain = el.scrollWidth - (el.scrollLeft + el.clientWidth);
    setStickToEnd(remain < 24);
  };

  const counts = useMemo(() => {
    const c = new Map();
    for (const e of events) {
      if (typeof e?.status !== 'number') continue;
      c.set(e.status, (c.get(e.status) || 0) + 1);
    }
    const order = [200, 429, 500, 503];
    return order.map((code) => ({ code, n: c.get(code) || 0 }));
  }, [events]);

  const max = Math.max(1, ...counts.map((x) => x.n));

  return (
    <div className="dist">
      <div className="dist__timelineWrap" aria-label="Circuit breaker state timeline">
        <div
          className="dist__timeline"
          ref={timelineRef}
          onScroll={onTimelineScroll}
          role="region"
          aria-label="Circuit breaker state timeline (scrollable)"
        >
          {points.length ? (
            <div className={`dist__ticks ${slide ? 'dist__ticks--slide' : ''}`}>
              {points.map((p, idx) => (
                <span
                  key={`${p.ts}-${idx}`}
                  className={[
                    'dist__tick',
                    `dist__tick--${p.tone}`,
                    idx === points.length - 1 ? 'dist__tick--latest' : '',
                  ].join(' ')}
                  title={`${formatClock(p.ts)} · ${p.state}`}
                  aria-hidden
                />
              ))}
            </div>
          ) : (
            <div className="muted">No snapshot history.</div>
          )}
        </div>
        <div className="dist__time" aria-hidden>
          <span className="dist__timeLabel">{oldestLabel}</span>
          <span className="dist__timeLabel dist__timeLabel--right">
            {newestLabel}
            {stickToEnd ? '' : ' (scroll → latest)'}
          </span>
        </div>
      </div>
      <div className="dist__bars" aria-label="HTTP status distribution">
        {counts.map(({ code, n }) => (
          <div key={code} className="dist__barRow">
            <div className="dist__barLabel">{code}</div>
            <div className="dist__barTrack">
              <div
                className={`dist__bar dist__bar--${code}`}
                style={{ width: `${Math.round((n / max) * 100)}%` }}
                aria-hidden
              />
            </div>
            <div className="dist__barValue">{n}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default function LoadTestDashboard() {
  const [snapshot, setSnapshot] = useState(null);
  const [snapshotHistory, setSnapshotHistory] = useState([]);
  const [events, setEvents] = useState([]);
  const [toggleBusy, setToggleBusy] = useState(false);
  const [error, setError] = useState(null);

  // Poll snapshot
  useEffect(() => {
    let stopped = false;
    let timer = null;
    let controller = null;

    const tick = async () => {
      controller?.abort();
      controller = new AbortController();

      try {
        const data = await fetchDefaultData('/api/system/snapshot', { signal: controller.signal });
        if (stopped) return;
        setSnapshot(data);
        setSnapshotHistory((prev) => [data, ...prev].slice(0, 360));
        setError(null);
      } catch (e) {
        if (!stopped) setError(e instanceof Error ? e.message : String(e));
      } finally {
        if (!stopped) timer = window.setTimeout(tick, SNAPSHOT_POLL_MS);
      }
    };

    tick();
    return () => {
      stopped = true;
      controller?.abort();
      if (timer) window.clearTimeout(timer);
    };
  }, []);

  // Poll recent requests
  useEffect(() => {
    let stopped = false;
    let timer = null;
    let controller = null;

    const tick = async () => {
      controller?.abort();
      controller = new AbortController();

      try {
        const data = await fetchDefaultData('/api/system/recent-requests?limit=50', { signal: controller.signal });
        if (stopped) return;
        setEvents(Array.isArray(data) ? data : []);
        setError(null);
      } catch (e) {
        if (!stopped) setError(e instanceof Error ? e.message : String(e));
      } finally {
        if (!stopped) timer = window.setTimeout(tick, REQUESTS_POLL_MS);
      }
    };

    tick();
    return () => {
      stopped = true;
      controller?.abort();
      if (timer) window.clearTimeout(timer);
    };
  }, []);

  const cb = cbMeta(snapshot?.circuitBreakerState);
  const dbPct = snapshot?.totalConnections ? pct(snapshot.activeConnections, snapshot.totalConnections) : 0;
  const waiting = snapshot?.waitingThreads ?? 0;

  const ipSummary = useMemo(() => buildIpSummary(events), [events]);

  const onToggleRateLimit = async () => {
    setToggleBusy(true);
    try {
      const data = await fetchDefaultData('/api/system/rate-limit/toggle', { method: 'POST' });
      setSnapshot((prev) => (prev ? { ...prev, rateLimitEnabled: data?.rateLimitEnabled } : prev));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setToggleBusy(false);
    }
  };

  return (
    <main className="obs">
      <header className="obs__header">
        <div>
          <h1 className="obs__title">Service-A Frontend — 실험 관측 대시보드</h1>
          <p className="obs__subtitle">Rate Limit Filter 기반 IP 차단 현황 실시간 관측</p>
        </div>
        {error ? <div className="obs__error">API 오류: {error}</div> : null}
      </header>

      <section className="obs__top" aria-label="System status bar">
        <StatusChip tone={cb.tone} title="Circuit Breaker" value={cb.label} />
        <ToggleChip enabled={!!snapshot?.rateLimitEnabled} onClick={onToggleRateLimit} busy={toggleBusy} />
        <StatusChip
          tone={dbPct >= 90 ? 'danger' : dbPct >= 70 ? 'warn' : 'ok'}
          title="DB Pool"
          value={snapshot ? `${snapshot.activeConnections}/${snapshot.totalConnections} (${dbPct}%)` : '—'}
          sub={waiting > 0 ? `⚠ ${waiting} waiting` : ' '}
        />
        <StatusChip
          tone={waiting > 0 ? 'warn' : 'default'}
          title="Waiting Threads"
          value={snapshot ? `${waiting}` : '—'}
          sub={waiting === 0 ? '0 (ok)' : ' '}
        />
        <StatusChip
          tone="default"
          title="Avg. Response"
          value={snapshot?.avgResponseTimeMs != null ? `${snapshot.avgResponseTimeMs}ms` : '—'}
          sub={snapshot?.timestamp ? formatClock(snapshot.timestamp) : ' '}
        />
      </section>

      <section className="obs__grid" aria-label="Observability main grid">
        <div className="obs__main">
          <Card title="Realtime Request Feed" right={<span className="muted">polling 1–2s</span>}>
            <RealtimeRequestFeed events={events} />
          </Card>

          <Card title="Circuit Breaker / HTTP Distribution">
            <CbAndStatusDistribution snapshotHistory={snapshotHistory} events={events} />
          </Card>
        </div>

        <div className="obs__side">
          <Card title="IP Summary">
            <IpSummary summary={ipSummary} />
          </Card>
        </div>
      </section>
    </main>
  );
}

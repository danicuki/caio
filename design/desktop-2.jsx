/* Caio — Desktop Job Detail + Email Unlock */

// ─────────────────────────────────────────────────────────────
// JOB DETAIL — 1440 × 1800
// ─────────────────────────────────────────────────────────────
const DesktopDetail = () => {
  const j = DETAIL_JOB;
  return (
    <div className="caio" style={{ width: 1440, minHeight: 1800, background: "var(--bg)" }}>
      <TopNav active="Jobs" onLight dense />

      {/* Breadcrumb */}
      <div style={{ padding: "16px 48px", fontSize: 13, color: "var(--muted)", display: "flex", alignItems: "center", gap: 8 }}>
        <a href="#" style={{ color: "var(--muted)" }}>Jobs</a>
        <span>›</span>
        <a href="#" style={{ color: "var(--muted)" }}>Software engineering</a>
        <span>›</span>
        <a href="#" style={{ color: "var(--muted)" }}>Stripe</a>
        <span>›</span>
        <span style={{ color: "var(--ink-2)" }}>Senior Backend Engineer, Payments</span>
      </div>

      {/* Header */}
      <header style={{ padding: "16px 48px 32px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr auto", gap: 32, alignItems: "end" }}>
          <div style={{ display: "flex", gap: 24, alignItems: "start" }}>
            <LogoChip logo={j.logo} size={88} radius={20}/>
            <div>
              <div style={{ display: "flex", gap: 8, alignItems: "center", marginBottom: 10 }}>
                <span style={{ fontSize: 15, color: "var(--ink-2)", fontWeight: 500 }}>{j.company}</span>
                <span style={{ color: "var(--muted)" }}>·</span>
                <span style={{ fontSize: 13, color: "var(--muted)" }}>Payments infrastructure</span>
                <span className="tag amber dot" style={{ marginLeft: 4 }}>Posted 2h ago</span>
              </div>
              <h1 className="serif" style={{ fontSize: 56, letterSpacing: "-0.025em", lineHeight: 1.02, maxWidth: 760 }}>
                Senior Backend Engineer,<br/>
                <span className="serif-italic" style={{ color: "var(--green)" }}>Payments</span>
              </h1>
              <div style={{ display: "flex", gap: 22, marginTop: 18, fontSize: 14, color: "var(--ink-2)", flexWrap: "wrap" }}>
                <Pill icon="pin">Remote · EU</Pill>
                <Pill icon="wallet" green><span className="mono">{j.salary}</span></Pill>
                <Pill icon="clock">Full-time</Pill>
                <Pill icon="globe">Visa sponsored</Pill>
                <Pill icon="users">8,000+ employees</Pill>
              </div>
            </div>
          </div>
          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <button className="btn btn-ghost">
              <Icon name="bookmark" size={15}/> Save
            </button>
            <button className="btn btn-primary btn-lg">
              Apply on {j.company} <Icon name="arrow-up-right" size={15}/>
            </button>
          </div>
        </div>
      </header>

      {/* Body */}
      <div style={{ padding: "0 48px 64px", display: "grid", gridTemplateColumns: "1fr 320px", gap: 40 }}>
        <article className="card" style={{ padding: 40, background: "var(--paper-2)" }}>
          {/* Skills row */}
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 28 }}>
            {j.tags.map(t => <span key={t} className="tag">{t}</span>)}
            <span className="tag green">Remote</span>
            <span className="tag">Senior</span>
          </div>

          <Section title="About the role">
            <p>At Stripe, the Money Movement team builds and operates the routing layer that delivers every dollar between accounts — billions of transactions per year, in 47 currencies, with end-to-end latency that has to stay under 200ms even when entire data centers go dark.</p>
            <p>We're looking for a senior engineer to own a critical service in this layer: the part that decides <em>how</em> a payment moves and <em>where</em> it goes, in real time, under load.</p>
          </Section>

          <Section title="What you'll do">
            <Bullet>Design and build distributed services that move money across providers, banks, and rails</Bullet>
            <Bullet>Drive a major rewrite of our retry and failover engine, with a focus on observability and graceful degradation</Bullet>
            <Bullet>Partner with product and risk teams to balance latency, cost, and reliability tradeoffs</Bullet>
            <Bullet>Mentor mid-level engineers, lead design reviews, set the bar for code quality on the team</Bullet>
            <Bullet>Be on a light, well-supported on-call rotation for the systems you own</Bullet>
          </Section>

          <Section title="What we're looking for">
            <Bullet>6+ years of backend engineering, ideally on systems that are latency-sensitive or money-sensitive</Bullet>
            <Bullet>Deep comfort with Go or a similar systems language; strong fundamentals in Postgres, queues, and distributed tracing</Bullet>
            <Bullet>A track record of leading non-trivial migrations or rewrites that ship</Bullet>
            <Bullet>Clear, calm written communication — async-first culture, every decision lives in a doc</Bullet>
          </Section>

          <Section title="What's in it for you">
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 14, marginTop: 8 }}>
              {[
                ["€140k – €185k", "base salary"],
                ["+ equity", "early-grant refresh program"],
                ["Remote EU", "or any of 5 hubs"],
                ["40 days", "PTO + holidays"],
                ["€2,000/yr", "learning + conferences"],
                ["Visa & relocation", "fully sponsored"],
              ].map(([n, l]) => (
                <div key={l} style={{ padding: "14px 16px", border: "1px solid var(--line)", borderRadius: 12, background: "var(--bg-2)" }}>
                  <div className="mono" style={{ fontSize: 16, color: "var(--green-2)" }}>{n}</div>
                  <div style={{ fontSize: 12, color: "var(--muted)", marginTop: 3 }}>{l}</div>
                </div>
              ))}
            </div>
          </Section>

          {/* Apply CTA at end */}
          <div style={{
            marginTop: 36, padding: 24, background: "var(--green-tint)", borderRadius: 14,
            border: "1px solid rgba(14,92,73,0.12)",
            display: "flex", justifyContent: "space-between", alignItems: "center", gap: 16,
          }}>
            <div>
              <h3 className="serif" style={{ fontSize: 22 }}>Apply on {j.company}'s site.</h3>
              <p style={{ fontSize: 13.5, color: "var(--ink-2)", marginTop: 4 }}>
                Caio doesn't gate applications. You'll be redirected to <span className="mono">{j.applyUrl}</span>.
              </p>
            </div>
            <button className="btn btn-primary btn-lg">Apply on {j.company} <Icon name="arrow-up-right" size={15}/></button>
          </div>
        </article>

        {/* Right rail */}
        <aside style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          {/* About company */}
          <div className="card" style={{ padding: 20 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 12 }}>
              <LogoChip logo={j.logo} size={34}/>
              <div>
                <div className="serif" style={{ fontSize: 17 }}>{j.company}</div>
                <div style={{ fontSize: 12, color: "var(--muted)" }}>Payments · 2010 · San Francisco</div>
              </div>
            </div>
            <p style={{ fontSize: 13, color: "var(--ink-2)", lineHeight: 1.55, marginBottom: 14 }}>
              Financial infrastructure for the internet. Building economic infrastructure for ambitious companies of every size.
            </p>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              {[
                ["8,000+", "employees"],
                ["47", "countries served"],
                ["72", "open roles"],
                ["⭐ 4.4", "Glassdoor"],
              ].map(([n, l]) => (
                <div key={l} style={{ padding: "8px 10px", background: "var(--bg-2)", borderRadius: 8 }}>
                  <div className="mono" style={{ fontSize: 14 }}>{n}</div>
                  <div style={{ fontSize: 11, color: "var(--muted)" }}>{l}</div>
                </div>
              ))}
            </div>
            <a href="#" className="ulink" style={{ display: "inline-flex", gap: 6, alignItems: "center", marginTop: 14, fontSize: 13 }}>
              All 72 jobs at {j.company} <Icon name="arrow-right" size={13}/>
            </a>
          </div>

          {/* Salary insight */}
          <div className="card" style={{ padding: 20 }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
              <div className="mono" style={{ fontSize: 11, letterSpacing: "0.08em", color: "var(--muted)", textTransform: "uppercase" }}>
                Salary insight
              </div>
              <span className="tag green">Top 18%</span>
            </div>
            <div className="serif" style={{ fontSize: 28, color: "var(--ink)" }}>€140k <span style={{ color: "var(--muted)" }}>–</span> €185k</div>
            <div style={{ fontSize: 12, color: "var(--muted)", marginBottom: 14 }}>vs. €112k median for Senior Backend, EU</div>
            {/* Range bar */}
            <div style={{ position: "relative", height: 26 }}>
              <div style={{ position: "absolute", top: 12, left: 0, right: 0, height: 2, background: "var(--line)" }}/>
              <div style={{ position: "absolute", top: 11, left: "48%", width: "32%", height: 4, background: "var(--green)", borderRadius: 2 }}/>
              <div style={{ position: "absolute", top: 7, left: "62%", width: 12, height: 12, borderRadius: 999, background: "var(--ink)", border: "3px solid var(--paper-2)" }}/>
              <div style={{ position: "absolute", top: 22, left: 0, fontSize: 10, color: "var(--muted)", fontFamily: "var(--mono)" }}>€60k</div>
              <div style={{ position: "absolute", top: 22, right: 0, fontSize: 10, color: "var(--muted)", fontFamily: "var(--mono)" }}>€220k+</div>
            </div>
          </div>

          {/* Similar */}
          <div className="card" style={{ padding: 20 }}>
            <div className="mono" style={{ fontSize: 11, letterSpacing: "0.08em", color: "var(--muted)", textTransform: "uppercase", marginBottom: 12 }}>
              Similar roles
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              {j.similar.map(s => (
                <div key={s.id} style={{ display: "flex", gap: 10 }}>
                  <LogoChip logo={s.logo} size={32}/>
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontSize: 13.5, lineHeight: 1.25 }}>{s.title}</div>
                    <div style={{ fontSize: 11.5, color: "var(--muted)", marginTop: 2 }}>{s.company} · {s.location}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </aside>
      </div>

      <Footer />
    </div>
  );
};

const Pill = ({ icon, children, green }) => (
  <span style={{
    display: "inline-flex", alignItems: "center", gap: 6,
    color: green ? "var(--green-2)" : "var(--ink-2)",
  }}>
    <Icon name={icon} size={14} style={{ color: green ? "var(--green)" : "var(--muted)" }}/>
    {children}
  </span>
);

const Section = ({ title, children }) => (
  <section style={{ marginTop: 32 }}>
    <h2 className="serif" style={{ fontSize: 26, letterSpacing: "-0.015em", marginBottom: 14 }}>{title}</h2>
    <div style={{ fontSize: 15, lineHeight: 1.65, color: "var(--ink-2)", display: "flex", flexDirection: "column", gap: 12 }}>
      {children}
    </div>
  </section>
);

const Bullet = ({ children }) => (
  <div style={{ display: "flex", gap: 12, alignItems: "start" }}>
    <span style={{
      flexShrink: 0, marginTop: 9, width: 6, height: 6, borderRadius: 999,
      background: "var(--green)",
    }}/>
    <div>{children}</div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// EMAIL UNLOCK STATE — 1440 × 1200
// Full-page modal over a dimmed Search results view.
// ─────────────────────────────────────────────────────────────
const DesktopUnlock = () => (
  <div className="caio" style={{ width: 1440, minHeight: 1200, background: "var(--bg)", position: "relative", overflow: "hidden" }}>
    {/* Backdrop — dimmed mini search page */}
    <div style={{ filter: "blur(2px) saturate(0.85)", opacity: 0.7 }}>
      <TopNav active="Jobs" onLight dense />
      <div style={{ padding: "20px 48px", background: "var(--paper)", borderBottom: "1px solid var(--line)" }}>
        <SearchBar size="sm" role="React engineer" location="Remote, EU" showCompany company="Any"/>
      </div>
      <div style={{ padding: "32px 48px", display: "grid", gridTemplateColumns: "264px 1fr 320px", gap: 32 }}>
        <div style={{ height: 600 }}/>
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {JOBS.slice(0, 5).map(j => <JobCardRow key={j.id} job={j} dense />)}
        </div>
        <div style={{ height: 400 }}/>
      </div>
    </div>

    {/* Scrim */}
    <div style={{ position: "absolute", inset: 0, background: "rgba(22,26,23,0.45)", backdropFilter: "blur(2px)" }}/>

    {/* Modal */}
    <div style={{
      position: "absolute", top: "52%", left: "50%", transform: "translate(-50%, -50%)",
      width: 880, background: "var(--paper-2)", borderRadius: 22,
      boxShadow: "0 40px 100px -20px rgba(0,0,0,0.4), 0 0 0 1px rgba(22,26,23,0.06)",
      display: "grid", gridTemplateColumns: "1fr 1fr", overflow: "hidden",
    }}>
      {/* Left — pitch */}
      <div style={{
        background: "var(--ink-surface)", color: "var(--ink-surface-fg)", padding: 40,
        display: "flex", flexDirection: "column", justifyContent: "space-between",
        position: "relative", overflow: "hidden",
      }}>
        <div style={{
          position: "absolute", top: -60, right: -60, width: 280, height: 280,
          borderRadius: 999, background: "radial-gradient(circle, var(--ink-surface-glow), transparent 70%)",
        }}/>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span className="logo-dot" style={{ width: 20, height: 20 }}/>
          <span className="serif" style={{ fontSize: 19, color: "var(--ink-surface-fg)" }}>caio</span>
        </div>
        <div>
          <div className="mono" style={{ fontSize: 11, letterSpacing: "0.08em", color: "var(--ink-surface-fg-3)", textTransform: "uppercase", marginBottom: 14 }}>
            ── Free. 20 seconds. No password.
          </div>
          <h2 className="serif" style={{ fontSize: 40, lineHeight: 1.05, letterSpacing: "-0.025em" }}>
            2,174 more jobs<br/>
            <span className="serif-italic" style={{ color: "var(--ink-surface-accent)" }}>are waiting.</span>
          </h2>
          <p style={{ marginTop: 16, fontSize: 14.5, color: "var(--ink-surface-fg-2)", lineHeight: 1.55 }}>
            Drop your email — we'll send you a magic link. No tracking pixels, no spam, no
            recruiter slop. You can delete your profile any time with one click.
          </p>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8, fontSize: 13, color: "var(--ink-surface-fg-2)" }}>
          {[
            ["spark", "Unlimited search and filters"],
            ["bookmark", "Save jobs and searches"],
            ["mail", "Daily digest of new matches"],
            ["bolt", "First-100 access to new tools"],
          ].map(([ic, t]) => (
            <div key={t} style={{ display: "flex", gap: 10, alignItems: "center" }}>
              <Icon name={ic} size={15} style={{ color: "var(--ink-surface-accent)" }}/>
              {t}
            </div>
          ))}
        </div>
      </div>

      {/* Right — form */}
      <div style={{ padding: 40, position: "relative" }}>
        <button style={{
          position: "absolute", top: 16, right: 16,
          width: 32, height: 32, borderRadius: 999, border: "1px solid var(--line)",
          background: "var(--paper-2)", color: "var(--ink-2)",
          display: "inline-flex", alignItems: "center", justifyContent: "center",
        }}>
          <Icon name="x" size={14}/>
        </button>
        <h3 className="serif" style={{ fontSize: 28, letterSpacing: "-0.02em", marginBottom: 4 }}>Create your free profile</h3>
        <p style={{ fontSize: 13.5, color: "var(--muted)", marginBottom: 22 }}>
          We'll email you a sign-in link. No password, no setup.
        </p>

        <label style={{ display: "block", marginBottom: 14 }}>
          <div className="mono" style={{ fontSize: 10.5, letterSpacing: "0.08em", color: "var(--muted)", textTransform: "uppercase", marginBottom: 6 }}>
            Work email
          </div>
          <div style={{
            display: "flex", alignItems: "center", gap: 10,
            border: "1.5px solid var(--green)", borderRadius: 10, padding: "0 14px",
            height: 48, background: "var(--paper-2)",
            boxShadow: "0 0 0 4px rgba(14,92,73,0.10)",
          }}>
            <Icon name="mail" size={16} style={{ color: "var(--muted)" }}/>
            <span style={{ fontSize: 15 }}>maria.almeida@</span>
            <span style={{ width: 1.5, height: 18, background: "var(--ink)", marginLeft: -2, animation: "blink 1s infinite" }}/>
          </div>
        </label>

        <button className="btn btn-primary btn-lg" style={{ width: "100%", marginBottom: 12 }}>
          Send me my sign-in link <Icon name="arrow-right" size={15}/>
        </button>

        <div style={{ display: "flex", alignItems: "center", gap: 10, margin: "16px 0", color: "var(--muted)", fontSize: 12 }}>
          <hr style={{ flex: 1, border: 0, borderTop: "1px solid var(--line)" }}/>
          <span>or</span>
          <hr style={{ flex: 1, border: 0, borderTop: "1px solid var(--line)" }}/>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          <button className="btn btn-ghost" style={{ height: 46 }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 .5a11.5 11.5 0 00-3.6 22.4c.6.1.8-.3.8-.6v-2c-3.2.7-3.9-1.5-3.9-1.5-.5-1.3-1.3-1.7-1.3-1.7-1.1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1.1 1.8 2.8 1.3 3.5 1 .1-.8.4-1.3.8-1.6-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.4-2.3 1.2-3.2-.1-.3-.5-1.5.1-3.2 0 0 1-.3 3.2 1.2a11 11 0 015.8 0c2.2-1.5 3.2-1.2 3.2-1.2.7 1.7.2 2.9.1 3.2.7.9 1.2 1.9 1.2 3.2 0 4.5-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.2v3.2c0 .3.2.7.8.6A11.5 11.5 0 0012 .5z"/></svg>
            GitHub
          </button>
          <button className="btn btn-ghost" style={{ height: 46 }}>
            <svg width="16" height="16" viewBox="0 0 24 24"><path d="M22 12.1c0-.8-.1-1.4-.2-2.1H12v3.9h5.7c-.1.9-.7 2.3-2 3.3l-.1.1 3 2.3.2.1c1.9-1.7 3.2-4.4 3.2-7.6z" fill="#4285F4"/><path d="M12 22c2.7 0 5-.9 6.7-2.4l-3.2-2.5c-.9.6-2 1-3.5 1a6.1 6.1 0 01-5.8-4.2l-.1.1-3.1 2.4-.1.1A10 10 0 0012 22z" fill="#34A853"/><path d="M6.2 13.9a6 6 0 010-3.8L1.9 6.8a10 10 0 000 10.4l4.3-3.3z" fill="#FBBC05"/><path d="M12 5.9c2 0 3.3.8 4 1.5l3-2.9A10 10 0 002 6.8l4.2 3.3A6.1 6.1 0 0112 5.9z" fill="#EA4335"/></svg>
            Google
          </button>
        </div>

        <p style={{ fontSize: 11.5, color: "var(--muted)", marginTop: 22, lineHeight: 1.5 }}>
          By continuing you agree to our <a href="#" className="ulink">Terms</a> and{" "}
          <a href="#" className="ulink">Privacy Policy</a>. We never share your email with employers.
        </p>
      </div>
    </div>

    <style>{`@keyframes blink { 50% { opacity: 0; } }`}</style>
  </div>
);

Object.assign(window, { DesktopDetail, DesktopUnlock });

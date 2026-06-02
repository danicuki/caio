/* Caio — Mobile screens (inside iOS device frame) */

// Shared mobile top bar
const MobileTopBar = ({ title, back = false }) => (
  <div style={{
    padding: "8px 18px 12px",
    display: "flex", alignItems: "center", justifyContent: "space-between",
    background: "var(--bg)", borderBottom: "1px solid var(--line)",
  }}>
    {back ? (
      <button style={{
        width: 36, height: 36, borderRadius: 999, border: "1px solid var(--line)",
        background: "var(--paper-2)", color: "var(--ink-2)", display: "flex",
        alignItems: "center", justifyContent: "center",
      }}>
        <Icon name="arrow-right" size={16} style={{ transform: "rotate(180deg)" }}/>
      </button>
    ) : (
      <Wordmark size={18} />
    )}
    {title && <span style={{ fontSize: 14, fontWeight: 500 }}>{title}</span>}
    <button style={{
      width: 36, height: 36, borderRadius: 999, border: "1px solid var(--line)",
      background: "var(--paper-2)", color: "var(--ink-2)", display: "flex",
      alignItems: "center", justifyContent: "center",
    }}>
      <Icon name="menu" size={16}/>
    </button>
  </div>
);

// ─────────────────────────────────────────────────────────────
// MOBILE LANDING
// ─────────────────────────────────────────────────────────────
const MobileLanding = () => (
  <div className="caio" style={{ background: "var(--bg)", height: "100%", paddingTop: 56 }}>
    <MobileTopBar />
    <div style={{ padding: "20px 18px 80px" }}>
      <div style={{
        display: "inline-flex", alignItems: "center", gap: 6, padding: "3px 8px 3px 4px",
        background: "var(--green-soft)", color: "var(--green-2)", borderRadius: 999,
        fontSize: 11, marginBottom: 16, border: "1px solid rgba(14,92,73,0.12)",
      }}>
        <span style={{
          padding: "1px 5px", background: "var(--green)", color: "var(--paper-2)",
          borderRadius: 999, fontSize: 9.5, fontFamily: "var(--mono)", letterSpacing: "0.04em",
        }}>NEW</span>
        1,182 jobs added today
      </div>
      <h1 className="serif" style={{ fontSize: 40, lineHeight: 1.0, letterSpacing: "-0.025em" }}>
        The next job<br/>
        you'll actually<br/>
        <span className="serif-italic" style={{ color: "var(--green)" }}>want</span> is in here.
      </h1>
      <p style={{ marginTop: 14, fontSize: 14, color: "var(--ink-2)", lineHeight: 1.5 }}>
        A search engine for tech jobs — updated every hour.
      </p>

      {/* Big counter */}
      <div className="card" style={{
        marginTop: 22, padding: 20,
        background: "linear-gradient(180deg, var(--paper) 0%, var(--bg-2) 100%)",
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 10.5, color: "var(--muted)", marginBottom: 8, fontFamily: "var(--mono)", letterSpacing: "0.06em", textTransform: "uppercase" }}>
          <span className="pulse" /> Live index
        </div>
        <div className="serif" style={{ fontSize: 56, lineHeight: 0.92, letterSpacing: "-0.03em" }}>435,343</div>
        <div style={{ marginTop: 4, fontSize: 13, color: "var(--ink-2)" }}>
          tech jobs and counting<span className="serif-italic" style={{ color: "var(--green)" }}>.</span>
        </div>
      </div>

      {/* Stacked search */}
      <div className="card" style={{ marginTop: 16, padding: 6, display: "flex", flexDirection: "column", gap: 1 }}>
        <MobileField icon="search" label="Role · keyword" value="Senior Backend Engineer"/>
        <div style={{ height: 1, background: "var(--line)", margin: "0 14px" }}/>
        <MobileField icon="pin" label="Location" value="Remote, EU"/>
        <button className="btn btn-primary" style={{ margin: 4, marginTop: 6, height: 46 }}>
          <Icon name="search" size={16} stroke={2}/>
          Search 435k jobs
        </button>
      </div>

      <div style={{ marginTop: 24 }}>
        <div className="mono" style={{ fontSize: 10, letterSpacing: "0.08em", color: "var(--muted)", textTransform: "uppercase", marginBottom: 10 }}>
          ── Fresh today
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
          {[JOBS[4], JOBS[0]].map(j => <JobCardMobile key={j.id} job={j}/>)}
        </div>
      </div>
    </div>
  </div>
);

const MobileField = ({ icon, label, value }) => (
  <div style={{ padding: "10px 14px", display: "flex", alignItems: "center", gap: 10 }}>
    <Icon name={icon} size={16} style={{ color: "var(--muted)" }}/>
    <div style={{ flex: 1 }}>
      <div className="mono" style={{ fontSize: 9.5, letterSpacing: "0.08em", color: "var(--muted)", textTransform: "uppercase" }}>{label}</div>
      <div style={{ fontSize: 14, color: "var(--ink)", marginTop: 1 }}>{value}</div>
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// MOBILE SEARCH
// ─────────────────────────────────────────────────────────────
const MobileSearch = () => (
  <div className="caio" style={{ background: "var(--bg)", height: "100%", paddingTop: 56 }}>
    {/* Sticky search header */}
    <div style={{ background: "var(--paper)", padding: "10px 14px 12px", borderBottom: "1px solid var(--line)" }}>
      <div style={{
        display: "flex", alignItems: "center", gap: 8, background: "var(--paper-2)",
        border: "1px solid var(--line)", borderRadius: 12, padding: "0 12px", height: 40,
      }}>
        <Icon name="search" size={16} style={{ color: "var(--muted)" }}/>
        <span style={{ fontSize: 14, color: "var(--ink)", flex: 1 }}>React engineer · Remote EU</span>
        <Icon name="x" size={14} style={{ color: "var(--muted)" }}/>
      </div>
      {/* Filter chips */}
      <div style={{ display: "flex", gap: 6, marginTop: 10, overflow: "hidden", whiteSpace: "nowrap" }}>
        <button className="btn btn-sm" style={{
          background: "var(--ink-surface)", color: "var(--ink-surface-fg)", height: 30, padding: "0 10px",
        }}>
          <Icon name="sliders" size={12}/> Filters · 3
        </button>
        {["Remote", "Senior+", "$180k+", "Visa"].map(t => (
          <span key={t} style={{
            display: "inline-flex", alignItems: "center", gap: 4,
            padding: "0 10px", height: 30, borderRadius: 999,
            border: "1px solid var(--line)", background: "var(--paper-2)",
            fontSize: 12.5, color: "var(--ink-2)",
          }}>{t} <Icon name="x" size={10}/></span>
        ))}
      </div>
    </div>

    <div style={{ padding: "14px 14px 0", display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
      <div className="serif" style={{ fontSize: 19 }}>
        <span className="mono" style={{ fontSize: 17 }}>2,184</span> matches
      </div>
      <button style={{ fontSize: 12, color: "var(--muted)", background: "transparent", border: 0 }}>
        Most recent <Icon name="chev-down" size={11}/>
      </button>
    </div>

    {/* Results */}
    <div style={{ padding: "12px 14px 80px", display: "flex", flexDirection: "column", gap: 10 }}>
      {JOBS.slice(0, 4).map(j => <JobCardMobile key={j.id} job={j}/>)}

      {/* Lock teaser */}
      <div style={{ position: "relative", marginTop: 6 }}>
        <div className="locked">
          <JobCardMobile job={JOBS[10]}/>
        </div>
        <div style={{
          position: "absolute", inset: "-12px -2px -8px",
          background: "linear-gradient(180deg, rgba(246,242,233,0) 0%, rgba(246,242,233,0.95) 50%, var(--bg) 100%)",
          display: "flex", alignItems: "flex-end", padding: "12px 0",
        }}>
          <div className="card" style={{
            padding: 16, width: "100%",
            display: "flex", alignItems: "center", gap: 12,
            boxShadow: "0 12px 30px -12px rgba(22,26,23,0.18)",
          }}>
            <div style={{
              width: 40, height: 40, borderRadius: 10,
              background: "var(--green-tint)", color: "var(--green-2)",
              display: "inline-flex", alignItems: "center", justifyContent: "center",
              border: "1px solid rgba(14,92,73,0.12)", flexShrink: 0,
            }}>
              <Icon name="lock" size={16}/>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="serif" style={{ fontSize: 15, lineHeight: 1.2 }}>
                <span className="mono" style={{ fontSize: 13 }}>2,174</span> more matches
              </div>
              <div style={{ fontSize: 11.5, color: "var(--muted)" }}>Free profile · 20 seconds</div>
            </div>
            <button className="btn btn-primary btn-sm">Unlock</button>
          </div>
        </div>
      </div>
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// MOBILE DETAIL
// ─────────────────────────────────────────────────────────────
const MobileDetail = () => {
  const j = DETAIL_JOB;
  return (
    <div className="caio" style={{ background: "var(--bg)", height: "100%", paddingTop: 56, position: "relative" }}>
      <MobileTopBar back />
      <div style={{ padding: "16px 18px 100px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 14 }}>
          <LogoChip logo={j.logo} size={48} radius={12}/>
          <div>
            <div style={{ fontSize: 12, color: "var(--muted)" }}>{j.company} · {j.posted}</div>
            <div style={{ fontSize: 12.5, color: "var(--ink-2)" }}>Payments infrastructure</div>
          </div>
        </div>
        <h1 className="serif" style={{ fontSize: 30, letterSpacing: "-0.02em", lineHeight: 1.05 }}>
          Senior Backend Engineer, <span className="serif-italic" style={{ color: "var(--green)" }}>Payments</span>
        </h1>

        <div style={{ display: "flex", flexWrap: "wrap", gap: "6px 14px", marginTop: 12, fontSize: 13, color: "var(--ink-2)" }}>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 5, color: "var(--muted)" }}>
            <Icon name="pin" size={13}/> Remote · EU
          </span>
          <span className="mono" style={{ color: "var(--green-2)" }}>{j.salary}</span>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 5, color: "var(--muted)" }}>
            <Icon name="clock" size={13}/> Full-time
          </span>
        </div>

        <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginTop: 14 }}>
          {j.tags.map(t => <span key={t} className="tag">{t}</span>)}
          <span className="tag green">Remote</span>
        </div>

        <hr className="dotted" style={{ margin: "22px 0" }}/>

        <h2 className="serif" style={{ fontSize: 19, marginBottom: 8 }}>About the role</h2>
        <p style={{ fontSize: 13.5, color: "var(--ink-2)", lineHeight: 1.6 }}>
          Build the routing layer that delivers every dollar between accounts at Stripe — billions
          of transactions per year, in 47 currencies. We're looking for a senior engineer to own
          the part that decides how a payment moves and where it goes, in real time.
        </p>

        <h2 className="serif" style={{ fontSize: 19, marginTop: 18, marginBottom: 8 }}>What you'll do</h2>
        <div style={{ display: "flex", flexDirection: "column", gap: 8, fontSize: 13.5, color: "var(--ink-2)", lineHeight: 1.55 }}>
          {[
            "Design and build distributed services that move money at scale",
            "Lead the rewrite of our retry and failover engine",
            "Mentor mid-level engineers and set the bar for code quality",
          ].map(t => (
            <div key={t} style={{ display: "flex", gap: 10 }}>
              <span style={{ flexShrink: 0, marginTop: 7, width: 5, height: 5, borderRadius: 999, background: "var(--green)" }}/>
              {t}
            </div>
          ))}
        </div>

        {/* Unlock teaser */}
        <div style={{
          marginTop: 24, padding: 18,
          background: "var(--paper-2)", borderRadius: 14,
          border: "1px solid var(--line)",
          display: "flex", gap: 14, alignItems: "center",
          position: "relative", overflow: "hidden",
        }}>
          <div style={{
            width: 42, height: 42, borderRadius: 10,
            background: "var(--green-tint)", color: "var(--green-2)",
            display: "inline-flex", alignItems: "center", justifyContent: "center",
            border: "1px solid rgba(14,92,73,0.12)", flexShrink: 0,
          }}>
            <Icon name="lock" size={17}/>
          </div>
          <div style={{ flex: 1 }}>
            <div className="serif" style={{ fontSize: 15.5 }}>Read the full description</div>
            <div style={{ fontSize: 12, color: "var(--muted)" }}>Free profile · no password</div>
          </div>
          <button className="btn btn-primary btn-sm">Unlock</button>
        </div>
      </div>

      {/* Sticky apply bar */}
      <div style={{
        position: "absolute", bottom: 34, left: 0, right: 0,
        padding: "12px 18px 16px",
        background: "rgba(251,249,243,0.85)",
        backdropFilter: "blur(14px) saturate(180%)",
        WebkitBackdropFilter: "blur(14px) saturate(180%)",
        borderTop: "1px solid var(--line)",
        display: "flex", alignItems: "center", gap: 10,
      }}>
        <button style={{
          width: 46, height: 46, borderRadius: 12, border: "1px solid var(--line)",
          background: "var(--paper-2)", color: "var(--ink-2)",
          display: "inline-flex", alignItems: "center", justifyContent: "center",
        }}>
          <Icon name="bookmark" size={17}/>
        </button>
        <button className="btn btn-primary" style={{ flex: 1, height: 46 }}>
          Apply on Stripe <Icon name="arrow-up-right" size={15}/>
        </button>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// MOBILE UNLOCK STATE (modal sheet)
// ─────────────────────────────────────────────────────────────
const MobileUnlock = () => (
  <div style={{ position: "relative", height: "100%", paddingTop: 56 }}>
    {/* Backdrop dim */}
    <div className="caio" style={{ background: "var(--bg)", height: "100%", opacity: 0.5, filter: "blur(2px)" }}>
      <MobileTopBar />
      <div style={{ padding: "14px 14px" }}>
        <div style={{ height: 50, background: "var(--paper-2)", borderRadius: 12, border: "1px solid var(--line)" }}/>
        <div style={{ marginTop: 14, display: "flex", flexDirection: "column", gap: 10 }}>
          {JOBS.slice(0, 3).map(j => <JobCardMobile key={j.id} job={j}/>)}
        </div>
      </div>
    </div>
    <div style={{ position: "absolute", inset: "56px 0 0", background: "rgba(22,26,23,0.4)" }}/>

    {/* Sheet */}
    <div style={{
      position: "absolute", bottom: 0, left: 0, right: 0,
      background: "var(--paper-2)", borderRadius: "22px 22px 0 0",
      padding: "16px 22px 50px",
      boxShadow: "0 -20px 40px -10px rgba(0,0,0,0.2)",
    }}>
      <div style={{ width: 42, height: 4, borderRadius: 999, background: "var(--line)", margin: "0 auto 18px" }}/>
      <div style={{
        width: 56, height: 56, borderRadius: 14,
        background: "var(--ink-surface)", color: "var(--ink-surface-fg)",
        display: "inline-flex", alignItems: "center", justifyContent: "center",
        marginBottom: 14,
      }}>
        <Icon name="lock" size={22}/>
      </div>
      <h2 className="serif" style={{ fontSize: 28, letterSpacing: "-0.02em", lineHeight: 1.1 }}>
        2,174 more jobs<br/>
        <span className="serif-italic" style={{ color: "var(--green)" }}>are waiting.</span>
      </h2>
      <p style={{ marginTop: 8, fontSize: 13.5, color: "var(--muted)" }}>
        Drop your email — we'll send a magic link. No password.
      </p>

      <div style={{
        marginTop: 18, display: "flex", alignItems: "center", gap: 10,
        border: "1.5px solid var(--green)", borderRadius: 12, padding: "0 14px",
        height: 50, background: "var(--paper-2)",
        boxShadow: "0 0 0 4px rgba(14,92,73,0.10)",
      }}>
        <Icon name="mail" size={16} style={{ color: "var(--muted)" }}/>
        <span style={{ fontSize: 15 }}>maria.almeida@</span>
        <span style={{ width: 1.5, height: 18, background: "var(--ink)", marginLeft: -2, animation: "blink 1s infinite" }}/>
      </div>
      <button className="btn btn-primary" style={{ width: "100%", marginTop: 10, height: 50 }}>
        Send my sign-in link <Icon name="arrow-right" size={15}/>
      </button>
      <div style={{ display: "flex", gap: 10, marginTop: 10 }}>
        <button className="btn btn-ghost" style={{ flex: 1, height: 46 }}>GitHub</button>
        <button className="btn btn-ghost" style={{ flex: 1, height: 46 }}>Google</button>
      </div>
      <p style={{ fontSize: 11, color: "var(--muted)", marginTop: 14, lineHeight: 1.5 }}>
        We never share your email with employers. <a href="#" className="ulink">Terms</a> · <a href="#" className="ulink">Privacy</a>.
      </p>
    </div>
  </div>
);

Object.assign(window, { MobileLanding, MobileSearch, MobileDetail, MobileUnlock });

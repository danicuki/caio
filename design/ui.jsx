/* Caio — shared UI atoms (search bar, job cards, nav, footer) */

// ─────────────────────────────────────────────────────────────
// Top Nav (desktop)
// ─────────────────────────────────────────────────────────────
const TopNav = ({ active = "Jobs", onLight = false, dense = false }) => (
  <div style={{
    display: "flex", alignItems: "center", justifyContent: "space-between",
    padding: dense ? "16px 32px" : "22px 48px",
    borderBottom: onLight ? "1px solid var(--line)" : "none",
    background: onLight ? "var(--paper)" : "transparent",
  }}>
    <div style={{ display: "flex", alignItems: "center", gap: 36 }}>
      <Wordmark size={22} />
      <nav style={{ display: "flex", gap: 26, fontSize: 14, color: "var(--ink-2)" }}>
        {["Jobs", "Companies", "Salaries", "For employers"].map(item => (
          <a key={item} href="#" style={{
            color: item === active ? "var(--ink)" : "var(--muted)",
            fontWeight: item === active ? 500 : 400,
            paddingBottom: 4,
            borderBottom: item === active ? "1.5px solid var(--ink)" : "1.5px solid transparent",
          }}>{item}</a>
        ))}
      </nav>
    </div>
    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
      <span style={{ display: "inline-flex", alignItems: "center", gap: 8, fontSize: 13, color: "var(--muted)" }}>
        <span className="pulse" />
        <span className="mono">435,343</span> live
      </span>
      <a href="#" style={{ fontSize: 14, color: "var(--ink-2)", padding: "8px 4px" }}>Sign in</a>
      <button className="btn btn-primary btn-sm">Create free profile</button>
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Search bar — three segments + button. Compact variant for header.
// ─────────────────────────────────────────────────────────────
const SearchBar = ({ size = "lg", role = "", location = "", company = "", showCompany = false }) => {
  const h = size === "lg" ? 60 : 48;
  const labelSize = size === "lg" ? 11 : 10;
  const fieldSize = size === "lg" ? 16 : 14;
  return (
    <div style={{
      display: "flex", alignItems: "stretch",
      background: "var(--paper-2)",
      border: "1px solid var(--line)",
      borderRadius: 14,
      padding: 6,
      boxShadow: size === "lg"
        ? "0 1px 0 rgba(255,255,255,0.6) inset, 0 12px 24px -16px rgba(22,26,23,0.18), 0 2px 6px -2px rgba(22,26,23,0.04)"
        : "0 1px 0 rgba(255,255,255,0.6) inset",
      gap: 0,
    }}>
      <Segment label="Role · keyword" icon="search" value={role || "Senior Backend Engineer"} placeholder grow h={h} ls={labelSize} fs={fieldSize}/>
      <Divider />
      <Segment label="Location" icon="pin" value={location || "Remote, EU"} grow h={h} ls={labelSize} fs={fieldSize}/>
      {showCompany && <>
        <Divider />
        <Segment label="Company" icon="building" value={company || "Any"} grow h={h} ls={labelSize} fs={fieldSize}/>
      </>}
      <button className="btn btn-primary" style={{
        height: h - 12, minWidth: size === "lg" ? 132 : 108, marginLeft: 6, borderRadius: 10,
        fontSize: size === "lg" ? 15 : 14,
      }}>
        <Icon name="search" size={16} stroke={2}/>
        Search jobs
      </button>
    </div>
  );
};

const Segment = ({ label, icon, value, placeholder, grow, h, ls, fs }) => (
  <div style={{
    flex: grow ? 1 : "0 0 auto", minWidth: 0,
    padding: "8px 14px", display: "flex", flexDirection: "column", justifyContent: "center",
    height: h - 12,
  }}>
    <div style={{
      fontSize: ls, fontFamily: "var(--mono)", letterSpacing: "0.06em",
      color: "var(--muted)", textTransform: "uppercase", marginBottom: 4,
    }}>{label}</div>
    <div style={{ display: "flex", alignItems: "center", gap: 8, color: "var(--ink)" }}>
      <Icon name={icon} size={15} style={{ color: "var(--muted)", flexShrink: 0 }}/>
      <span style={{
        fontSize: fs, fontWeight: 400, color: placeholder ? "var(--ink)" : "var(--ink)",
        whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
      }}>{value}</span>
    </div>
  </div>
);

const Divider = () => (
  <div style={{ width: 1, background: "var(--line)", margin: "8px 0", alignSelf: "stretch" }} />
);

// ─────────────────────────────────────────────────────────────
// JobCard — list variant (full width)
// ─────────────────────────────────────────────────────────────
const JobCardRow = ({ job, dense = false, active = false }) => (
  <div className="card" style={{
    padding: dense ? "16px 18px" : "20px 22px",
    display: "grid", gridTemplateColumns: "auto 1fr auto", gap: 16,
    alignItems: "start",
    borderColor: active ? "var(--ink)" : "var(--line)",
    boxShadow: active ? "0 0 0 1px var(--ink)" : "none",
  }}>
    <LogoChip logo={job.logo} size={dense ? 38 : 44} radius={10}/>
    <div style={{ minWidth: 0 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 6 }}>
        <h3 className="serif" style={{ fontSize: dense ? 19 : 21, lineHeight: 1.2 }}>{job.title}</h3>
        {job.posted && parseInt(job.posted) <= 5 && job.posted.includes("h") && (
          <span className="tag amber dot" style={{ fontSize: 10.5 }}>New</span>
        )}
      </div>
      <div style={{
        display: "flex", flexWrap: "wrap", gap: "4px 14px", alignItems: "center",
        fontSize: 13.5, color: "var(--ink-2)", marginBottom: dense ? 8 : 10,
      }}>
        <span style={{ fontWeight: 500 }}>{job.company}</span>
        <span style={{ color: "var(--muted)" }}>·</span>
        <span style={{ display: "inline-flex", alignItems: "center", gap: 5, color: "var(--muted)" }}>
          <Icon name="pin" size={13}/> {job.location}
        </span>
        {job.salary && <>
          <span style={{ color: "var(--muted)" }}>·</span>
          <span className="mono" style={{ color: "var(--green-2)", fontSize: 13 }}>{job.salary}</span>
        </>}
      </div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
        {job.tags.slice(0, 3).map(t => <span key={t} className="tag">{t}</span>)}
        {job.remote && <span className="tag green">Remote</span>}
        {job.visa && <span className="tag">Visa sponsor</span>}
      </div>
    </div>
    <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 8 }}>
      <span style={{ fontSize: 12, color: "var(--muted)" }}>{job.posted}</span>
      <button className="btn btn-ghost btn-sm" style={{ height: 30, padding: "0 10px" }}>
        <Icon name="bookmark" size={13}/> Save
      </button>
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// JobCard — block variant (used on landing as sample cards)
// ─────────────────────────────────────────────────────────────
const JobCardBlock = ({ job }) => (
  <div className="card" style={{ padding: 20, display: "flex", flexDirection: "column", gap: 14 }}>
    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
      <LogoChip logo={job.logo} size={40}/>
      <span style={{ fontSize: 12, color: "var(--muted)" }}>{job.posted}</span>
    </div>
    <div>
      <div style={{ fontSize: 12.5, color: "var(--muted)", marginBottom: 4 }}>{job.company}</div>
      <h3 className="serif" style={{ fontSize: 19, lineHeight: 1.25 }}>{job.title}</h3>
    </div>
    <div style={{ display: "flex", flexWrap: "wrap", gap: "4px 12px", fontSize: 12.5, color: "var(--ink-2)" }}>
      <span style={{ display: "inline-flex", alignItems: "center", gap: 5, color: "var(--muted)" }}>
        <Icon name="pin" size={12}/> {job.location}
      </span>
      <span className="mono" style={{ color: "var(--green-2)" }}>{job.salary}</span>
    </div>
    <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
      {job.tags.slice(0, 3).map(t => <span key={t} className="tag" style={{ fontSize: 11 }}>{t}</span>)}
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Mobile compact card
// ─────────────────────────────────────────────────────────────
const JobCardMobile = ({ job }) => (
  <div style={{
    padding: "16px 18px",
    background: "var(--paper-2)",
    borderRadius: 14,
    border: "1px solid var(--line)",
    display: "flex", gap: 12,
  }}>
    <LogoChip logo={job.logo} size={38}/>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 8 }}>
        <span style={{ fontSize: 12, color: "var(--muted)" }}>{job.company}</span>
        <span style={{ fontSize: 11, color: "var(--muted)" }}>{job.posted}</span>
      </div>
      <h3 className="serif" style={{ fontSize: 17, lineHeight: 1.2, margin: "2px 0 8px" }}>{job.title}</h3>
      <div style={{ fontSize: 12, color: "var(--ink-2)", display: "flex", flexWrap: "wrap", gap: "2px 10px", marginBottom: 8 }}>
        <span style={{ display: "inline-flex", alignItems: "center", gap: 4, color: "var(--muted)" }}>
          <Icon name="pin" size={11}/> {job.location}
        </span>
        <span className="mono" style={{ color: "var(--green-2)" }}>{job.salary}</span>
      </div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 4 }}>
        {job.tags.slice(0, 2).map(t => <span key={t} className="tag" style={{ fontSize: 10.5, height: 20 }}>{t}</span>)}
        {job.remote && <span className="tag green" style={{ fontSize: 10.5, height: 20 }}>Remote</span>}
      </div>
    </div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────
const Footer = () => (
  <div style={{
    background: "var(--ink-surface)", color: "var(--ink-surface-fg-2)", padding: "48px 48px 32px",
    display: "grid", gridTemplateColumns: "2fr 1fr 1fr 1fr", gap: 40, fontSize: 13,
  }}>
    <div>
      <div className="logo-mark" style={{ color: "var(--ink-surface-fg)", fontSize: 22 }}>
        <span className="logo-dot" />
        <span>caio</span>
      </div>
      <p style={{ marginTop: 14, color: "var(--ink-surface-fg-3)", maxWidth: 280, lineHeight: 1.55 }}>
        A search engine for tech jobs.
        Hundreds of thousands of roles indexed
        from across the web, refreshed every hour.
      </p>
    </div>
    {[
      ["Search", ["Frontend", "Backend", "ML & data", "Design", "DevOps & SRE", "Remote only"]],
      ["Caio", ["About", "How it works", "Changelog", "Pricing"]],
      ["Help", ["Contact", "Privacy", "Terms", "Status"]],
    ].map(([title, items]) => (
      <div key={title}>
        <div style={{ color: "var(--ink-surface-fg)", fontSize: 12.5, marginBottom: 12, letterSpacing: "0.04em", textTransform: "uppercase" }}>{title}</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {items.map(i => <a key={i} href="#" style={{ color: "var(--ink-surface-fg-2)" }}>{i}</a>)}
        </div>
      </div>
    ))}
  </div>
);

Object.assign(window, { TopNav, SearchBar, JobCardRow, JobCardBlock, JobCardMobile, Footer });

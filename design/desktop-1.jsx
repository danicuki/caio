/* Caio — Desktop screens */

// ─────────────────────────────────────────────────────────────
// LANDING — 1440 × 2100
// Editorial hero. Big stat. Search. Sample jobs. Unlock teaser.
// ─────────────────────────────────────────────────────────────
const DesktopLanding = () => (
  <div className="caio" style={{ width: 1440, minHeight: 2100, background: "var(--bg)" }}>
    <TopNav active="Jobs" />

    {/* Hero */}
    <section style={{ padding: "32px 48px 56px", position: "relative" }}>
      <div style={{ display: "grid", gridTemplateColumns: "1.15fr 0.85fr", gap: 56, alignItems: "end" }}>
        <div>
          <div style={{
            display: "inline-flex", alignItems: "center", gap: 8, padding: "5px 10px 5px 6px",
            background: "var(--green-soft)", color: "var(--green-2)", borderRadius: 999,
            fontSize: 12, marginBottom: 24, border: "1px solid rgba(14,92,73,0.12)",
          }}>
            <span style={{
              padding: "1px 6px", background: "var(--green)", color: "var(--paper-2)",
              borderRadius: 999, fontSize: 10.5, fontFamily: "var(--mono)", letterSpacing: "0.04em",
            }}>NEW</span>
            Refreshed 14 minutes ago · 1,182 jobs added today
          </div>
          <h1 className="serif" style={{ fontSize: 92, lineHeight: 0.98, letterSpacing: "-0.035em", maxWidth: 760 }}>
            The next job<br/>
            you'll actually <span className="serif-italic" style={{ color: "var(--green)" }}>want</span><br/>
            is in here somewhere.
          </h1>
          <p style={{ marginTop: 24, maxWidth: 560, fontSize: 17, lineHeight: 1.5, color: "var(--ink-2)" }}>
            Caio indexes every tech job worth reading — from Series A to public — and helps
            engineers, designers, and data folks find the one that fits, fast.
          </p>
        </div>

        {/* Big counter card */}
        <div style={{ position: "relative" }}>
          <div className="card" style={{
            padding: "32px 36px",
            background: "linear-gradient(180deg, var(--paper) 0%, var(--bg-2) 100%)",
            borderColor: "var(--line)",
            boxShadow: "0 24px 60px -32px rgba(22,26,23,0.18)",
          }}>
            <div style={{ display: "flex", alignItems: "center", gap: 8, fontSize: 12, color: "var(--muted)", marginBottom: 14, fontFamily: "var(--mono)", letterSpacing: "0.06em", textTransform: "uppercase" }}>
              <span className="pulse" /> Live index · 14:32 UTC
            </div>
            <div className="serif" style={{ fontSize: 96, lineHeight: 0.95, letterSpacing: "-0.04em" }}>
              <span style={{ color: "var(--ink)" }}>435,343</span>
            </div>
            <div style={{ marginTop: 8, fontSize: 16, color: "var(--ink-2)" }}>
              tech jobs and counting<span className="serif-italic" style={{ color: "var(--green)" }}>.</span>
            </div>
            <hr className="dotted" style={{ margin: "22px 0" }}/>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16 }}>
              {[
                ["+1,182", "added today"],
                ["7,400+", "companies"],
                ["64", "countries"],
              ].map(([n, l]) => (
                <div key={l}>
                  <div className="mono" style={{ fontSize: 22, color: "var(--ink)", letterSpacing: "-0.02em" }}>{n}</div>
                  <div style={{ fontSize: 11.5, color: "var(--muted)", marginTop: 2 }}>{l}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Decorative — small floating job ping */}
          <div style={{
            position: "absolute", top: -12, right: -16,
            background: "var(--ink-surface)", color: "var(--ink-surface-fg)",
            borderRadius: 12, padding: "10px 12px", fontSize: 12,
            display: "flex", alignItems: "center", gap: 8,
            boxShadow: "0 8px 20px -8px rgba(0,0,0,0.4)",
            transform: "rotate(2deg)",
          }}>
            <span className="pulse" style={{ background: "var(--ink-surface-accent)", boxShadow: "0 0 0 0 var(--ink-surface-glow)" }}/>
            <span className="mono" style={{ fontSize: 11 }}>+1 just posted</span>
            <span style={{ opacity: 0.7 }}>· Anthropic</span>
          </div>
        </div>
      </div>

      {/* Search bar */}
      <div style={{ marginTop: 40, maxWidth: 1100 }}>
        <SearchBar size="lg" />
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 14, fontSize: 13, color: "var(--muted)", flexWrap: "wrap" }}>
          <span>Try:</span>
          {["Senior React, remote EU", "Staff PM, fintech", "Data engineer, $200k+", "Founding eng, AI"].map(t => (
            <a key={t} href="#" style={{
              padding: "5px 10px", border: "1px solid var(--line)", borderRadius: 999,
              color: "var(--ink-2)", fontSize: 12.5, background: "var(--paper)",
            }}>{t}</a>
          ))}
        </div>
      </div>
    </section>

    {/* Latest sample jobs */}
    <section style={{ padding: "32px 48px 56px" }}>
      <div style={{ display: "flex", alignItems: "end", justifyContent: "space-between", marginBottom: 24 }}>
        <div>
          <div className="mono" style={{ fontSize: 11, letterSpacing: "0.08em", color: "var(--muted)", textTransform: "uppercase", marginBottom: 8 }}>
            ── Fresh from the index
          </div>
          <h2 className="serif" style={{ fontSize: 42, letterSpacing: "-0.02em" }}>
            Posted in the last <span className="serif-italic" style={{ color: "var(--green)" }}>few hours</span>
          </h2>
        </div>
        <a href="#" style={{ display: "inline-flex", alignItems: "center", gap: 6, color: "var(--ink)", fontSize: 14, borderBottom: "1px solid var(--ink)", paddingBottom: 2 }}>
          See all 435,343 jobs <Icon name="arrow-right" size={14}/>
        </a>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 16 }}>
        {[JOBS[4], JOBS[0], JOBS[1], JOBS[8], JOBS[5], JOBS[7]].map(j => <JobCardBlock key={j.id} job={j}/>)}
      </div>
    </section>

    {/* Imagery + unlock teaser */}
    <section style={{ padding: "32px 48px 64px" }}>
      <div style={{ display: "grid", gridTemplateColumns: "1.1fr 0.9fr", gap: 32, alignItems: "stretch" }}>
        {/* World imagery placeholder */}
        <div className="placeholder-img" style={{
          height: 420, borderRadius: 18, position: "relative", overflow: "hidden",
        }}>
          <div style={{ position: "absolute", top: 18, left: 20, color: "var(--muted)", fontFamily: "var(--mono)", fontSize: 10, letterSpacing: "0.1em" }}>
            EDITORIAL IMAGE · 1200×840 · warm, hand-drawn world map with light pulses where jobs were just posted
          </div>
          {/* tiny "city" dots, decorative */}
          <svg viewBox="0 0 1200 840" style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}>
            {[
              [220, 320], [340, 280], [460, 340], [560, 250], [680, 360], [800, 300],
              [900, 380], [320, 480], [520, 500], [720, 480], [880, 520], [410, 600],
              [610, 580], [780, 620], [240, 420], [460, 220], [950, 230], [620, 700],
            ].map(([x, y], i) => (
              <g key={i}>
                <circle cx={x} cy={y} r={i % 4 === 0 ? 6 : 3} fill="#0E5C49" opacity={i % 5 === 0 ? 0.85 : 0.4}/>
                {i % 4 === 0 && <circle cx={x} cy={y} r="14" fill="none" stroke="#0E5C49" strokeWidth="1" opacity="0.3"/>}
              </g>
            ))}
            {/* light hand-drawn continents */}
            <path d="M120,360 Q260,260 420,290 T700,320 Q880,300 1050,360 T1100,460 Q900,540 700,520 T420,490 Q280,510 160,470 Z"
              fill="none" stroke="rgba(22,26,23,0.18)" strokeWidth="1.2" strokeDasharray="3 3"/>
          </svg>
          <div style={{
            position: "absolute", bottom: 20, left: 20, right: 20,
            background: "rgba(251,249,243,0.92)", backdropFilter: "blur(6px)",
            borderRadius: 12, padding: "14px 16px", border: "1px solid var(--line)",
            display: "flex", justifyContent: "space-between", alignItems: "center",
          }}>
            <div>
              <div className="serif" style={{ fontSize: 18 }}>Hiring is happening, everywhere.</div>
              <div style={{ fontSize: 12.5, color: "var(--muted)", marginTop: 2 }}>3,184 cities · 64 countries · remote, hybrid, on-site</div>
            </div>
            <div style={{ display: "flex", gap: -8 }}>
              {["#635BFF", "#5E6AD2", "#0ACF83", "#F38020", "#C77B5C"].map((c, i) => (
                <div key={i} style={{
                  width: 28, height: 28, borderRadius: 999, background: c,
                  marginLeft: i === 0 ? 0 : -8, border: "2px solid var(--paper-2)",
                }}/>
              ))}
            </div>
          </div>
        </div>

        {/* How it works / unlock */}
        <div style={{
          background: "var(--ink-surface)", color: "var(--ink-surface-fg)", borderRadius: 18, padding: 32,
          display: "flex", flexDirection: "column", justifyContent: "space-between",
          position: "relative", overflow: "hidden",
        }}>
          <div style={{
            position: "absolute", top: -40, right: -40, width: 240, height: 240,
            borderRadius: 999, background: "radial-gradient(circle, var(--ink-surface-glow), transparent 70%)",
          }}/>
          <div>
            <div className="mono" style={{ fontSize: 11, letterSpacing: "0.08em", color: "var(--ink-surface-fg-3)", textTransform: "uppercase", marginBottom: 14 }}>
              ── Free to use
            </div>
            <h3 className="serif" style={{ fontSize: 36, letterSpacing: "-0.02em", lineHeight: 1.1 }}>
              Search 10 jobs as a guest.<br/>
              <span className="serif-italic" style={{ color: "var(--ink-surface-accent)" }}>Unlimited</span> with a free profile.
            </h3>
            <div style={{ marginTop: 20, display: "flex", flexDirection: "column", gap: 10, fontSize: 14.5, color: "var(--ink-surface-fg-2)" }}>
              {[
                "Save searches and get daily digests",
                "Track applications in one place",
                "Salary comparisons, sourced from listings",
              ].map(item => (
                <div key={item} style={{ display: "flex", gap: 10, alignItems: "center" }}>
                  <Icon name="check" size={16} style={{ color: "var(--ink-surface-accent)" }}/>
                  {item}
                </div>
              ))}
            </div>
          </div>
          <div style={{ display: "flex", gap: 10, marginTop: 28 }}>
            <button className="btn btn-lg" style={{ background: "var(--ink-surface-fg)", color: "var(--ink-surface)" }}>
              Create free profile <Icon name="arrow-right" size={15}/>
            </button>
            <button className="btn btn-lg" style={{ background: "transparent", color: "var(--ink-surface-fg)", border: "1px solid var(--ink-surface-line)" }}>
              Browse as guest
            </button>
          </div>
        </div>
      </div>
    </section>

    {/* Companies strip */}
    <section style={{ padding: "32px 48px 64px" }}>
      <div className="mono" style={{ fontSize: 11, letterSpacing: "0.08em", color: "var(--muted)", textTransform: "uppercase", marginBottom: 20, textAlign: "center" }}>
        Indexed from 7,400+ company career pages and ATS feeds
      </div>
      <div style={{
        display: "flex", alignItems: "center", justifyContent: "space-between",
        gap: 8, padding: "0 8px", flexWrap: "wrap",
      }}>
        {["Stripe", "Linear", "Vercel", "Notion", "Figma", "Anthropic", "Supabase", "Cloudflare", "Discord", "Ramp"].map(c => (
          <span key={c} className="serif" style={{
            fontSize: 22, color: "var(--muted)", padding: "8px 12px", letterSpacing: "-0.01em",
          }}>{c}</span>
        ))}
      </div>
    </section>

    <Footer />
  </div>
);

// ─────────────────────────────────────────────────────────────
// SEARCH RESULTS — 1440 × 1700
// ─────────────────────────────────────────────────────────────
const DesktopSearch = () => {
  const visible = JOBS.filter(j => !j.locked).slice(0, 10);
  return (
    <div className="caio" style={{ width: 1440, minHeight: 1700, background: "var(--bg)" }}>
      <TopNav active="Jobs" onLight dense />

      {/* Search header */}
      <div style={{ padding: "20px 48px", background: "var(--paper)", borderBottom: "1px solid var(--line)" }}>
        <SearchBar size="sm" role="React engineer" location="Remote, EU" showCompany company="Any" />
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "264px 1fr 320px", gap: 32, padding: "32px 48px 56px" }}>
        {/* Filters sidebar */}
        <aside style={{ position: "sticky", top: 0 }}>
          <FilterGroup title="Role family" items={[
            ["Software engineering", 184320, true],
            ["Product & design", 28140, false],
            ["Data & ML", 38150, false],
            ["DevOps & SRE", 21800, false],
            ["Security", 9420, false],
            ["Product mgmt", 14250, false],
          ]}/>
          <FilterGroup title="Seniority" items={[
            ["Junior", 38000, false],
            ["Mid-level", 124200, false],
            ["Senior", 168500, true],
            ["Staff +", 41200, false],
          ]}/>
          <FilterGroup title="Workplace" items={[
            ["Remote", 142300, true],
            ["Hybrid", 98400, false],
            ["On-site", 194600, false],
          ]}/>
          <FilterGroup title="Salary" items={[
            ["$80k+", 91400, false],
            ["$120k+", 64300, false],
            ["$180k+", 28400, true],
            ["$250k+", 8200, false],
          ]}/>
          <FilterGroup title="Perks" items={[
            ["Visa sponsorship", 41200, true],
            ["4-day week", 1840, false],
            ["Equity", 38200, false],
          ]}/>
        </aside>

        {/* Results */}
        <main>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 18 }}>
            <div>
              <h1 className="serif" style={{ fontSize: 32, letterSpacing: "-0.02em" }}>
                <span className="mono" style={{ fontSize: 28 }}>2,184</span> React engineer jobs
              </h1>
              <div style={{ fontSize: 13, color: "var(--muted)", marginTop: 4 }}>
                Remote · EU · Senior+ · refreshed 12 min ago
              </div>
            </div>
            <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <span style={{ fontSize: 13, color: "var(--muted)" }}>Sort</span>
              <button className="btn btn-ghost btn-sm">Most recent <Icon name="chev-down" size={13}/></button>
            </div>
          </div>

          {/* Active filter pills */}
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 16 }}>
            {[
              "React engineer", "Remote", "EU", "Senior+", "$180k+", "Visa sponsorship",
            ].map(t => (
              <span key={t} style={{
                display: "inline-flex", alignItems: "center", gap: 6,
                padding: "5px 6px 5px 11px", borderRadius: 999, background: "var(--ink-surface)",
                color: "var(--ink-surface-fg)", fontSize: 12,
              }}>
                {t}
                <span style={{
                  width: 18, height: 18, borderRadius: 999, background: "var(--ink-surface-line)",
                  display: "inline-flex", alignItems: "center", justifyContent: "center",
                }}>
                  <Icon name="x" size={10}/>
                </span>
              </span>
            ))}
            <button style={{
              fontSize: 12, color: "var(--muted)", border: "none", background: "transparent",
              padding: "5px 8px", textDecoration: "underline", textUnderlineOffset: 3,
            }}>Clear all</button>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            <JobCardRow job={JOBS[0]} active />
            {visible.slice(1).map(j => <JobCardRow key={j.id} job={j} dense />)}
          </div>

          {/* Unlock gate */}
          <UnlockGate />
        </main>

        {/* Right rail — job preview */}
        <aside>
          <RightRailPreview job={JOBS[0]} />
        </aside>
      </div>
    </div>
  );
};

const FilterGroup = ({ title, items }) => (
  <div style={{ marginBottom: 28 }}>
    <div style={{
      fontSize: 11.5, fontFamily: "var(--mono)", letterSpacing: "0.08em",
      color: "var(--muted)", textTransform: "uppercase", marginBottom: 12,
    }}>{title}</div>
    <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
      {items.map(([label, count, on]) => (
        <label key={label} style={{
          display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10,
          cursor: "pointer", fontSize: 13.5, color: on ? "var(--ink)" : "var(--ink-2)",
          fontWeight: on ? 500 : 400,
        }}>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 9 }}>
            <span style={{
              width: 16, height: 16, borderRadius: 4,
              border: on ? "1.5px solid var(--green)" : "1.5px solid var(--line)",
              background: on ? "var(--green)" : "var(--paper-2)",
              display: "inline-flex", alignItems: "center", justifyContent: "center", color: "var(--paper-2)",
            }}>
              {on && <Icon name="check" size={11} stroke={2.5}/>}
            </span>
            {label}
          </span>
          <span className="mono" style={{ fontSize: 11.5, color: "var(--muted)" }}>{count.toLocaleString()}</span>
        </label>
      ))}
    </div>
  </div>
);

const UnlockGate = () => (
  <div style={{ position: "relative", marginTop: 12 }}>
    {/* Blurred preview cards */}
    <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
      {JOBS.filter(j => j.locked).map(j => (
        <div className="locked" key={j.id}>
          <JobCardRow job={j} dense />
        </div>
      ))}
    </div>
    {/* Overlay card */}
    <div style={{
      position: "absolute", inset: "-12px -8px 0 -8px",
      background: "linear-gradient(180deg, rgba(246,242,233,0) 0%, rgba(246,242,233,0.95) 38%, var(--bg) 65%)",
      display: "flex", alignItems: "flex-end", justifyContent: "center",
      paddingBottom: 12, pointerEvents: "none",
    }}>
      <div className="card" style={{
        pointerEvents: "auto", padding: 24, maxWidth: 560,
        background: "var(--paper-2)",
        boxShadow: "0 16px 40px -16px rgba(22,26,23,0.18)",
        display: "flex", gap: 20, alignItems: "center",
      }}>
        <div style={{
          width: 56, height: 56, borderRadius: 14,
          background: "var(--green-tint)", color: "var(--green-2)",
          display: "inline-flex", alignItems: "center", justifyContent: "center",
          border: "1px solid rgba(14,92,73,0.12)", flexShrink: 0,
        }}>
          <Icon name="lock" size={22}/>
        </div>
        <div style={{ flex: 1 }}>
          <h3 className="serif" style={{ fontSize: 22, lineHeight: 1.2 }}>
            <span className="mono" style={{ fontSize: 18 }}>2,174</span> more jobs match this search.
          </h3>
          <p style={{ fontSize: 13.5, color: "var(--ink-2)", marginTop: 6 }}>
            Create a free profile — takes 20 seconds — to see all results, save searches, and get a daily digest.
          </p>
        </div>
        <button className="btn btn-primary">
          Unlock free <Icon name="arrow-right" size={15}/>
        </button>
      </div>
    </div>
  </div>
);

const RightRailPreview = ({ job }) => (
  <div className="card" style={{ padding: 22, position: "sticky", top: 16 }}>
    <div style={{ display: "flex", alignItems: "start", gap: 12, marginBottom: 14 }}>
      <LogoChip logo={job.logo} size={44} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 12, color: "var(--muted)" }}>{job.company} · {job.posted}</div>
        <h3 className="serif" style={{ fontSize: 20, lineHeight: 1.2, marginTop: 2 }}>{job.title}</h3>
      </div>
    </div>
    <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "8px 16px", fontSize: 12.5, marginBottom: 16 }}>
      <Meta icon="pin" label="Location" value={job.location}/>
      <Meta icon="wallet" label="Salary" value={job.salary} mono />
      <Meta icon="clock" label="Type" value="Full-time"/>
      <Meta icon="globe" label="Visa" value="Sponsored"/>
    </div>
    <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 18 }}>
      {job.tags.map(t => <span key={t} className="tag">{t}</span>)}
      <span className="tag green">Remote</span>
    </div>
    <p style={{ fontSize: 13.5, color: "var(--ink-2)", lineHeight: 1.55, marginBottom: 18 }}>
      {job.desc} You'll work alongside the protocol team to design how funds move between accounts at scale.
    </p>
    <div style={{ display: "flex", gap: 8 }}>
      <button className="btn btn-primary" style={{ flex: 1 }}>
        Apply on Stripe <Icon name="arrow-up-right" size={14}/>
      </button>
      <button className="btn btn-ghost" style={{ width: 44, padding: 0 }}>
        <Icon name="bookmark" size={16}/>
      </button>
    </div>
    <div style={{ marginTop: 16, paddingTop: 14, borderTop: "1px dashed var(--line)", fontSize: 12, color: "var(--muted)", display: "flex", justifyContent: "space-between" }}>
      <span>Sourced via Greenhouse</span>
      <span>Verified · 12m ago</span>
    </div>
  </div>
);

const Meta = ({ icon, label, value, mono }) => (
  <div>
    <div style={{ fontSize: 10.5, color: "var(--muted)", textTransform: "uppercase", letterSpacing: "0.06em", fontFamily: "var(--mono)", marginBottom: 3, display: "flex", alignItems: "center", gap: 5 }}>
      <Icon name={icon} size={11}/> {label}
    </div>
    <div className={mono ? "mono" : ""} style={{ fontSize: 13, color: mono ? "var(--green-2)" : "var(--ink)" }}>{value}</div>
  </div>
);

Object.assign(window, { DesktopLanding, DesktopSearch, FilterGroup, UnlockGate, RightRailPreview });

/* Caio — Sunrise logo system.
   "caio" set in Newsreader at natural spacing; the dot of the i
   is replaced by a sunrise: a horizon line with a half-disc above.
   It also reads as a small hat — friendly without being childish. */

// ─────────────────────────────────────────────────────────────
// The mark on its own — used for avatars / favicons / loose icon.
// Proportion: total bbox 28×28. Line at y=20, dome radius 9 → the
// dome sits cleanly inside, with breathing room on all sides.
// strokeWidth scales with `s` so the mark holds at any size.
// ─────────────────────────────────────────────────────────────
const Sunrise = ({ s = 1, line = "currentColor", dome }) => (
  <svg width={28 * s} height={28 * s} viewBox="0 0 28 28" fill="none">
    <line x1="3" y1="20" x2="25" y2="20"
          stroke={line} strokeWidth={Math.max(1.6, 2 * s)} strokeLinecap="round"/>
    <path d="M5 20 A 9 9 0 0 1 23 20 Z" fill={dome || line}/>
  </svg>
);

// ─────────────────────────────────────────────────────────────
// Wordmark.
//
// The full word "caio" is rendered as a single continuous serif
// string so kerning is exactly what Newsreader was designed for.
// Only the "i" is wrapped in a position-relative span so we can
// pin the sunrise above it; the glyph used is "ı" (dotless i)
// so the native tittle doesn't fight the hat.
//
// Critically: there is NO horizontal gap between the segments.
// Letterspacing is uniform across "c", "a", "ı", "o" exactly as
// the typeface intends. The hat scales from the font size; the
// horizon line is the same stroke weight as the i-stem reads at
// that scale, so it looks intentional rather than applied.
// ─────────────────────────────────────────────────────────────
const Wordmark = ({
  color = "var(--ink)",
  accent = "var(--green)",
  size = 80,
  mono = false,  // if true, dome takes `color` not `accent`
}) => {
  // Hat geometry — tuned against the i stem.
  // Width ~ 0.46 of cap height feels balanced (not too wide).
  // Sits ~0.30 cap heights above the baseline of the letterform.
  const hatW = size * 0.46;
  const hatH = size * 0.24;
  const hatTop = -size * 0.30;
  const stroke = Math.max(1.6, size * 0.030);

  return (
    <span
      className="serif"
      style={{
        fontSize: size,
        letterSpacing: "-0.025em",
        lineHeight: 1,
        color,
        display: "inline-block",
        whiteSpace: "nowrap",
      }}
    >
      ca<span style={{ position: "relative", display: "inline-block" }}>ı<svg
        width={hatW}
        height={hatH}
        viewBox="0 0 46 24"
        style={{
          position: "absolute",
          left: "50%",
          top: hatTop,
          transform: "translateX(-50%)",
          overflow: "visible",
        }}
        fill="none"
      >
        <line
          x1="2.5" y1="20" x2="43.5" y2="20"
          stroke={color}
          strokeWidth={stroke * (24 / hatH)}
          strokeLinecap="round"
          vectorEffect="non-scaling-stroke"
        />
        <path d="M7 20 A 16 16 0 0 1 39 20 Z" fill={mono ? color : accent}/>
      </svg></span>o
    </span>
  );
};

// ─────────────────────────────────────────────────────────────
// Helper tiles — used by the logo sheet.
// ─────────────────────────────────────────────────────────────
const Swatch = ({ bg, fg, accent, mono, w = 280, h = 140, label }) => (
  <div style={{
    width: w, height: h, borderRadius: 14, background: bg,
    border: "1px solid var(--line)",
    display: "flex", alignItems: "center", justifyContent: "center",
    position: "relative",
  }}>
    <Wordmark color={fg} accent={accent} size={56} mono={mono}/>
    {label && (
      <div className="mono" style={{
        position: "absolute", left: 12, bottom: 10,
        fontSize: 10, letterSpacing: "0.08em", textTransform: "uppercase",
        color: "var(--muted)",
      }}>{label}</div>
    )}
  </div>
);

const Tile = ({ bg, fg, dome, label, size = 96 }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 8, alignItems: "flex-start" }}>
    <div style={{
      width: size, height: size, borderRadius: 20, background: bg,
      border: "1px solid var(--line)",
      display: "flex", alignItems: "center", justifyContent: "center",
      color: fg,
    }}>
      <Sunrise s={size / 28 * 0.6} line={fg} dome={dome}/>
    </div>
    {label && <div className="mono" style={{ fontSize: 10, letterSpacing: "0.06em", color: "var(--muted)", textTransform: "uppercase" }}>{label}</div>}
  </div>
);

const Favicon = ({ px, bg, fg, dome }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 6, alignItems: "center" }}>
    <div style={{
      width: px, height: px, borderRadius: px * 0.22, background: bg,
      border: "1px solid var(--line)",
      display: "flex", alignItems: "center", justifyContent: "center",
    }}>
      <Sunrise s={px / 28 * 0.62} line={fg} dome={dome}/>
    </div>
    <div className="mono" style={{ fontSize: 10, color: "var(--muted)" }}>{px}</div>
  </div>
);

// ─────────────────────────────────────────────────────────────
// LogoSheet — full presentation of the chosen direction.
// One artboard, sectioned: hero · scale ladder · color · mark ·
// favicon · in-context preview.
// ─────────────────────────────────────────────────────────────
const LogoSheet = () => (
  <div className="caio" style={{
    width: 1280, padding: 56, background: "var(--bg)",
    display: "flex", flexDirection: "column", gap: 48,
  }}>
    {/* Header strip */}
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
      <div>
        <div className="mono" style={{ fontSize: 11, letterSpacing: "0.10em", color: "var(--muted)", textTransform: "uppercase", marginBottom: 8 }}>
          Caio · Identity sheet · v1
        </div>
        <h1 className="serif" style={{ fontSize: 46, letterSpacing: "-0.02em", lineHeight: 1.1 }}>
          Sunrise<span className="serif-italic" style={{ color: "var(--green)" }}>.</span>
        </h1>
        <p style={{ marginTop: 10, fontSize: 14.5, color: "var(--ink-2)", maxWidth: 520, lineHeight: 1.55 }}>
          A horizon line with a half-disc rising above it stands in for the tittle of
          the "i". It reads as a sunrise, an arrow climbing, the head of a place pin —
          and, looked at sideways, a small hat.
        </p>
      </div>
      <div style={{ textAlign: "right", fontSize: 12, color: "var(--muted)", lineHeight: 1.7 }}>
        <div>Wordmark · Newsreader · 500</div>
        <div>Tracking · −2.5%</div>
        <div>Hat · 0.46× cap height</div>
        <div>Stroke · 0.030× size</div>
      </div>
    </div>

    {/* Hero */}
    <div style={{
      background: "var(--paper-2)", border: "1px solid var(--line)",
      borderRadius: 22, padding: "80px 40px",
      display: "flex", alignItems: "center", justifyContent: "center",
      position: "relative", overflow: "hidden",
    }}>
      {/* faint baseline */}
      <div style={{ position: "absolute", left: 40, right: 40, top: "calc(50% + 70px)", borderTop: "1px dashed var(--line)" }}/>
      <Wordmark size={200}/>
      <div className="mono" style={{ position: "absolute", left: 20, top: 16, fontSize: 10, letterSpacing: "0.06em", color: "var(--muted)" }}>PRIMARY · INK ON CREAM</div>
    </div>

    {/* Scale ladder */}
    <section>
      <SectionLabel>Scale · The mark holds from billboard to favicon</SectionLabel>
      <div className="card" style={{
        padding: "40px 32px", background: "var(--paper-2)",
        display: "flex", alignItems: "baseline", justifyContent: "space-between",
        gap: 24, flexWrap: "wrap",
      }}>
        {[136, 96, 64, 40, 24, 16].map(s => (
          <div key={s} style={{ display: "flex", flexDirection: "column", gap: 14, alignItems: "flex-start" }}>
            <Wordmark size={s}/>
            <div className="mono" style={{ fontSize: 10, color: "var(--muted)" }}>{s}px</div>
          </div>
        ))}
      </div>
    </section>

    {/* Color variations */}
    <section>
      <SectionLabel>Color · Four sanctioned colorways</SectionLabel>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 14 }}>
        <Swatch bg="var(--paper-2)" fg="var(--ink)" accent="var(--green)" label="01 · Primary" w="100%"/>
        <Swatch bg="var(--bg-2)"    fg="var(--ink)" accent="var(--green)" label="02 · On warm" w="100%"/>
        <Swatch bg="var(--green)"   fg="#FBF9F3"    accent="#FBF9F3"      mono label="03 · On brand" w="100%"/>
        <Swatch bg="#14201B"        fg="#ECE6D8"    accent="#4FCDA8"      label="04 · On dark"  w="100%"/>
      </div>
    </section>

    {/* Mark alone + favicons */}
    <section>
      <div style={{ display: "grid", gridTemplateColumns: "1.4fr 1fr", gap: 24 }}>
        <div>
          <SectionLabel>Mark · As an app icon</SectionLabel>
          <div className="card" style={{ padding: 32, background: "var(--paper-2)", display: "flex", gap: 24, alignItems: "flex-end" }}>
            <Tile bg="var(--bg-2)"  fg="var(--ink)" dome="var(--green)" label="Light"/>
            <Tile bg="var(--green)" fg="#FBF9F3"    dome="#FBF9F3"      label="Brand"/>
            <Tile bg="#14201B"      fg="#ECE6D8"    dome="#4FCDA8"      label="Dark"/>
            <Tile bg="var(--ink)"   fg="#FBF9F3"    dome="#FBF9F3"      label="Mono"/>
          </div>
        </div>
        <div>
          <SectionLabel>Favicon · Holds to 16px</SectionLabel>
          <div className="card" style={{ padding: 32, background: "var(--paper-2)", display: "flex", gap: 22, alignItems: "flex-end", justifyContent: "center", height: "calc(100% - 28px)" }}>
            <Favicon px={64} bg="var(--bg-2)" fg="var(--ink)" dome="var(--green)"/>
            <Favicon px={48} bg="var(--bg-2)" fg="var(--ink)" dome="var(--green)"/>
            <Favicon px={32} bg="var(--bg-2)" fg="var(--ink)" dome="var(--green)"/>
            <Favicon px={16} bg="var(--bg-2)" fg="var(--ink)" dome="var(--green)"/>
          </div>
        </div>
      </div>
    </section>

    {/* In context */}
    <section>
      <SectionLabel>In context · How it shows up</SectionLabel>
      <div style={{ display: "grid", gridTemplateColumns: "1.4fr 1fr", gap: 14 }}>
        {/* Browser tab mockup */}
        <div className="card" style={{ padding: 0, overflow: "hidden", background: "var(--paper-2)" }}>
          <div style={{ background: "var(--bg-2)", padding: "10px 14px", display: "flex", gap: 10, alignItems: "center", borderBottom: "1px solid var(--line)" }}>
            <div style={{ display: "flex", gap: 6 }}>
              {["#E16259", "#E8B73E", "#3DCB6A"].map(c => <span key={c} style={{ width: 11, height: 11, borderRadius: 999, background: c }}/>)}
            </div>
            <div style={{
              flex: 1, marginLeft: 8, padding: "6px 12px",
              background: "var(--paper-2)", border: "1px solid var(--line)", borderRadius: 8,
              display: "flex", alignItems: "center", gap: 8, fontSize: 12, color: "var(--ink-2)",
            }}>
              <div style={{ width: 14, height: 14, borderRadius: 3, background: "var(--bg-2)", display: "flex", alignItems: "center", justifyContent: "center" }}>
                <Sunrise s={0.42} line="var(--ink)" dome="var(--green)"/>
              </div>
              <span className="mono">caio.work</span>
              <span style={{ color: "var(--muted)" }}>— Senior Backend Engineer, Stripe</span>
            </div>
          </div>
          <div style={{ padding: "26px 28px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <Wordmark size={28}/>
            <div style={{ display: "flex", gap: 22, fontSize: 13, color: "var(--ink-2)" }}>
              <span>Jobs</span><span>Companies</span><span>Salaries</span>
              <span style={{ color: "var(--green-2)" }}>● 435,343 live</span>
            </div>
          </div>
        </div>

        {/* Phone home screen tile */}
        <div className="card" style={{
          padding: 0, overflow: "hidden",
          background: "linear-gradient(160deg, #2E5A48 0%, #14201B 100%)",
          display: "flex", alignItems: "center", justifyContent: "center", padding: 28,
        }}>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
            <div style={{
              width: 96, height: 96, borderRadius: 22, background: "var(--bg-2)",
              display: "flex", alignItems: "center", justifyContent: "center",
              boxShadow: "0 8px 24px -8px rgba(0,0,0,0.35), 0 0 0 1px rgba(255,255,255,0.05) inset",
            }}>
              <Sunrise s={2.1} line="var(--ink)" dome="var(--green)"/>
            </div>
            <div style={{ fontSize: 12, color: "rgba(255,255,255,0.85)", letterSpacing: "0.01em" }}>Caio</div>
          </div>
        </div>
      </div>
    </section>

    {/* Footer note */}
    <div style={{
      paddingTop: 28, borderTop: "1px dashed var(--line)",
      display: "flex", justifyContent: "space-between", alignItems: "center",
      fontSize: 12, color: "var(--muted)",
    }}>
      <span className="mono">caio.work · identity · 2026</span>
      <span>One mark. Newsreader 500. Trust green. Cream warmth.</span>
    </div>
  </div>
);

const SectionLabel = ({ children }) => (
  <div className="mono" style={{
    fontSize: 11, letterSpacing: "0.10em", color: "var(--muted)",
    textTransform: "uppercase", marginBottom: 14,
  }}>── {children}</div>
);

Object.assign(window, { Sunrise, Wordmark, LogoSheet });

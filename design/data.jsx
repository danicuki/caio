/* Caio — mock job data and shared atoms */

// ─────────────────────────────────────────────────────────────
// Job index — realistic-feeling tech roles
// ─────────────────────────────────────────────────────────────
const JOBS = [
  {
    id: "j-001",
    title: "Senior Backend Engineer, Payments",
    company: "Stripe",
    logo: { mono: "S", bg: "#635BFF" },
    location: "Remote · EU",
    salary: "€140k – €185k",
    type: "Full-time",
    posted: "2h ago",
    tags: ["Go", "Distributed Systems", "Postgres"],
    remote: true,
    visa: true,
    desc: "Build the core payment routing layer that processes billions of transactions, with a focus on latency, observability, and graceful failure modes.",
  },
  {
    id: "j-002",
    title: "Staff Product Designer",
    company: "Linear",
    logo: { mono: "L", bg: "#5E6AD2" },
    location: "Remote · Global",
    salary: "$190k – $240k",
    type: "Full-time",
    posted: "5h ago",
    tags: ["Product", "Systems", "Prototyping"],
    remote: true,
    visa: false,
    desc: "Shape the next generation of issue tracking. Own end-to-end design from research through ship.",
  },
  {
    id: "j-003",
    title: "Senior DevOps Engineer",
    company: "Vercel",
    logo: { mono: "▲", bg: "#000000" },
    location: "Remote · Americas",
    salary: "$180k – $230k",
    type: "Full-time",
    posted: "1d ago",
    tags: ["Kubernetes", "Terraform", "AWS"],
    remote: true,
    visa: true,
  },
  {
    id: "j-004",
    title: "Data Engineer, Growth",
    company: "Notion",
    logo: { mono: "N", bg: "#111" },
    location: "San Francisco, CA",
    salary: "$170k – $210k",
    type: "Full-time",
    posted: "1d ago",
    tags: ["dbt", "Snowflake", "Python"],
    remote: false,
    visa: true,
  },
  {
    id: "j-005",
    title: "ML Research Engineer",
    company: "Anthropic",
    logo: { mono: "A", bg: "#C77B5C" },
    location: "Remote · US/UK",
    salary: "$280k – $390k",
    type: "Full-time",
    posted: "3h ago",
    tags: ["PyTorch", "Distributed Training", "Evals"],
    remote: true,
    visa: true,
  },
  {
    id: "j-006",
    title: "Senior Frontend Engineer",
    company: "Figma",
    logo: { mono: "F", bg: "#0ACF83" },
    location: "New York, NY",
    salary: "$200k – $250k",
    type: "Full-time",
    posted: "6h ago",
    tags: ["TypeScript", "WebGL", "React"],
    remote: false,
    visa: true,
  },
  {
    id: "j-007",
    title: "Site Reliability Engineer",
    company: "Cloudflare",
    logo: { mono: "☁", bg: "#F38020" },
    location: "Lisbon, Portugal",
    salary: "€110k – €145k",
    type: "Full-time",
    posted: "2d ago",
    tags: ["SRE", "Rust", "Edge"],
    remote: false,
    visa: true,
  },
  {
    id: "j-008",
    title: "iOS Engineer",
    company: "Arc",
    logo: { mono: "◐", bg: "#FF6B6B" },
    location: "Remote · US",
    salary: "$170k – $215k",
    type: "Full-time",
    posted: "9h ago",
    tags: ["Swift", "SwiftUI", "Performance"],
    remote: true,
    visa: false,
  },
  {
    id: "j-009",
    title: "Founding Engineer",
    company: "Glide Robotics",
    logo: { mono: "G", bg: "#0E5C49" },
    location: "Berlin, Germany",
    salary: "€120k + equity",
    type: "Full-time",
    posted: "11h ago",
    tags: ["Rust", "Embedded", "Computer Vision"],
    remote: false,
    visa: true,
  },
  {
    id: "j-010",
    title: "Senior Platform Engineer",
    company: "Supabase",
    logo: { mono: "≋", bg: "#3ECF8E" },
    location: "Remote · Global",
    salary: "$160k – $210k",
    type: "Full-time",
    posted: "14h ago",
    tags: ["Postgres", "Go", "Open Source"],
    remote: true,
    visa: false,
  },
  // locked / preview-only
  {
    id: "j-011",
    title: "Senior Security Engineer, AppSec",
    company: "Ramp",
    logo: { mono: "R", bg: "#F1E9D7" },
    location: "Remote · US",
    salary: "$210k – $260k",
    type: "Full-time",
    posted: "1d ago",
    tags: ["AppSec", "Python", "Threat Modeling"],
    remote: true,
    visa: true,
    locked: true,
  },
  {
    id: "j-012",
    title: "Staff Engineer, Infra",
    company: "Discord",
    logo: { mono: "D", bg: "#5865F2" },
    location: "Remote · Americas",
    salary: "$250k – $320k",
    type: "Full-time",
    posted: "1d ago",
    tags: ["Elixir", "Rust", "Scale"],
    remote: true,
    visa: true,
    locked: true,
  },
  {
    id: "j-013",
    title: "Design Engineer",
    company: "Vercel",
    logo: { mono: "▲", bg: "#000000" },
    location: "Remote · EU",
    salary: "€100k – €140k",
    type: "Full-time",
    posted: "2d ago",
    tags: ["React", "Motion", "Tokens"],
    remote: true,
    visa: false,
    locked: true,
  },
];

// Detail-page job (extended)
const DETAIL_JOB = {
  ...JOBS[0],
  team: "Money Movement",
  employees: "8,000+",
  founded: 2010,
  funding: "Public (private)",
  applyUrl: "stripe.com/jobs/...",
  similar: [JOBS[2], JOBS[6], JOBS[9]],
};

// ─────────────────────────────────────────────────────────────
// Small SVG icons (line, 1.5px, currentColor)
// ─────────────────────────────────────────────────────────────
const Icon = ({ name, size = 16, stroke = 1.5, style }) => {
  const s = { width: size, height: size, fill: "none", stroke: "currentColor", strokeWidth: stroke, strokeLinecap: "round", strokeLinejoin: "round", ...style };
  switch (name) {
    case "search": return <svg viewBox="0 0 24 24" style={s}><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>;
    case "pin": return <svg viewBox="0 0 24 24" style={s}><path d="M12 21s-7-7.5-7-12a7 7 0 1114 0c0 4.5-7 12-7 12z"/><circle cx="12" cy="9" r="2.5"/></svg>;
    case "globe": return <svg viewBox="0 0 24 24" style={s}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.5 3 14 0 18M12 3c-3 3.5-3 14 0 18"/></svg>;
    case "clock": return <svg viewBox="0 0 24 24" style={s}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>;
    case "wallet": return <svg viewBox="0 0 24 24" style={s}><rect x="3" y="6" width="18" height="14" rx="2"/><path d="M16 13h2M3 10h18"/></svg>;
    case "bookmark": return <svg viewBox="0 0 24 24" style={s}><path d="M6 4h12v17l-6-4-6 4V4z"/></svg>;
    case "filter": return <svg viewBox="0 0 24 24" style={s}><path d="M4 5h16M7 12h10M10 19h4"/></svg>;
    case "arrow-right": return <svg viewBox="0 0 24 24" style={s}><path d="M5 12h14M13 6l6 6-6 6"/></svg>;
    case "arrow-up-right": return <svg viewBox="0 0 24 24" style={s}><path d="M7 17L17 7M9 7h8v8"/></svg>;
    case "lock": return <svg viewBox="0 0 24 24" style={s}><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>;
    case "mail": return <svg viewBox="0 0 24 24" style={s}><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 7 9-7"/></svg>;
    case "bolt": return <svg viewBox="0 0 24 24" style={s}><path d="M13 2L4 14h7l-1 8 9-12h-7l1-8z"/></svg>;
    case "check": return <svg viewBox="0 0 24 24" style={s}><path d="M5 12l4 4 10-10"/></svg>;
    case "menu": return <svg viewBox="0 0 24 24" style={s}><path d="M4 7h16M4 12h16M4 17h16"/></svg>;
    case "chev-down": return <svg viewBox="0 0 24 24" style={s}><path d="M6 9l6 6 6-6"/></svg>;
    case "x": return <svg viewBox="0 0 24 24" style={s}><path d="M6 6l12 12M18 6L6 18"/></svg>;
    case "sliders": return <svg viewBox="0 0 24 24" style={s}><path d="M4 6h10M4 12h6M4 18h14"/><circle cx="17" cy="6" r="2"/><circle cx="13" cy="12" r="2"/><circle cx="19" cy="18" r="2"/></svg>;
    case "building": return <svg viewBox="0 0 24 24" style={s}><path d="M4 21V5l8-2v18M12 21V9l8 2v10M4 21h16M8 8h0M8 12h0M8 16h0M16 14h0M16 18h0"/></svg>;
    case "users": return <svg viewBox="0 0 24 24" style={s}><circle cx="9" cy="8" r="3"/><path d="M3 20c0-3 3-5 6-5s6 2 6 5"/><circle cx="17" cy="9" r="2.5"/><path d="M16 20c0-2 2-4 5-4"/></svg>;
    case "spark": return <svg viewBox="0 0 24 24" style={s}><path d="M12 3v6M12 15v6M3 12h6M15 12h6M6 6l4 4M14 14l4 4M18 6l-4 4M10 14l-4 4"/></svg>;
    default: return null;
  }
};

// ─────────────────────────────────────────────────────────────
// Company logo chip — letterform on tinted square
// ─────────────────────────────────────────────────────────────
const LogoChip = ({ logo, size = 40, radius = 10 }) => (
  <div style={{
    width: size, height: size, borderRadius: radius,
    background: logo.bg, color: "#fff",
    display: "flex", alignItems: "center", justifyContent: "center",
    fontFamily: "var(--serif)", fontWeight: 500, fontSize: size * 0.5,
    flexShrink: 0,
    boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.06), 0 1px 2px rgba(0,0,0,0.06)",
  }}>{logo.mono}</div>
);

// ─────────────────────────────────────────────────────────────
// Logo wordmark
// ─────────────────────────────────────────────────────────────
const Wordmark = ({ size = 22 }) => (
  <div className="logo-mark" style={{ fontSize: size }}>
    <span className="logo-dot" style={{ width: size, height: size }} />
    <span>caio</span>
  </div>
);

// Big formatted jobs counter (with thin space separators)
const fmtCount = (n) => n.toLocaleString("en-US").replace(/,/g, ",");

Object.assign(window, { JOBS, DETAIL_JOB, Icon, LogoChip, Wordmark, fmtCount });

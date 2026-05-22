/* global React, useTweaks, TweaksPanel, TweakSection, DesignCanvas, DCSection, DCArtboard */
const { useState } = React;

const ink = "#fefae0";
const paper = "#283618";
const sticky = "#dda15e";
const muted = "#a8a08a";
const tile = "#fefae0";
const searchBg = "#fefae0";

const wfBox = (extra = {}) => ({
  border: `1px solid ${ink}`,
  background: "transparent",
  boxSizing: "border-box",
  borderRadius: 10,
  ...extra,
});

const Hand = ({ children, size = 18, style = {} }) => (
  <span style={{ fontFamily: "'Caveat', cursive", fontSize: size, color: ink, lineHeight: 1.1, ...style }}>{children}</span>
);

const Mono = ({ children, size = 11, style = {} }) => (
  <span style={{ fontFamily: "'JetBrains Mono', ui-monospace, monospace", fontSize: size, color: ink, letterSpacing: 0.2, ...style }}>{children}</span>
);

const SearchBar = ({ height = 44, label = "search shops, services, hotels…" }) => (
  <div style={{ ...wfBox({ background: searchBg, border: `1px solid ${searchBg}` }), height, borderRadius: height / 2, display: "flex", alignItems: "center", padding: "0 18px", gap: 12 }}>
    <div style={{ border: `1px solid #283618`, width: 14, height: 14, borderRadius: "50%" }} />
    <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 11, color: "#283618", flex: 1 }}>{label}</span>
    <div style={{ border: `1px solid #283618`, padding: "3px 8px", borderRadius: 10 }}><span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: "#283618" }}>⌘K</span></div>
  </div>
);

/* ══════════════════════════════════════════════
   SCREEN 1 — Home page
══════════════════════════════════════════════ */
const Screen1_Home = () => {
  const cats = [
    { id: "shops",   label: "Shops",            icon: "🛍",  to: "→ 02" },
    { id: "service", label: "Services",          icon: "🔧",  to: "→ 03" },
    { id: "theater", label: "Theaters",          icon: "🎭",  to: "→ 04" },
    { id: "hotels",  label: "Hotels",            icon: "🏨",  to: "→ 05" },
    { id: "resto",   label: "Restaurants",       icon: "🍽",  to: "→ 06" },
    { id: "beauty",  label: "Beauty & Wellness", icon: "💆",  to: "→ 07" },
  ];

  return (
    <div style={{ width: 390, height: 844, background: paper, display: "flex", flexDirection: "column", overflow: "hidden", fontFamily: "'JetBrains Mono', monospace" }}>
      {/* top bar */}
      <div style={{ borderBottom: `1px solid ${ink}`, padding: "12px 14px", display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
        <div style={{ ...wfBox(), width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Mono size={12}>≡</Mono>
        </div>
        <Hand size={22}>onkerala</Hand>
        <div style={{ ...wfBox(), padding: "4px 10px", borderRadius: 12, cursor: "pointer" }}>
          <Mono size={10}>login</Mono>
        </div>
      </div>

      {/* search */}
      <div style={{ padding: "12px 14px", borderBottom: `1px solid ${ink}`, flexShrink: 0 }}>
        <SearchBar height={38} />
      </div>

      {/* body */}
      <div style={{ flex: 1, overflowY: "auto", padding: 16, display: "flex", flexDirection: "column", backgroundImage: "linear-gradient(rgba(40, 54, 24, 0.55), rgba(40, 54, 24, 0.55)), url('assets/kerala-bg.png')", backgroundSize: "cover", backgroundPosition: "center" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16 }}>
          <Hand size={22}>What are you looking for?</Hand>
          <div style={{ ...wfBox(), padding: "6px 12px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer", borderRadius: 20 }}>
            <Mono size={10}>📍</Mono>
            <Mono size={10}>near me</Mono>
          </div>
        </div>

        {/* category grid — fills available height */}
        <div style={{ flex: 1, display: "grid", gridTemplateColumns: "1fr 1fr", gridTemplateRows: "1fr 1fr 1fr", gap: 12 }}>
          {cats.map((cat) => (
            <div key={cat.id} style={{ background: tile, border: `1px solid ${tile}`, borderRadius: 16, padding: 20, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8, cursor: "pointer", position: "relative" }}>
              <div style={{ fontSize: 30 }}>{cat.icon}</div>
              <span style={{ fontFamily: "'Caveat', cursive", fontSize: 15, color: "#283618", textAlign: "center", lineHeight: 1.1 }}>{cat.label}</span>
              <span style={{ position: "absolute", top: 8, right: 10, fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: "#283618", opacity: 0.6 }}>{cat.to}</span>
            </div>
          ))}
        </div>
      </div>

      {/* bottom nav */}
      <div style={{ borderTop: `1px solid ${ink}`, padding: "10px 14px", display: "flex", justifyContent: "space-around", flexShrink: 0 }}>
        <Mono size={10}>home</Mono>
        <Mono size={10} style={{ color: muted }}>search</Mono>
        <Mono size={10} style={{ color: muted }}>saved</Mono>
        <Mono size={10} style={{ color: muted }}>me</Mono>
      </div>
    </div>
  );
};

/* ══════════════════════════════
   SCREEN 2 — Shops search
══════════════════════════════ */
const Screen2_Shops = () => {
  const [openFilter, setOpenFilter] = useState(null);
  const [sel, setSel] = useState({ district: ["Kochi"], category: ["Textiles"], rating: [], price: [], open: false });

  const filters = {
    district:  ["Trivandrum", "Kollam", "Pathanamthitta", "Alappuzha", "Kottayam", "Idukki", "Ernakulam", "Kochi", "Thrissur", "Palakkad", "Malappuram", "Kozhikode", "Wayanad", "Kannur", "Kasaragod"],
    category:  ["Textiles", "Spices", "Jewelry", "Food & Snacks", "Crafts", "Electronics", "Books", "Ayurveda"],
    rating:    ["4.5+ stars", "4.0+ stars", "3.5+ stars", "any rating"],
    price:     ["₹", "₹₹", "₹₹₹", "₹₹₹₹"],
  };

  const toggle = (group, item) => {
    setSel((s) => {
      const cur = s[group] || [];
      return { ...s, [group]: cur.includes(item) ? cur.filter((x) => x !== item) : [...cur, item] };
    });
  };

  const activeChips = [
    ...sel.district.map((d) => ({ group: "district", label: d })),
    ...sel.category.map((c) => ({ group: "category", label: c })),
    ...sel.rating.map((r) => ({ group: "rating", label: r })),
    ...sel.price.map((p) => ({ group: "price", label: p })),
  ];

  const shops = [
    { name: "Seemati Silks", cat: "Textiles", rating: 4.6, reviews: 312, tags: ["Kochi", "₹₹₹"] },
    { name: "Spice Route Co.", cat: "Spices", rating: 4.8, reviews: 524, tags: ["Kochi", "₹₹"] },
    { name: "Alukkas Jewellery", cat: "Jewelry", rating: 4.4, reviews: 198, tags: ["Kochi", "₹₹₹₹"] },
    { name: "Kalyan Sarees", cat: "Textiles", rating: 4.5, reviews: 267, tags: ["Kochi", "₹₹₹"] },
    { name: "Cochin Bazaar", cat: "Crafts", rating: 4.2, reviews: 89, tags: ["Kochi", "₹₹"] },
    { name: "Highrange Books", cat: "Books", rating: 4.7, reviews: 142, tags: ["Kochi", "₹₹"] },
  ];

  return (
    <div style={{ width: 390, height: 844, background: paper, display: "flex", flexDirection: "column", overflow: "hidden", fontFamily: "'JetBrains Mono', monospace", position: "relative" }}>
      {/* top bar */}
      <div style={{ borderBottom: `1px solid ${ink}`, padding: "12px 14px", display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
        <div style={{ ...wfBox(), width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Mono size={12}>←</Mono>
        </div>
        <Hand size={22}>Shops</Hand>
        <div style={{ ...wfBox(), padding: "4px 10px", borderRadius: 12, cursor: "pointer" }}>
          <Mono size={10}>login</Mono>
        </div>
      </div>

      {/* search */}
      <div style={{ padding: "12px 14px", flexShrink: 0 }}>
        <SearchBar height={38} label="search shops…" />
      </div>

      {/* filter pills */}
      <div style={{ padding: "0 14px 10px", display: "flex", gap: 8, overflowX: "auto", flexShrink: 0 }}>
        {[
          { id: "district", label: "District" },
          { id: "category", label: "Category" },
          { id: "rating", label: "Rating" },
          { id: "price", label: "Price" },
          { id: "open", label: "Open now" },
        ].map((f) => {
          const active = f.id === "open" ? sel.open : (sel[f.id] || []).length > 0;
          return (
            <div key={f.id}
              onClick={() => f.id === "open" ? setSel({ ...sel, open: !sel.open }) : setOpenFilter(openFilter === f.id ? null : f.id)}
              style={{ ...wfBox({ background: active ? sticky : "transparent", border: `1px solid ${active ? sticky : ink}`, borderRadius: 16, padding: "6px 12px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer", flexShrink: 0 }) }}>
              <Mono size={10} style={{ color: active ? paper : ink }}>{f.label}</Mono>
              {f.id !== "open" && <Mono size={9} style={{ color: active ? paper : ink }}>{openFilter === f.id ? "▴" : "▾"}</Mono>}
            </div>
          );
        })}
      </div>

      {/* active chips */}
      {activeChips.length > 0 && (
        <div style={{ padding: "0 14px 10px", display: "flex", gap: 6, flexWrap: "wrap", flexShrink: 0 }}>
          {activeChips.map((c, i) => (
            <div key={i} onClick={() => toggle(c.group, c.label)} style={{ ...wfBox({ background: tile, border: `1px solid ${tile}`, borderRadius: 12, padding: "4px 10px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }) }}>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>{c.label}</span>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>×</span>
            </div>
          ))}
          <div onClick={() => setSel({ district: [], category: [], rating: [], price: [], open: false })} style={{ padding: "4px 10px", cursor: "pointer" }}>
            <Mono size={10} style={{ color: muted }}>clear all</Mono>
          </div>
        </div>
      )}

      {/* result header */}
      <div style={{ padding: "6px 14px 8px", display: "flex", justifyContent: "space-between", alignItems: "center", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>{shops.length} shops · sorted by rating</Mono>
        <Mono size={10}>sort ▾</Mono>
      </div>

      {/* shop grid */}
      <div style={{ flex: 1, overflowY: "auto", padding: "4px 14px 14px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {shops.map((s, i) => (
            <div key={i} style={{ background: tile, borderRadius: 14, overflow: "hidden", display: "flex", flexDirection: "column", cursor: "pointer" }}>
              <div style={{ aspectRatio: "1 / 1", background: "#a8a08a", borderBottom: `1px solid ${paper}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.5 }}>photo</span>
              </div>
              <div style={{ padding: "8px 10px 10px" }}>
                <span style={{ fontFamily: "'Caveat', cursive", fontSize: 17, color: paper, lineHeight: 1, display: "block" }}>{s.name}</span>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.7, display: "block", marginTop: 2 }}>{s.cat}</span>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 6 }}>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>★ {s.rating}</span>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.6 }}>({s.reviews})</span>
                </div>
                <div style={{ display: "flex", gap: 4, marginTop: 6, flexWrap: "wrap" }}>
                  {s.tags.map((t, j) => (
                    <span key={j} style={{ border: `1px solid ${paper}`, borderRadius: 8, padding: "1px 6px", fontFamily: "'JetBrains Mono', monospace", fontSize: 8, color: paper }}>{t}</span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* dropdown sheet */}
      {openFilter && openFilter !== "open" && (
        <div onClick={() => setOpenFilter(null)} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.35)", display: "flex", alignItems: "flex-end", zIndex: 5 }}>
          <div onClick={(e) => e.stopPropagation()} style={{ width: "100%", maxHeight: "70%", background: paper, borderTop: `1px solid ${ink}`, borderTopLeftRadius: 18, borderTopRightRadius: 18, padding: 18, display: "flex", flexDirection: "column", gap: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Hand size={20}>Choose {openFilter}</Hand>
              <div onClick={() => setOpenFilter(null)} style={{ cursor: "pointer" }}><Mono size={12}>×</Mono></div>
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, overflowY: "auto" }}>
              {(filters[openFilter] || []).map((it) => {
                const isOn = (sel[openFilter] || []).includes(it);
                return (
                  <div key={it} onClick={() => toggle(openFilter, it)} style={{ ...wfBox({ background: isOn ? sticky : "transparent", border: `1px solid ${isOn ? sticky : ink}`, borderRadius: 14, padding: "6px 12px", cursor: "pointer" }) }}>
                    <Mono size={11} style={{ color: isOn ? paper : ink }}>{it}</Mono>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* bottom nav */}
      <div style={{ borderTop: `1px solid ${ink}`, padding: "10px 14px", display: "flex", justifyContent: "space-around", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>home</Mono>
        <Mono size={10}>search</Mono>
        <Mono size={10} style={{ color: muted }}>saved</Mono>
        <Mono size={10} style={{ color: muted }}>me</Mono>
      </div>
    </div>
  );
};

/* ══════════════════════════════════════════════
   SCREEN 3 — Services search
══════════════════════════════════════════════ */
const Screen3_Services = () => {
  const [openFilter, setOpenFilter] = useState(null);
  const [sel, setSel] = useState({ district: ["Kochi"], type: ["Plumbing"], rating: [], verified: false });

  const filters = {
    district:  ["Trivandrum", "Kollam", "Pathanamthitta", "Alappuzha", "Kottayam", "Idukki", "Ernakulam", "Kochi", "Thrissur", "Palakkad", "Malappuram", "Kozhikode", "Wayanad", "Kannur", "Kasaragod"],
    type:      ["Plumbing", "Electrical", "Carpentry", "Painting", "Cleaning", "AC Repair", "Appliance Repair", "Pest Control", "Moving"],
    rating:    ["4.5+ stars", "4.0+ stars", "3.5+ stars", "any rating"],
  };

  const toggle = (group, item) => {
    setSel((s) => {
      const cur = s[group] || [];
      return { ...s, [group]: cur.includes(item) ? cur.filter((x) => x !== item) : [...cur, item] };
    });
  };

  const activeChips = [
    ...sel.district.map((d) => ({ group: "district", label: d })),
    ...sel.type.map((c) => ({ group: "type", label: c })),
    ...sel.rating.map((r) => ({ group: "rating", label: r })),
  ];

  const services = [
    { name: "Rapid Plumbing", cat: "Plumbing", rating: 4.8, reviews: 421, tags: ["Kochi", "Verified"] },
    { name: "Bright Spark Electricians", cat: "Electrical", rating: 4.7, reviews: 356, tags: ["Kochi", "Verified"] },
    { name: "Classic Carpentry", cat: "Carpentry", rating: 4.5, reviews: 198, tags: ["Kochi"] },
    { name: "HomeCare Cleaners", cat: "Cleaning", rating: 4.6, reviews: 542, tags: ["Kochi", "Verified"] },
    { name: "CoolBreeze AC Service", cat: "AC Repair", rating: 4.4, reviews: 267, tags: ["Kochi"] },
    { name: "Fix-It-Fast Repairs", cat: "Appliance Repair", rating: 4.3, reviews: 134, tags: ["Kochi"] },
  ];

  return (
    <div style={{ width: 390, height: 844, background: paper, display: "flex", flexDirection: "column", overflow: "hidden", fontFamily: "'JetBrains Mono', monospace", position: "relative" }}>
      {/* top bar */}
      <div style={{ borderBottom: `1px solid ${ink}`, padding: "12px 14px", display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
        <div style={{ ...wfBox(), width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Mono size={12}>←</Mono>
        </div>
        <Hand size={22}>Services</Hand>
        <div style={{ ...wfBox(), padding: "4px 10px", borderRadius: 12, cursor: "pointer" }}>
          <Mono size={10}>login</Mono>
        </div>
      </div>

      {/* search */}
      <div style={{ padding: "12px 14px", flexShrink: 0 }}>
        <SearchBar height={38} label="search services…" />
      </div>

      {/* filter pills */}
      <div style={{ padding: "0 14px 10px", display: "flex", gap: 8, overflowX: "auto", flexShrink: 0 }}>
        {[
          { id: "district", label: "District" },
          { id: "type", label: "Service Type" },
          { id: "rating", label: "Rating" },
          { id: "verified", label: "Verified" },
        ].map((f) => {
          const active = f.id === "verified" ? sel.verified : (sel[f.id] || []).length > 0;
          return (
            <div key={f.id}
              onClick={() => f.id === "verified" ? setSel({ ...sel, verified: !sel.verified }) : setOpenFilter(openFilter === f.id ? null : f.id)}
              style={{ ...wfBox({ background: active ? sticky : "transparent", border: `1px solid ${active ? sticky : ink}`, borderRadius: 16, padding: "6px 12px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer", flexShrink: 0 }) }}>
              <Mono size={10} style={{ color: active ? paper : ink }}>{f.label}</Mono>
              {f.id !== "verified" && <Mono size={9} style={{ color: active ? paper : ink }}>{openFilter === f.id ? "▴" : "▾"}</Mono>}
            </div>
          );
        })}
      </div>

      {/* active chips */}
      {activeChips.length > 0 && (
        <div style={{ padding: "0 14px 10px", display: "flex", gap: 6, flexWrap: "wrap", flexShrink: 0 }}>
          {activeChips.map((c, i) => (
            <div key={i} onClick={() => toggle(c.group, c.label)} style={{ ...wfBox({ background: tile, border: `1px solid ${tile}`, borderRadius: 12, padding: "4px 10px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }) }}>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>{c.label}</span>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>×</span>
            </div>
          ))}
          <div onClick={() => setSel({ district: [], type: [], rating: [], verified: false })} style={{ padding: "4px 10px", cursor: "pointer" }}>
            <Mono size={10} style={{ color: muted }}>clear all</Mono>
          </div>
        </div>
      )}

      {/* result header */}
      <div style={{ padding: "6px 14px 8px", display: "flex", justifyContent: "space-between", alignItems: "center", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>{services.length} services · sorted by rating</Mono>
        <Mono size={10}>sort ▾</Mono>
      </div>

      {/* service grid */}
      <div style={{ flex: 1, overflowY: "auto", padding: "4px 14px 14px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {services.map((s, i) => (
            <div key={i} style={{ background: tile, borderRadius: 14, overflow: "hidden", display: "flex", flexDirection: "column", cursor: "pointer" }}>
              <div style={{ aspectRatio: "1 / 1", background: "#a8a08a", borderBottom: `1px solid ${paper}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.5 }}>photo</span>
              </div>
              <div style={{ padding: "8px 10px 10px" }}>
                <span style={{ fontFamily: "'Caveat', cursive", fontSize: 17, color: paper, lineHeight: 1, display: "block" }}>{s.name}</span>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.7, display: "block", marginTop: 2 }}>{s.cat}</span>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 6 }}>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>★ {s.rating}</span>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.6 }}>({s.reviews})</span>
                </div>
                <div style={{ display: "flex", gap: 4, marginTop: 6, flexWrap: "wrap" }}>
                  {s.tags.map((t, j) => (
                    <span key={j} style={{ border: `1px solid ${paper}`, borderRadius: 8, padding: "1px 6px", fontFamily: "'JetBrains Mono', monospace", fontSize: 8, color: paper }}>{t}</span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* dropdown sheet */}
      {openFilter && openFilter !== "verified" && (
        <div onClick={() => setOpenFilter(null)} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.35)", display: "flex", alignItems: "flex-end", zIndex: 5 }}>
          <div onClick={(e) => e.stopPropagation()} style={{ width: "100%", maxHeight: "70%", background: paper, borderTop: `1px solid ${ink}`, borderTopLeftRadius: 18, borderTopRightRadius: 18, padding: 18, display: "flex", flexDirection: "column", gap: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Hand size={20}>Choose {openFilter}</Hand>
              <div onClick={() => setOpenFilter(null)} style={{ cursor: "pointer" }}><Mono size={12}>×</Mono></div>
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, overflowY: "auto" }}>
              {(filters[openFilter] || []).map((it) => {
                const isOn = (sel[openFilter] || []).includes(it);
                return (
                  <div key={it} onClick={() => toggle(openFilter, it)} style={{ ...wfBox({ background: isOn ? sticky : "transparent", border: `1px solid ${isOn ? sticky : ink}`, borderRadius: 14, padding: "6px 12px", cursor: "pointer" }) }}>
                    <Mono size={11} style={{ color: isOn ? paper : ink }}>{it}</Mono>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* bottom nav */}
      <div style={{ borderTop: `1px solid ${ink}`, padding: "10px 14px", display: "flex", justifyContent: "space-around", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>home</Mono>
        <Mono size={10}>search</Mono>
        <Mono size={10} style={{ color: muted }}>saved</Mono>
        <Mono size={10} style={{ color: muted }}>me</Mono>
      </div>
    </div>
  );
};

/* ══════════════════════════════════════════════
   SCREEN 4 — Theaters search
══════════════════════════════════════════════ */
const Screen4_Theaters = () => {
  const [openFilter, setOpenFilter] = useState(null);
  const [sel, setSel] = useState({ district: ["Kochi"], type: [], showtime: [], language: [] });

  const filters = {
    district:  ["Trivandrum", "Kollam", "Pathanamthitta", "Alappuzha", "Kottayam", "Idukki", "Ernakulam", "Kochi", "Thrissur", "Palakkad", "Malappuram", "Kozhikode", "Wayanad", "Kannur", "Kasaragod"],
    type:      ["Multiplex", "Single Screen", "IMAX", "4DX", "Drive-in"],
    showtime:  ["Morning (6-12)", "Afternoon (12-6)", "Evening (6-9)", "Night (9+)"],
    language:  ["Malayalam", "Tamil", "Hindi", "English", "Telugu", "Kannada"],
  };

  const toggle = (group, item) => {
    setSel((s) => {
      const cur = s[group] || [];
      return { ...s, [group]: cur.includes(item) ? cur.filter((x) => x !== item) : [...cur, item] };
    });
  };

  const activeChips = [
    ...sel.district.map((d) => ({ group: "district", label: d })),
    ...sel.type.map((c) => ({ group: "type", label: c })),
    ...sel.showtime.map((r) => ({ group: "showtime", label: r })),
    ...sel.language.map((r) => ({ group: "language", label: r })),
  ];

  const theaters = [
    { name: "PVR Lulu", cat: "Multiplex", screens: 7, tags: ["Kochi", "IMAX"] },
    { name: "Cinépolis Centre Square", cat: "Multiplex", screens: 5, tags: ["Kochi", "4DX"] },
    { name: "Kavitha Theatre", cat: "Single Screen", screens: 1, tags: ["Kochi"] },
    { name: "Shenoys Kalabhavan", cat: "Single Screen", screens: 1, tags: ["Kochi"] },
    { name: "Aries Plex", cat: "Multiplex", screens: 4, tags: ["Kochi"] },
    { name: "Casino Theatre", cat: "Single Screen", screens: 1, tags: ["Kochi"] },
  ];

  return (
    <div style={{ width: 390, height: 844, background: paper, display: "flex", flexDirection: "column", overflow: "hidden", fontFamily: "'JetBrains Mono', monospace", position: "relative" }}>
      {/* top bar */}
      <div style={{ borderBottom: `1px solid ${ink}`, padding: "12px 14px", display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
        <div style={{ ...wfBox(), width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Mono size={12}>←</Mono>
        </div>
        <Hand size={22}>Theaters</Hand>
        <div style={{ ...wfBox(), padding: "4px 10px", borderRadius: 12, cursor: "pointer" }}>
          <Mono size={10}>login</Mono>
        </div>
      </div>

      {/* search */}
      <div style={{ padding: "12px 14px", flexShrink: 0 }}>
        <SearchBar height={38} label="search theaters…" />
      </div>

      {/* filter pills */}
      <div style={{ padding: "0 14px 10px", display: "flex", gap: 8, overflowX: "auto", flexShrink: 0 }}>
        {[
          { id: "district", label: "District" },
          { id: "type", label: "Type" },
          { id: "showtime", label: "Showtime" },
          { id: "language", label: "Language" },
        ].map((f) => {
          const active = (sel[f.id] || []).length > 0;
          return (
            <div key={f.id}
              onClick={() => setOpenFilter(openFilter === f.id ? null : f.id)}
              style={{ ...wfBox({ background: active ? sticky : "transparent", border: `1px solid ${active ? sticky : ink}`, borderRadius: 16, padding: "6px 12px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer", flexShrink: 0 }) }}>
              <Mono size={10} style={{ color: active ? paper : ink }}>{f.label}</Mono>
              <Mono size={9} style={{ color: active ? paper : ink }}>{openFilter === f.id ? "▴" : "▾"}</Mono>
            </div>
          );
        })}
      </div>

      {/* active chips */}
      {activeChips.length > 0 && (
        <div style={{ padding: "0 14px 10px", display: "flex", gap: 6, flexWrap: "wrap", flexShrink: 0 }}>
          {activeChips.map((c, i) => (
            <div key={i} onClick={() => toggle(c.group, c.label)} style={{ ...wfBox({ background: tile, border: `1px solid ${tile}`, borderRadius: 12, padding: "4px 10px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }) }}>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>{c.label}</span>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>×</span>
            </div>
          ))}
          <div onClick={() => setSel({ district: [], type: [], showtime: [], language: [] })} style={{ padding: "4px 10px", cursor: "pointer" }}>
            <Mono size={10} style={{ color: muted }}>clear all</Mono>
          </div>
        </div>
      )}

      {/* result header */}
      <div style={{ padding: "6px 14px 8px", display: "flex", justifyContent: "space-between", alignItems: "center", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>{theaters.length} theaters · sorted by name</Mono>
        <Mono size={10}>sort ▾</Mono>
      </div>

      {/* theater grid */}
      <div style={{ flex: 1, overflowY: "auto", padding: "4px 14px 14px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {theaters.map((s, i) => (
            <div key={i} style={{ background: tile, borderRadius: 14, overflow: "hidden", display: "flex", flexDirection: "column", cursor: "pointer" }}>
              <div style={{ aspectRatio: "1 / 1", background: "#a8a08a", borderBottom: `1px solid ${paper}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.5 }}>photo</span>
              </div>
              <div style={{ padding: "8px 10px 10px" }}>
                <span style={{ fontFamily: "'Caveat', cursive", fontSize: 17, color: paper, lineHeight: 1, display: "block" }}>{s.name}</span>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.7, display: "block", marginTop: 2 }}>{s.cat}</span>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 6 }}>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>{s.screens} screen{s.screens > 1 ? 's' : ''}</span>
                </div>
                <div style={{ display: "flex", gap: 4, marginTop: 6, flexWrap: "wrap" }}>
                  {s.tags.map((t, j) => (
                    <span key={j} style={{ border: `1px solid ${paper}`, borderRadius: 8, padding: "1px 6px", fontFamily: "'JetBrains Mono', monospace", fontSize: 8, color: paper }}>{t}</span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* dropdown sheet */}
      {openFilter && (
        <div onClick={() => setOpenFilter(null)} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.35)", display: "flex", alignItems: "flex-end", zIndex: 5 }}>
          <div onClick={(e) => e.stopPropagation()} style={{ width: "100%", maxHeight: "70%", background: paper, borderTop: `1px solid ${ink}`, borderTopLeftRadius: 18, borderTopRightRadius: 18, padding: 18, display: "flex", flexDirection: "column", gap: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Hand size={20}>Choose {openFilter}</Hand>
              <div onClick={() => setOpenFilter(null)} style={{ cursor: "pointer" }}><Mono size={12}>×</Mono></div>
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, overflowY: "auto" }}>
              {(filters[openFilter] || []).map((it) => {
                const isOn = (sel[openFilter] || []).includes(it);
                return (
                  <div key={it} onClick={() => toggle(openFilter, it)} style={{ ...wfBox({ background: isOn ? sticky : "transparent", border: `1px solid ${isOn ? sticky : ink}`, borderRadius: 14, padding: "6px 12px", cursor: "pointer" }) }}>
                    <Mono size={11} style={{ color: isOn ? paper : ink }}>{it}</Mono>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* bottom nav */}
      <div style={{ borderTop: `1px solid ${ink}`, padding: "10px 14px", display: "flex", justifyContent: "space-around", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>home</Mono>
        <Mono size={10}>search</Mono>
        <Mono size={10} style={{ color: muted }}>saved</Mono>
        <Mono size={10} style={{ color: muted }}>me</Mono>
      </div>
    </div>
  );
};

/* ══════════════════════════════════════════════════
   SCREEN 5 — Hotels search
══════════════════════════════════════════════════ */
const Screen5_Hotels = () => {
  const [openFilter, setOpenFilter] = useState(null);
  const [sel, setSel] = useState({ district: ["Kochi"], category: [], rating: [], price: [] });

  const filters = {
    district:  ["Trivandrum", "Kollam", "Pathanamthitta", "Alappuzha", "Kottayam", "Idukki", "Ernakulam", "Kochi", "Thrissur", "Palakkad", "Malappuram", "Kozhikode", "Wayanad", "Kannur", "Kasaragod"],
    category:  ["Budget", "Mid-range", "Luxury", "Resort", "Heritage", "Homestay"],
    rating:    ["4.5+ stars", "4.0+ stars", "3.5+ stars", "any rating"],
    price:     ["₹ < 1000", "₹ 1000-2500", "₹ 2500-5000", "₹ 5000+"],
  };

  const toggle = (group, item) => {
    setSel((s) => {
      const cur = s[group] || [];
      return { ...s, [group]: cur.includes(item) ? cur.filter((x) => x !== item) : [...cur, item] };
    });
  };

  const activeChips = [
    ...sel.district.map((d) => ({ group: "district", label: d })),
    ...sel.category.map((c) => ({ group: "category", label: c })),
    ...sel.rating.map((r) => ({ group: "rating", label: r })),
    ...sel.price.map((r) => ({ group: "price", label: r })),
  ];

  const hotels = [
    { name: "Taj Malabar", cat: "Luxury", rating: 4.8, reviews: 612, tags: ["Kochi", "₹ 5000+"] },
    { name: "Forte Kochi", cat: "Mid-range", rating: 4.5, reviews: 289, tags: ["Kochi", "₹ 2500-5000"] },
    { name: "Old Harbour Hotel", cat: "Heritage", rating: 4.7, reviews: 421, tags: ["Kochi", "₹ 2500-5000"] },
    { name: "Zostel Kochi", cat: "Budget", rating: 4.3, reviews: 156, tags: ["Kochi", "₹ < 1000"] },
    { name: "Coconut Creek", cat: "Resort", rating: 4.6, reviews: 334, tags: ["Kochi", "₹ 5000+"] },
    { name: "Spice Village Homestay", cat: "Homestay", rating: 4.4, reviews: 98, tags: ["Kochi", "₹ 1000-2500"] },
  ];

  return (
    <div style={{ width: 390, height: 844, background: paper, display: "flex", flexDirection: "column", overflow: "hidden", fontFamily: "'JetBrains Mono', monospace", position: "relative" }}>
      {/* top bar */}
      <div style={{ borderBottom: `1px solid ${ink}`, padding: "12px 14px", display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
        <div style={{ ...wfBox(), width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Mono size={12}>←</Mono>
        </div>
        <Hand size={22}>Hotels</Hand>
        <div style={{ ...wfBox(), padding: "4px 10px", borderRadius: 12, cursor: "pointer" }}>
          <Mono size={10}>login</Mono>
        </div>
      </div>

      {/* search */}
      <div style={{ padding: "12px 14px", flexShrink: 0 }}>
        <SearchBar height={38} label="search hotels…" />
      </div>

      {/* filter pills */}
      <div style={{ padding: "0 14px 10px", display: "flex", gap: 8, overflowX: "auto", flexShrink: 0 }}>
        {[
          { id: "district", label: "District" },
          { id: "category", label: "Category" },
          { id: "rating", label: "Rating" },
          { id: "price", label: "Price" },
        ].map((f) => {
          const active = (sel[f.id] || []).length > 0;
          return (
            <div key={f.id}
              onClick={() => setOpenFilter(openFilter === f.id ? null : f.id)}
              style={{ ...wfBox({ background: active ? sticky : "transparent", border: `1px solid ${active ? sticky : ink}`, borderRadius: 16, padding: "6px 12px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer", flexShrink: 0 }) }}>
              <Mono size={10} style={{ color: active ? paper : ink }}>{f.label}</Mono>
              <Mono size={9} style={{ color: active ? paper : ink }}>{openFilter === f.id ? "▴" : "▾"}</Mono>
            </div>
          );
        })}
      </div>

      {/* active chips */}
      {activeChips.length > 0 && (
        <div style={{ padding: "0 14px 10px", display: "flex", gap: 6, flexWrap: "wrap", flexShrink: 0 }}>
          {activeChips.map((c, i) => (
            <div key={i} onClick={() => toggle(c.group, c.label)} style={{ ...wfBox({ background: tile, border: `1px solid ${tile}`, borderRadius: 12, padding: "4px 10px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }) }}>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>{c.label}</span>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>×</span>
            </div>
          ))}
          <div onClick={() => setSel({ district: [], category: [], rating: [], price: [] })} style={{ padding: "4px 10px", cursor: "pointer" }}>
            <Mono size={10} style={{ color: muted }}>clear all</Mono>
          </div>
        </div>
      )}

      {/* result header */}
      <div style={{ padding: "6px 14px 8px", display: "flex", justifyContent: "space-between", alignItems: "center", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>{hotels.length} hotels · sorted by rating</Mono>
        <Mono size={10}>sort ▾</Mono>
      </div>

      {/* hotel grid */}
      <div style={{ flex: 1, overflowY: "auto", padding: "4px 14px 14px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {hotels.map((s, i) => (
            <div key={i} style={{ background: tile, borderRadius: 14, overflow: "hidden", display: "flex", flexDirection: "column", cursor: "pointer" }}>
              <div style={{ aspectRatio: "1 / 1", background: "#a8a08a", borderBottom: `1px solid ${paper}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.5 }}>photo</span>
              </div>
              <div style={{ padding: "8px 10px 10px" }}>
                <span style={{ fontFamily: "'Caveat', cursive", fontSize: 17, color: paper, lineHeight: 1, display: "block" }}>{s.name}</span>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.7, display: "block", marginTop: 2 }}>{s.cat}</span>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 6 }}>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>★ {s.rating}</span>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.6 }}>({s.reviews})</span>
                </div>
                <div style={{ display: "flex", gap: 4, marginTop: 6, flexWrap: "wrap" }}>
                  {s.tags.map((t, j) => (
                    <span key={j} style={{ border: `1px solid ${paper}`, borderRadius: 8, padding: "1px 6px", fontFamily: "'JetBrains Mono', monospace", fontSize: 8, color: paper }}>{t}</span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* dropdown sheet */}
      {openFilter && (
        <div onClick={() => setOpenFilter(null)} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.35)", display: "flex", alignItems: "flex-end", zIndex: 5 }}>
          <div onClick={(e) => e.stopPropagation()} style={{ width: "100%", maxHeight: "70%", background: paper, borderTop: `1px solid ${ink}`, borderTopLeftRadius: 18, borderTopRightRadius: 18, padding: 18, display: "flex", flexDirection: "column", gap: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Hand size={20}>Choose {openFilter}</Hand>
              <div onClick={() => setOpenFilter(null)} style={{ cursor: "pointer" }}><Mono size={12}>×</Mono></div>
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, overflowY: "auto" }}>
              {(filters[openFilter] || []).map((it) => {
                const isOn = (sel[openFilter] || []).includes(it);
                return (
                  <div key={it} onClick={() => toggle(openFilter, it)} style={{ ...wfBox({ background: isOn ? sticky : "transparent", border: `1px solid ${isOn ? sticky : ink}`, borderRadius: 14, padding: "6px 12px", cursor: "pointer" }) }}>
                    <Mono size={11} style={{ color: isOn ? paper : ink }}>{it}</Mono>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* bottom nav */}
      <div style={{ borderTop: `1px solid ${ink}`, padding: "10px 14px", display: "flex", justifyContent: "space-around", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>home</Mono>
        <Mono size={10}>search</Mono>
        <Mono size={10} style={{ color: muted }}>saved</Mono>
        <Mono size={10} style={{ color: muted }}>me</Mono>
      </div>
    </div>
  );
};

/* ══════════════════════════════════════════════════
   SCREEN 6 — Restaurants search
══════════════════════════════════════════════════ */
const Screen6_Restaurants = () => {
  const [openFilter, setOpenFilter] = useState(null);
  const [sel, setSel] = useState({ district: ["Kochi"], cuisine: [], rating: [], price: [] });

  const filters = {
    district:  ["Trivandrum", "Kollam", "Pathanamthitta", "Alappuzha", "Kottayam", "Idukki", "Ernakulam", "Kochi", "Thrissur", "Palakkad", "Malappuram", "Kozhikode", "Wayanad", "Kannur", "Kasaragod"],
    cuisine:   ["Kerala", "North Indian", "Chinese", "Continental", "Seafood", "Fast Food", "Bakery & Cafe", "Vegetarian"],
    rating:    ["4.5+ stars", "4.0+ stars", "3.5+ stars", "any rating"],
    price:     ["₹ < 200", "₹ 200-500", "₹ 500-1000", "₹ 1000+"],
  };

  const toggle = (group, item) => {
    setSel((s) => {
      const cur = s[group] || [];
      return { ...s, [group]: cur.includes(item) ? cur.filter((x) => x !== item) : [...cur, item] };
    });
  };

  const activeChips = [
    ...sel.district.map((d) => ({ group: "district", label: d })),
    ...sel.cuisine.map((c) => ({ group: "cuisine", label: c })),
    ...sel.rating.map((r) => ({ group: "rating", label: r })),
    ...sel.price.map((r) => ({ group: "price", label: r })),
  ];

  const restaurants = [
    { name: "Dhe Puttu", cat: "Kerala", rating: 4.7, reviews: 812, tags: ["Kochi", "₹ 200-500"] },
    { name: "Kayees Rahmathulla", cat: "Kerala", rating: 4.8, reviews: 1205, tags: ["Kochi", "₹ < 200"] },
    { name: "Fort House Restaurant", cat: "Seafood", rating: 4.6, reviews: 623, tags: ["Kochi", "₹ 500-1000"] },
    { name: "Ginger House", cat: "Continental", rating: 4.5, reviews: 421, tags: ["Kochi", "₹ 1000+"] },
    { name: "Paragon Restaurant", cat: "Kerala", rating: 4.4, reviews: 1534, tags: ["Kochi", "₹ 200-500"] },
    { name: "Kashi Art Cafe", cat: "Bakery & Cafe", rating: 4.6, reviews: 345, tags: ["Kochi", "₹ 200-500"] },
  ];

  return (
    <div style={{ width: 390, height: 844, background: paper, display: "flex", flexDirection: "column", overflow: "hidden", fontFamily: "'JetBrains Mono', monospace", position: "relative" }}>
      {/* top bar */}
      <div style={{ borderBottom: `1px solid ${ink}`, padding: "12px 14px", display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
        <div style={{ ...wfBox(), width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Mono size={12}>←</Mono>
        </div>
        <Hand size={22}>Restaurants</Hand>
        <div style={{ ...wfBox(), padding: "4px 10px", borderRadius: 12, cursor: "pointer" }}>
          <Mono size={10}>login</Mono>
        </div>
      </div>

      {/* search */}
      <div style={{ padding: "12px 14px", flexShrink: 0 }}>
        <SearchBar height={38} label="search restaurants…" />
      </div>

      {/* filter pills */}
      <div style={{ padding: "0 14px 10px", display: "flex", gap: 8, overflowX: "auto", flexShrink: 0 }}>
        {[
          { id: "district", label: "District" },
          { id: "cuisine", label: "Cuisine" },
          { id: "rating", label: "Rating" },
          { id: "price", label: "Price" },
        ].map((f) => {
          const active = (sel[f.id] || []).length > 0;
          return (
            <div key={f.id}
              onClick={() => setOpenFilter(openFilter === f.id ? null : f.id)}
              style={{ ...wfBox({ background: active ? sticky : "transparent", border: `1px solid ${active ? sticky : ink}`, borderRadius: 16, padding: "6px 12px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer", flexShrink: 0 }) }}>
              <Mono size={10} style={{ color: active ? paper : ink }}>{f.label}</Mono>
              <Mono size={9} style={{ color: active ? paper : ink }}>{openFilter === f.id ? "▴" : "▾"}</Mono>
            </div>
          );
        })}
      </div>

      {/* active chips */}
      {activeChips.length > 0 && (
        <div style={{ padding: "0 14px 10px", display: "flex", gap: 6, flexWrap: "wrap", flexShrink: 0 }}>
          {activeChips.map((c, i) => (
            <div key={i} onClick={() => toggle(c.group, c.label)} style={{ ...wfBox({ background: tile, border: `1px solid ${tile}`, borderRadius: 12, padding: "4px 10px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }) }}>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>{c.label}</span>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>×</span>
            </div>
          ))}
          <div onClick={() => setSel({ district: [], cuisine: [], rating: [], price: [] })} style={{ padding: "4px 10px", cursor: "pointer" }}>
            <Mono size={10} style={{ color: muted }}>clear all</Mono>
          </div>
        </div>
      )}

      {/* result header */}
      <div style={{ padding: "6px 14px 8px", display: "flex", justifyContent: "space-between", alignItems: "center", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>{restaurants.length} restaurants · sorted by rating</Mono>
        <Mono size={10}>sort ▾</Mono>
      </div>

      {/* restaurant grid */}
      <div style={{ flex: 1, overflowY: "auto", padding: "4px 14px 14px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {restaurants.map((s, i) => (
            <div key={i} style={{ background: tile, borderRadius: 14, overflow: "hidden", display: "flex", flexDirection: "column", cursor: "pointer" }}>
              <div style={{ aspectRatio: "1 / 1", background: "#a8a08a", borderBottom: `1px solid ${paper}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.5 }}>photo</span>
              </div>
              <div style={{ padding: "8px 10px 10px" }}>
                <span style={{ fontFamily: "'Caveat', cursive", fontSize: 17, color: paper, lineHeight: 1, display: "block" }}>{s.name}</span>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.7, display: "block", marginTop: 2 }}>{s.cat}</span>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 6 }}>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>★ {s.rating}</span>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.6 }}>({s.reviews})</span>
                </div>
                <div style={{ display: "flex", gap: 4, marginTop: 6, flexWrap: "wrap" }}>
                  {s.tags.map((t, j) => (
                    <span key={j} style={{ border: `1px solid ${paper}`, borderRadius: 8, padding: "1px 6px", fontFamily: "'JetBrains Mono', monospace", fontSize: 8, color: paper }}>{t}</span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* dropdown sheet */}
      {openFilter && (
        <div onClick={() => setOpenFilter(null)} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.35)", display: "flex", alignItems: "flex-end", zIndex: 5 }}>
          <div onClick={(e) => e.stopPropagation()} style={{ width: "100%", maxHeight: "70%", background: paper, borderTop: `1px solid ${ink}`, borderTopLeftRadius: 18, borderTopRightRadius: 18, padding: 18, display: "flex", flexDirection: "column", gap: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Hand size={20}>Choose {openFilter}</Hand>
              <div onClick={() => setOpenFilter(null)} style={{ cursor: "pointer" }}><Mono size={12}>×</Mono></div>
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, overflowY: "auto" }}>
              {(filters[openFilter] || []).map((it) => {
                const isOn = (sel[openFilter] || []).includes(it);
                return (
                  <div key={it} onClick={() => toggle(openFilter, it)} style={{ ...wfBox({ background: isOn ? sticky : "transparent", border: `1px solid ${isOn ? sticky : ink}`, borderRadius: 14, padding: "6px 12px", cursor: "pointer" }) }}>
                    <Mono size={11} style={{ color: isOn ? paper : ink }}>{it}</Mono>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* bottom nav */}
      <div style={{ borderTop: `1px solid ${ink}`, padding: "10px 14px", display: "flex", justifyContent: "space-around", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>home</Mono>
        <Mono size={10}>search</Mono>
        <Mono size={10} style={{ color: muted }}>saved</Mono>
        <Mono size={10} style={{ color: muted }}>me</Mono>
      </div>
    </div>
  );
};

/* ══════════════════════════════════════════════════════════════
   SCREEN 7 — Beauty & Wellness search
══════════════════════════════════════════════════════════════ */
const Screen7_Beauty = () => {
  const [openFilter, setOpenFilter] = useState(null);
  const [sel, setSel] = useState({ district: ["Kochi"], type: [], rating: [], price: [] });

  const filters = {
    district:  ["Trivandrum", "Kollam", "Pathanamthitta", "Alappuzha", "Kottayam", "Idukki", "Ernakulam", "Kochi", "Thrissur", "Palakkad", "Malappuram", "Kozhikode", "Wayanad", "Kannur", "Kasaragod"],
    type:      ["Salon", "Spa", "Ayurveda", "Massage", "Yoga Studio", "Fitness Center", "Beauty Clinic"],
    rating:    ["4.5+ stars", "4.0+ stars", "3.5+ stars", "any rating"],
    price:     ["₹ < 500", "₹ 500-1500", "₹ 1500-3000", "₹ 3000+"],
  };

  const toggle = (group, item) => {
    setSel((s) => {
      const cur = s[group] || [];
      return { ...s, [group]: cur.includes(item) ? cur.filter((x) => x !== item) : [...cur, item] };
    });
  };

  const activeChips = [
    ...sel.district.map((d) => ({ group: "district", label: d })),
    ...sel.type.map((c) => ({ group: "type", label: c })),
    ...sel.rating.map((r) => ({ group: "rating", label: r })),
    ...sel.price.map((r) => ({ group: "price", label: r })),
  ];

  const places = [
    { name: "Kalari Kovilakom", cat: "Ayurveda", rating: 4.9, reviews: 421, tags: ["Kochi", "₹ 3000+"] },
    { name: "Tone & Tan Unisex Salon", cat: "Salon", rating: 4.6, reviews: 712, tags: ["Kochi", "₹ 500-1500"] },
    { name: "The Spa at Trident", cat: "Spa", rating: 4.8, reviews: 298, tags: ["Kochi", "₹ 1500-3000"] },
    { name: "Isha Yoga Center", cat: "Yoga Studio", rating: 4.7, reviews: 534, tags: ["Kochi", "₹ < 500"] },
    { name: "Gold's Gym", cat: "Fitness Center", rating: 4.5, reviews: 623, tags: ["Kochi", "₹ 500-1500"] },
    { name: "Kaya Skin Clinic", cat: "Beauty Clinic", rating: 4.4, reviews: 189, tags: ["Kochi", "₹ 1500-3000"] },
  ];

  return (
    <div style={{ width: 390, height: 844, background: paper, display: "flex", flexDirection: "column", overflow: "hidden", fontFamily: "'JetBrains Mono', monospace", position: "relative" }}>
      {/* top bar */}
      <div style={{ borderBottom: `1px solid ${ink}`, padding: "12px 14px", display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
        <div style={{ ...wfBox(), width: 28, height: 28, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Mono size={12}>←</Mono>
        </div>
        <Hand size={22}>Beauty & Wellness</Hand>
        <div style={{ ...wfBox(), padding: "4px 10px", borderRadius: 12, cursor: "pointer" }}>
          <Mono size={10}>login</Mono>
        </div>
      </div>

      {/* search */}
      <div style={{ padding: "12px 14px", flexShrink: 0 }}>
        <SearchBar height={38} label="search beauty & wellness…" />
      </div>

      {/* filter pills */}
      <div style={{ padding: "0 14px 10px", display: "flex", gap: 8, overflowX: "auto", flexShrink: 0 }}>
        {[
          { id: "district", label: "District" },
          { id: "type", label: "Type" },
          { id: "rating", label: "Rating" },
          { id: "price", label: "Price" },
        ].map((f) => {
          const active = (sel[f.id] || []).length > 0;
          return (
            <div key={f.id}
              onClick={() => setOpenFilter(openFilter === f.id ? null : f.id)}
              style={{ ...wfBox({ background: active ? sticky : "transparent", border: `1px solid ${active ? sticky : ink}`, borderRadius: 16, padding: "6px 12px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer", flexShrink: 0 }) }}>
              <Mono size={10} style={{ color: active ? paper : ink }}>{f.label}</Mono>
              <Mono size={9} style={{ color: active ? paper : ink }}>{openFilter === f.id ? "▴" : "▾"}</Mono>
            </div>
          );
        })}
      </div>

      {/* active chips */}
      {activeChips.length > 0 && (
        <div style={{ padding: "0 14px 10px", display: "flex", gap: 6, flexWrap: "wrap", flexShrink: 0 }}>
          {activeChips.map((c, i) => (
            <div key={i} onClick={() => toggle(c.group, c.label)} style={{ ...wfBox({ background: tile, border: `1px solid ${tile}`, borderRadius: 12, padding: "4px 10px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }) }}>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>{c.label}</span>
              <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>×</span>
            </div>
          ))}
          <div onClick={() => setSel({ district: [], type: [], rating: [], price: [] })} style={{ padding: "4px 10px", cursor: "pointer" }}>
            <Mono size={10} style={{ color: muted }}>clear all</Mono>
          </div>
        </div>
      )}

      {/* result header */}
      <div style={{ padding: "6px 14px 8px", display: "flex", justifyContent: "space-between", alignItems: "center", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>{places.length} places · sorted by rating</Mono>
        <Mono size={10}>sort ▾</Mono>
      </div>

      {/* grid */}
      <div style={{ flex: 1, overflowY: "auto", padding: "4px 14px 14px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
          {places.map((s, i) => (
            <div key={i} style={{ background: tile, borderRadius: 14, overflow: "hidden", display: "flex", flexDirection: "column", cursor: "pointer" }}>
              <div style={{ aspectRatio: "1 / 1", background: "#a8a08a", borderBottom: `1px solid ${paper}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.5 }}>photo</span>
              </div>
              <div style={{ padding: "8px 10px 10px" }}>
                <span style={{ fontFamily: "'Caveat', cursive", fontSize: 17, color: paper, lineHeight: 1, display: "block" }}>{s.name}</span>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.7, display: "block", marginTop: 2 }}>{s.cat}</span>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 6 }}>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 10, color: paper }}>⭐ {s.rating}</span>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 9, color: paper, opacity: 0.6 }}>({s.reviews})</span>
                </div>
                <div style={{ display: "flex", gap: 4, marginTop: 6, flexWrap: "wrap" }}>
                  {s.tags.map((t, j) => (
                    <span key={j} style={{ border: `1px solid ${paper}`, borderRadius: 8, padding: "1px 6px", fontFamily: "'JetBrains Mono', monospace", fontSize: 8, color: paper }}>{t}</span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* dropdown sheet */}
      {openFilter && (
        <div onClick={() => setOpenFilter(null)} style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.35)", display: "flex", alignItems: "flex-end", zIndex: 5 }}>
          <div onClick={(e) => e.stopPropagation()} style={{ width: "100%", maxHeight: "70%", background: paper, borderTop: `1px solid ${ink}`, borderTopLeftRadius: 18, borderTopRightRadius: 18, padding: 18, display: "flex", flexDirection: "column", gap: 10 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <Hand size={20}>Choose {openFilter}</Hand>
              <div onClick={() => setOpenFilter(null)} style={{ cursor: "pointer" }}><Mono size={12}>×</Mono></div>
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, overflowY: "auto" }}>
              {(filters[openFilter] || []).map((it) => {
                const isOn = (sel[openFilter] || []).includes(it);
                return (
                  <div key={it} onClick={() => toggle(openFilter, it)} style={{ ...wfBox({ background: isOn ? sticky : "transparent", border: `1px solid ${isOn ? sticky : ink}`, borderRadius: 14, padding: "6px 12px", cursor: "pointer" }) }}>
                    <Mono size={11} style={{ color: isOn ? paper : ink }}>{it}</Mono>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* bottom nav */}
      <div style={{ borderTop: `1px solid ${ink}`, padding: "10px 14px", display: "flex", justifyContent: "space-around", flexShrink: 0 }}>
        <Mono size={10} style={{ color: muted }}>home</Mono>
        <Mono size={10}>search</Mono>
        <Mono size={10} style={{ color: muted }}>saved</Mono>
        <Mono size={10} style={{ color: muted }}>me</Mono>
      </div>
    </div>
  );
};

/* ── App ── */
function App() {
  const [tw, setTw] = useTweaks(/*EDITMODE-BEGIN*/{"dummy":1}/*EDITMODE-END*/);
  return (
    <DesignCanvas title="onkerala" subtitle="Building screens one by one">
      <DCSection id="s1" title="Home">
        <DCArtboard id="a1" label="01 · Home" width={390} height={844}>
          <Screen1_Home />
        </DCArtboard>
        <DCArtboard id="a2" label="02 · Shops" width={390} height={844}>
          <Screen2_Shops />
        </DCArtboard>
        <DCArtboard id="a3" label="03 · Services" width={390} height={844}>
          <Screen3_Services />
        </DCArtboard>
        <DCArtboard id="a4" label="04 · Theaters" width={390} height={844}>
          <Screen4_Theaters />
        </DCArtboard>
        <DCArtboard id="a5" label="05 · Hotels" width={390} height={844}>
          <Screen5_Hotels />
        </DCArtboard>
        <DCArtboard id="a6" label="06 · Restaurants" width={390} height={844}>
          <Screen6_Restaurants />
        </DCArtboard>
        <DCArtboard id="a7" label="07 · Beauty & Wellness" width={390} height={844}>
          <Screen7_Beauty />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(<App />);

/**
 * Indian / Kerala color name → hex mapping.
 * All hex values are lowercase 6-digit #RRGGBB strings.
 */
const COLOR_MAP: Record<string, string> = {
  // ── Fruits ──────────────────────────────────────────────────────────────
  mango:       '#ff9f1c',
  banana:      '#ffe135',
  jackfruit:   '#d4820a',
  tamarind:    '#6b3a2a',
  'chilli red':'#c0392b',
  chilli:      '#c0392b',
  tomato:      '#ff6347',

  // ── Spices ───────────────────────────────────────────────────────────────
  saffron:     '#ff671f',
  kesari:      '#ff671f',
  haldi:       '#e9b824',
  turmeric:    '#e9b824',
  pepper:      '#1a1a1a',
  'pepper black': '#1a1a1a',
  cardamom:    '#5c7a3e',
  cinnamon:    '#7b3f00',

  // ── Nature / Kerala landscape ────────────────────────────────────────────
  'neem green':     '#78a829',
  neem:             '#78a829',
  'paddy green':    '#6a9e3e',
  paddy:            '#6a9e3e',
  'rice white':     '#f5f0e8',
  rice:             '#f5f0e8',
  laterite:         '#c45c3d',
  'kerala red':     '#c45c3d',
  'laterite red':   '#c45c3d',
  'monsoon blue':   '#4a7fa5',
  monsoon:          '#4a7fa5',
  'backwater blue': '#1a6b7c',
  backwater:        '#1a6b7c',
  'forest green':   '#228b22',
  forest:           '#228b22',
  coconut:          '#c4a35a',
  'coconut white':  '#f8f0dc',
  'banana leaf':    '#4e8535',

  // ── Flowers ──────────────────────────────────────────────────────────────
  jasmine:          '#f8f4e3',
  'jasmine white':  '#f8f4e3',
  marigold:         '#f9a602',
  'lotus pink':     '#e75480',
  lotus:            '#e75480',
  hibiscus:         '#b5003a',
  champa:           '#ffd700',
  'champa yellow':  '#ffd700',
  rose:             '#e8115b',
  'rose pink':      '#e8115b',

  // ── Textiles ─────────────────────────────────────────────────────────────
  'kasavu gold':    '#d4a843',
  kasavu:           '#d4a843',
  indigo:           '#4b0082',
  'peacock blue':   '#0078a8',
  'peacock green':  '#00827f',
  peacock:          '#0078a8',
  'kathakali red':  '#cc2200',
  'mundu white':    '#f5f0e0',

  // ── Festivals ────────────────────────────────────────────────────────────
  'onam yellow':    '#f6c90e',
  onam:             '#f6c90e',
  'diwali gold':    '#f5a623',
  diwali:           '#f5a623',
  'christmas red':  '#cc0000',
  'christmas green':'#006400',
  'eid green':      '#00894d',
  eid:              '#00894d',
  vishu:            '#ffbf00',
  'holi pink':      '#e84393',
  holi:             '#e84393',

  // ── Standard / common ────────────────────────────────────────────────────
  white:            '#ffffff',
  black:            '#000000',
  red:              '#ff0000',
  'dark red':       '#8b0000',
  crimson:          '#dc143c',
  green:            '#008000',
  'dark green':     '#006400',
  'light green':    '#90ee90',
  blue:             '#0000ff',
  'dark blue':      '#00008b',
  'light blue':     '#add8e6',
  navy:             '#001f5b',
  'navy blue':      '#001f5b',
  yellow:           '#ffff00',
  'dark yellow':    '#cccc00',
  orange:           '#ff8000',
  'dark orange':    '#cc5500',
  purple:           '#800080',
  violet:           '#8f00ff',
  pink:             '#ffc0cb',
  'hot pink':       '#ff69b4',
  grey:             '#808080',
  gray:             '#808080',
  'light grey':     '#d3d3d3',
  'light gray':     '#d3d3d3',
  'dark grey':      '#404040',
  'dark gray':      '#404040',
  brown:            '#a52a2a',
  'dark brown':     '#5c1010',
  cream:            '#fffdd0',
  beige:            '#f5f5dc',
  gold:             '#ffd700',
  silver:           '#c0c0c0',
  maroon:           '#800000',
  teal:             '#008080',
  'dark teal':      '#004d4d',
  cyan:             '#00ffff',
  'rose gold':      '#b76e79',
  'sky blue':       '#87ceeb',
  lime:             '#00ff00',
  'lime green':     '#32cd32',
  magenta:          '#ff00ff',
  coral:            '#ff7f50',
  salmon:           '#fa8072',
  tan:              '#d2b48c',
  khaki:            '#c3b091',
  lavender:         '#e6e6fa',
  mint:             '#98ff98',
  'mint green':     '#98ff98',
  turquoise:        '#40e0d0',
  aqua:             '#00ffff',
  azure:            '#007fff',
  peach:            '#ffcba4',
  ivory:            '#fffff0',
  charcoal:         '#36454f',
  ash:              '#b2beb5',
  sand:             '#c2b280',
  copper:           '#b87333',
  bronze:           '#cd7f32',
  burgundy:         '#800020',
  ochre:            '#cc7722',
  mustard:          '#ffdb58',
  olive:            '#808000',
  'olive green':    '#6b8e23',
};

/**
 * Resolve a human color name to a 6-digit hex string.
 * Returns null if the name is not recognised.
 */
export function resolveColorName(name: string): string | null {
  if (!name) return null;

  const normalized = name
    .trim()
    .toLowerCase()
    .replace(/colour/g, 'color') // British → American
    .replace(/\s+/g, ' ');       // collapse multiple spaces

  if (COLOR_MAP[normalized]) return COLOR_MAP[normalized];

  // Partial / alias scan — try removing common filler words
  const stripped = normalized.replace(/\b(colour|color|shade|tone)\b/g, '').trim();
  if (stripped && COLOR_MAP[stripped]) return COLOR_MAP[stripped];

  return null;
}

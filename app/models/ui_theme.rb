# Registry for the three-axis look system ("theme lab").
#
#   palette   → color primitives (paper, ink, the neutral ramp, accent hues)
#   typeface  → the type pairing (body / display / mono)
#   style     → structural skin: shape, depth, density, motion, placement
#
# The axes are independent: any palette works with any typeface and any style
# (10 × 10 × 10 = 1000 combinations), and each is applied purely by a data
# attribute on <html> — see app/assets/tailwind/themes/*. This registry is the
# single source of truth for both the settings UI and model validation, so
# adding a look means adding one entry plus its CSS block.
class UiTheme
  Option = Data.define(:id, :name, :blurb, :meta) do
    def to_param = id
  end

  # `meta` carries preview data for the settings pickers:
  #   palettes  → { paper:, ink:, accent:, positive: } hex chips
  #   typefaces → { sample:, css_stack: } for a live specimen
  #   styles    → { vibe:, tags: [] } shown as a caption + chips
  PALETTES = [
    Option.new(
      id: "graphite", name: "Graphite",
      blurb: "The house look. Near-black ink on paper white, color reserved for money moving.",
      meta: { paper: "#FFFFFF", ink: "#171717", accent: "#1570EF", positive: "#078C52", ground_dark: "#0B0B0B" }
    ),
    Option.new(
      id: "sequoia", name: "Sequoia",
      blurb: "Warm earth: redwood bark, moss, and a terracotta accent. Reads like paper in lamplight.",
      meta: { paper: "#FDF8F3", ink: "#2A1E17", accent: "#B4551F", positive: "#4F7942", ground_dark: "#171008" }
    ),
    Option.new(
      id: "blueprint", name: "Blueprint",
      blurb: "Cyanotype drafting: deep navy stock, chalk-white line work, engineering cyan.",
      meta: { paper: "#F2F6FB", ink: "#0B2545", accent: "#00A6D6", positive: "#1B998B", ground_dark: "#061426" }
    ),
    Option.new(
      id: "vellum", name: "Vellum",
      blurb: "Archival ledger — cream stock, sepia ink, oxblood for the debits.",
      meta: { paper: "#FBF6E9", ink: "#3B3226", accent: "#8C2F1E", positive: "#5B7B3A", ground_dark: "#161207" }
    ),
    Option.new(
      id: "phosphor", name: "Phosphor",
      blurb: "CRT terminal. Amber-green glow on carbon. Best paired with the Terminal skin.",
      meta: { paper: "#F2F7F0", ink: "#0F1A12", accent: "#0E7C5A", positive: "#1E7C46", ground_dark: "#050A07" }
    ),
    Option.new(
      id: "tokyo", name: "Tokyo Night",
      blurb: "Indigo midnight with magenta and cyan neon. High contrast, unapologetically synthetic.",
      meta: { paper: "#F7F6FD", ink: "#1B1A3A", accent: "#5B45D9", positive: "#0E8F73", ground_dark: "#0C0D1F" }
    ),
    Option.new(
      id: "botanic", name: "Botanic",
      blurb: "Sage, moss, and clay. The calmest palette here — low saturation, soft edges.",
      meta: { paper: "#F6F8F3", ink: "#222A21", accent: "#6B8F5E", positive: "#3F7D52", ground_dark: "#0C120C" }
    ),
    Option.new(
      id: "copper", name: "Copper Ledger",
      blurb: "Espresso and polished copper. A private-bank statement at 11pm.",
      meta: { paper: "#FAF5EF", ink: "#241C15", accent: "#B87333", positive: "#3E7C63", ground_dark: "#12100D" }
    ),
    Option.new(
      id: "arctic", name: "Arctic",
      blurb: "Glacier blues on slate. Cold, crisp, and very legible in bright rooms.",
      meta: { paper: "#F5F9FC", ink: "#12212B", accent: "#0E7C9E", positive: "#0E9384", ground_dark: "#080F14" }
    ),
    Option.new(
      id: "solaris", name: "Solaris",
      blurb: "Hot sand over aubergine shadow, tangerine accent. Sunset warmth without the pastel.",
      meta: { paper: "#FFF7ED", ink: "#2E1B33", accent: "#E8590C", positive: "#2F9E64", ground_dark: "#170C1B" }
    )
  ].freeze

  TYPEFACES = [
    Option.new(
      id: "geist", name: "Geist",
      blurb: "Neutral Swiss-modern. Quiet, tight, gets out of the way.",
      meta: { sample: "Net worth", css_stack: "'Geist', system-ui, sans-serif" }
    ),
    Option.new(
      id: "instrument", name: "Instrument",
      blurb: "Editorial contrast — a high-contrast serif headline over a cool neutral sans.",
      meta: { sample: "Net worth", css_stack: "'Instrument Serif', Georgia, serif" }
    ),
    Option.new(
      id: "fraunces", name: "Fraunces",
      blurb: "Warm and wonky: soft old-style serif display, flat grotesque body.",
      meta: { sample: "Net worth", css_stack: "'Fraunces', Georgia, serif" }
    ),
    Option.new(
      id: "bricolage", name: "Bricolage",
      blurb: "Contemporary grotesque, deliberately imperfect. Keeps a dashboard from feeling corporate.",
      meta: { sample: "Net worth", css_stack: "'Bricolage Grotesque', system-ui, sans-serif" }
    ),
    Option.new(
      id: "plex", name: "IBM Plex",
      blurb: "Engineered and rational — reads like instrumentation, which suits a ledger.",
      meta: { sample: "Net worth", css_stack: "'IBM Plex Sans', system-ui, sans-serif" }
    ),
    Option.new(
      id: "sora", name: "Sora",
      blurb: "Geometric futurist with wide apertures. Made for the Glass and Aurora skins.",
      meta: { sample: "Net worth", css_stack: "'Sora', system-ui, sans-serif" }
    ),
    Option.new(
      id: "newsreader", name: "Newsreader",
      blurb: "Broadsheet serif for body text — the financial-paper reading experience.",
      meta: { sample: "Net worth", css_stack: "'Newsreader', Georgia, serif" }
    ),
    Option.new(
      id: "archivo", name: "Archivo",
      blurb: "Utility grotesque with a width axis; headlines set wide and heavy like a scoreboard.",
      meta: { sample: "Net worth", css_stack: "'Archivo', system-ui, sans-serif" }
    ),
    Option.new(
      id: "mono", name: "Monospace",
      blurb: "The entire interface on a fixed grid. Numbers align by construction.",
      meta: { sample: "Net worth", css_stack: "'JetBrains Mono', ui-monospace, monospace" }
    ),
    Option.new(
      id: "atkinson", name: "Atkinson",
      blurb: "Legibility first — designed so 0/O and 1/l stay distinguishable. Safest for numbers.",
      meta: { sample: "Net worth", css_stack: "'Atkinson Hyperlegible Next', system-ui, sans-serif" }
    )
  ].freeze

  STYLES = [
    Option.new(
      id: "refined", name: "Refined",
      blurb: "The current app: soft cards, hairline borders, restrained motion.",
      meta: { vibe: "Calm default", tags: %w[soft hairline quiet] }
    ),
    Option.new(
      id: "brutal", name: "Brutalist",
      blurb: "Hard black rules, offset shadows, zero radius, shouting uppercase labels. Cards snap on hover.",
      meta: { vibe: "Loud and structural", tags: %w[flat offset-shadow uppercase] }
    ),
    Option.new(
      id: "glass", name: "Liquid Glass",
      blurb: "Frosted translucent panels over a lit backdrop, luminous edges, specular hover.",
      meta: { vibe: "Depth through blur", tags: %w[frosted blur glow] }
    ),
    Option.new(
      id: "editorial", name: "Editorial",
      blurb: "No cards at all. Hairline rules, a narrow reading column, magazine hierarchy.",
      meta: { vibe: "Print layout", tags: %w[rules whitespace column] }
    ),
    Option.new(
      id: "terminal", name: "Terminal",
      blurb: "Monospace everything, box-drawn borders, scanline wash, blinking cursor accents.",
      meta: { vibe: "CRT console", tags: %w[mono scanlines dense] }
    ),
    Option.new(
      id: "bento", name: "Bento",
      blurb: "Pillowed tiles with layered depth and generous gaps. Tiles press in when you touch them.",
      meta: { vibe: "Soft 3D", tags: %w[pillowed depth spacious] }
    ),
    Option.new(
      id: "dense", name: "Terminal Dense",
      blurb: "Trading-desk information density: small type, zebra rows, square corners, no wasted pixels.",
      meta: { vibe: "Maximum data", tags: %w[compact zebra tabular] }
    ),
    Option.new(
      id: "aurora", name: "Aurora",
      blurb: "Animated gradient mesh behind color-lit cards, glowing hover halos, staggered reveals.",
      meta: { vibe: "Motion forward", tags: %w[gradient animated glow] }
    ),
    Option.new(
      id: "deco", name: "Deco",
      blurb: "Art-deco framing: symmetrical rules, metallic hairlines, small-caps headings, chevrons.",
      meta: { vibe: "Geometric luxury", tags: %w[symmetry metallic small-caps] }
    ),
    Option.new(
      id: "clay", name: "Claymorphic",
      blurb: "Extruded clay: fat radii, dual-tone soft shadows, buttons that physically depress.",
      meta: { vibe: "Extreme 3D", tags: %w[extruded playful tactile] }
    )
  ].freeze

  AXES = {
    palette: { options: PALETTES, default: "graphite", attribute: "data-palette" },
    typeface: { options: TYPEFACES, default: "geist", attribute: "data-typeface" },
    style: { options: STYLES, default: "refined", attribute: "data-ui-style" }
  }.freeze

  class << self
    def options_for(axis) = AXES.fetch(axis.to_sym)[:options]
    def ids_for(axis) = options_for(axis).map(&:id)
    def default_for(axis) = AXES.fetch(axis.to_sym)[:default]

    def find(axis, id)
      options_for(axis).find { |option| option.id == id } ||
        options_for(axis).find { |option| option.id == default_for(axis) }
    end

    # Every axis combination is valid, so "surprise me" is a plain sample.
    def random_combination
      AXES.keys.index_with { |axis| ids_for(axis).sample }
    end
  end
end

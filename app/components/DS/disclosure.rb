class DS::Disclosure < DesignSystemComponent
  renders_one :summary_content

  VARIANTS = %i[default card card_inset inline].freeze

  attr_reader :title, :align, :open, :variant, :opts

  # `:default` — bg-surface summary, no chrome on the `<details>`. Use
  # for inline expanders that sit inside a parent card (the summary
  # itself reads as the surface).
  #
  # `:card` — `<details>` itself becomes a `bg-container shadow-border-xs
  # rounded-xl` card; the summary inherits the container (no own bg).
  # Use for provider-item rows (binance, lunchflow, plaid, etc.) where
  # each card is the surface and the summary is custom rich content.
  #
  # `:card_inset` — `<details>` is `bg-surface-inset rounded-xl` (no
  # shadow). Use for inset sub-panels inside a parent card surface
  # (e.g. the IBKR flex-query "report details" panel embedded inside
  # the IBKR settings flow). Same summary contract as `:card`.
  #
  # `:inline` — no surface, no padding, no shadow. The disclosure reads
  # as a plain text-link-style toggle (e.g. "Alternative auth" inside
  # a form, or a "Manage connections" lazy-load opener). Caller provides
  # the summary text (and optional chevron) via the `summary_content`
  # slot.
  #
  # In card / inline variants, callers should pass their own
  # `summary_content` slot; the built-in title rendering assumes the
  # `:default` shape.
  def initialize(title: nil, align: "right", open: false, variant: :default, **opts)
    @title = title
    @align = align.to_sym
    @open = open
    @variant = variant.to_sym
    @opts = opts

    raise ArgumentError, "Invalid variant: #{@variant}. Must be one of #{VARIANTS.inspect}" unless VARIANTS.include?(@variant)
  end

  def details_classes
    case variant
    when :card
      "group bg-container p-4 shadow-border-xs rounded-xl"
    when :card_inset
      "group bg-surface-inset rounded-xl p-4"
    else
      "group"
    end
  end

  def summary_classes
    case variant
    when :card, :card_inset
      # Card variants: no bg on summary — the parent details *is* the
      # surface. Keep cursor + focus-visible ring + list-none baseline.
      "list-none cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-900 theme-dark:focus-visible:outline-white"
    when :inline
      # Inline variant: no surface, no padding — the summary reads as
      # plain text-link copy. Caller markup (text + optional chevron)
      # provides the visual. Keep cursor + focus-visible ring.
      "list-none cursor-pointer focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-900 theme-dark:focus-visible:outline-white rounded-sm"
    else
      "px-3 py-2 rounded-xl cursor-pointer flex items-center justify-between bg-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-gray-900 theme-dark:focus-visible:outline-white"
    end
  end
end

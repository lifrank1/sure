# Piecewise-linear interpolation through anchor points, clamped at both ends.
# Pure math with no Rails dependencies — keep it that way so anchor tuning is
# predictable and the mapping can be sanity-checked with plain ruby.
module FinancialHealth
  module Curve
    module_function

    # anchors: ascending [raw, score] pairs, e.g. [ [ -25, 5 ], [ 0, 30 ], [ 35, 97 ] ].
    # Returns a Float score, or nil when raw is nil.
    def score(raw, anchors)
      return nil if raw.nil?

      x = raw.to_f
      return anchors.first[1].to_f if x <= anchors.first[0]
      return anchors.last[1].to_f if x >= anchors.last[0]

      anchors.each_cons(2) do |(x0, y0), (x1, y1)|
        if x >= x0 && x <= x1
          frac = (x - x0).to_f / (x1 - x0)
          return (y0 + frac * (y1 - y0)).to_f
        end
      end

      anchors.last[1].to_f
    end
  end
end

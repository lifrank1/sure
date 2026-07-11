import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

// Cumulative month-to-date spending line against an even-pace guide toward
// the month's target (budget or typical-month fallback). The endpoint badge
// reads over/under relative to TODAY'S pace point, not the month total.
export default class extends Controller {
  static values = {
    series: Array, // cumulative spending, index 0 = day 1, last = today
    target: Number,
    days: Number,
    currency: { type: String, default: "$" },
  };

  connect() {
    this.#draw();
    this.resizeHandler = () => {
      this.element.innerHTML = "";
      this.#draw();
    };
    window.addEventListener("resize", this.resizeHandler);
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler);
  }

  #draw() {
    const width = this.element.clientWidth;
    const height = this.element.clientHeight;
    if (width === 0 || height === 0) return;

    const series = this.seriesValue;
    const target = this.targetValue;
    const days = Math.max(this.daysValue, 1);
    const today = series.length; // day of month
    const spentToday = series.length ? series[series.length - 1] : 0;
    const paceToday = target * (today / days);
    const diff = spentToday - paceToday;
    const over = diff > 0;

    const margin = { top: 10, right: 12, bottom: 10, left: 12 };
    const yMax = Math.max(target, spentToday) * 1.08 || 1;

    const x = d3
      .scaleLinear()
      .domain([1, days])
      .range([margin.left, width - margin.right]);
    const y = d3
      .scaleLinear()
      .domain([0, yMax])
      .range([height - margin.bottom, margin.top]);

    const svg = d3
      .select(this.element)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("viewBox", [0, 0, width, height]);

    // Even-pace guide: straight line from day 0 (zero spent) to month-end target
    svg
      .append("line")
      .attr("x1", x(1) - (x(2) - x(1))) // visually anchor at "day 0"
      .attr("y1", y(0))
      .attr("x2", x(days))
      .attr("y2", y(target))
      .attr("stroke-dasharray", "4,4")
      .attr("stroke-width", 1.5)
      .style("stroke", "var(--color-gray-500)")
      .style("opacity", 0.7);

    if (series.length > 0) {
      const line = d3
        .line()
        .x((d, i) => x(i + 1))
        .y((d) => y(d))
        .curve(d3.curveMonotoneX);

      const lineColor = over
        ? "var(--color-destructive)"
        : "var(--color-success)";

      svg
        .append("path")
        .datum(series)
        .attr("fill", "none")
        .attr("stroke-width", 2.5)
        .attr("stroke-linecap", "round")
        .style("stroke", lineColor)
        .attr("d", line);

      // Endpoint marker (ring style: theme-colored stroke, container fill)
      const ex = x(today);
      const ey = y(spentToday);
      svg
        .append("circle")
        .attr("cx", ex)
        .attr("cy", ey)
        .attr("r", 4.5)
        .attr("stroke-width", 2.5)
        .style("stroke", lineColor)
        .style("fill", "var(--color-container)");

      // Over/under badge next to the endpoint
      const fmt = d3.format(",.0f");
      const label = `${this.currencyValue}${fmt(Math.abs(diff))} ${over ? "over" : "under"}`;
      const badge = svg.append("g");
      const text = badge
        .append("text")
        .attr("font-size", 12)
        .attr("font-weight", 500)
        .style("fill", "var(--color-white)")
        .text(label);
      const textWidth = text.node().getComputedTextLength();
      const padX = 8;
      const padY = 5;
      const badgeW = textWidth + padX * 2;
      const badgeH = 24;

      // Prefer below-right of the endpoint; flip left/up when out of bounds
      let bx = ex + 10;
      let by = ey + 12;
      if (bx + badgeW > width - margin.right) bx = ex - badgeW - 10;
      if (by + badgeH > height - margin.bottom) by = ey - badgeH - 12;
      if (by < margin.top) by = margin.top;

      badge
        .insert("rect", "text")
        .attr("x", bx)
        .attr("y", by)
        .attr("width", badgeW)
        .attr("height", badgeH)
        .attr("rx", 6)
        .style("fill", over ? "var(--color-destructive)" : "var(--color-success)");
      text
        .attr("x", bx + padX)
        .attr("y", by + badgeH / 2 + 4);
    }
  }
}

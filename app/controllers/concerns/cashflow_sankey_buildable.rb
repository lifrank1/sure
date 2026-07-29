# Builds the cashflow sankey dataset shared by the dashboard and the Reports
# page (extracted from PagesController so both render the same viz).
#
# ONE SPENDING ENGINE (SIMPLIFICATION_PLAN 4a): both sides are GROSS —
# income side = income_totals (money in, refunds included as inflows),
# expense side = expense_totals (money out, no refund netting), each
# including its synthetic Uncategorized bucket. That makes the expense side
# reconcile with expense_split by construction:
#   Σ(links out of cash_flow, excl. surplus) == expense_totals.total
#     == expense_split.spending + expense_split.invested
# and the income side with income_totals.total. Deficit months get an
# explicit balancing node (previously the diagram silently unbalanced).
module CashflowSankeyBuildable
  extend ActiveSupport::Concern

  private

    def build_cashflow_sankey_data(income_totals, expense_totals, currency)
      nodes = []
      links = []
      node_indices = {}

      add_node = ->(unique_key, display_name, value, percentage, color) {
        node_indices[unique_key] ||= begin
          nodes << { id: unique_key, name: display_name, value: value.to_f.round(2), percentage: percentage.to_f.round(1), color: color }
          nodes.size - 1
        end
      }

      total_income = income_totals.total.to_f.round(2)
      total_expense = expense_totals.total.to_f.round(2)

      # Central Cash Flow node (client-side d3 recomputes displayed value
      # from link sums; the server value is cosmetic)
      cash_flow_idx = add_node.call("cash_flow_node", I18n.t("pages.dashboard.cashflow_sankey.node_cash_flow", default: "Cash Flow"), [ total_income, total_expense ].max, 100.0, "var(--color-success)")

      # Categories that also spend this period: income under them is almost
      # always refunds — label the inflow node accordingly so "Dining" never
      # shows up as an income source.
      expense_category_ids = expense_totals.category_totals
        .reject { |ct| ct.category.subcategory? }
        .map { |ct| ct.category.id }
        .compact

      process_gross_side(
        totals: income_totals,
        side_total: total_income,
        prefix: "income",
        add_node: add_node,
        links: links,
        cash_flow_idx: cash_flow_idx,
        flow_direction: :inbound,
        refund_category_ids: expense_category_ids
      )

      process_gross_side(
        totals: expense_totals,
        side_total: total_expense,
        prefix: "expense",
        add_node: add_node,
        links: links,
        cash_flow_idx: cash_flow_idx,
        flow_direction: :outbound
      )

      # Surplus / Deficit — always balance the diagram
      net = (total_income - total_expense).round(2)
      if net.positive?
        percentage = total_income.zero? ? 0 : (net / total_income * 100).round(1)
        idx = add_node.call("surplus_node", I18n.t("pages.dashboard.cashflow_sankey.node_surplus", default: "Surplus"), net, percentage, "var(--color-success)")
        links << { source: cash_flow_idx, target: idx, value: net, color: "var(--color-success)", percentage: percentage }
      elsif net.negative?
        deficit = net.abs
        percentage = total_expense.zero? ? 0 : (deficit / total_expense * 100).round(1)
        idx = add_node.call("deficit_node", I18n.t("pages.dashboard.cashflow_sankey.node_deficit", default: "Deficit"), deficit, percentage, "var(--color-destructive)")
        links << { source: idx, target: cash_flow_idx, value: deficit, color: "var(--color-destructive)", percentage: percentage }
      end

      verify_sankey_reconciliation!(links, node_indices, cash_flow_idx, total_income, total_expense)

      { nodes: nodes, links: links, currency_symbol: Money::Currency.new(currency).symbol }
    end

    # One side of the diagram from GROSS period totals: top-level categories
    # (including the synthetic Uncategorized bucket) linked to cash_flow,
    # with gross same-side subcategory breakdowns beneath their parents.
    # Gross totals never flip sides, so there is no opposite-direction
    # machinery — that complexity existed only for refund-netted inputs.
    def process_gross_side(totals:, side_total:, prefix:, add_node:, links:, cash_flow_idx:, flow_direction:, refund_category_ids: [])
      rows = totals.category_totals
      top_level = rows.reject { |ct| ct.category.subcategory? }
      subs_by_parent = rows
        .select { |ct| ct.category.parent_id.present? && ct.total.to_f.round(2) > 0 }
        .group_by { |ct| ct.category.parent_id }

      top_level.each do |ct|
        val = ct.total.to_f.round(2)
        next if val.zero?

        percentage = side_total.zero? ? 0 : (val / side_total * 100).round(1)
        color = ct.category.color.presence || Category::UNCATEGORIZED_COLOR
        # Stable, locale-independent keys for the synthetic buckets
        synthetic_key = ct.category.other_investments? ? "other_investments" : "uncategorized"
        node_key = "#{prefix}_#{ct.category.id || synthetic_key}"
        display_name = if ct.category.id && refund_category_ids.include?(ct.category.id)
          I18n.t("pages.dashboard.cashflow_sankey.refunds_suffix", name: ct.category.name, default: "%{name} (refunds)")
        else
          ct.category.name
        end
        idx = add_node.call(node_key, display_name, val, percentage, color)

        if flow_direction == :inbound
          links << { source: idx, target: cash_flow_idx, value: val, color: color, percentage: percentage }
        else
          links << { source: cash_flow_idx, target: idx, value: val, color: color, percentage: percentage }
        end

        (ct.category.id ? (subs_by_parent[ct.category.id] || []) : []).each do |sub|
          sub_val = sub.total.to_f.round(2)
          sub_pct = val.zero? ? 0 : (sub_val / val * 100).round(1)
          sub_color = sub.category.color.presence || color
          sub_idx = add_node.call("#{prefix}_sub_#{sub.category.id}", sub.category.name, sub_val, sub_pct, sub_color)

          if flow_direction == :inbound
            links << { source: sub_idx, target: idx, value: sub_val, color: sub_color, percentage: sub_pct }
          else
            links << { source: idx, target: sub_idx, value: sub_val, color: sub_color, percentage: sub_pct }
          end
        end
      end
    end

    # The load-bearing identity of the one-engine reconciliation. Never
    # raises — a drift here is a data bug to fix, not a page to break.
    def verify_sankey_reconciliation!(links, node_indices, cash_flow_idx, total_income, total_expense)
      surplus_idx = node_indices["surplus_node"]
      deficit_idx = node_indices["deficit_node"]

      expense_side = links.sum { |l| l[:source] == cash_flow_idx && l[:target] != surplus_idx ? l[:value] : 0 }
      income_side = links.sum { |l| l[:target] == cash_flow_idx && l[:source] != deficit_idx ? l[:value] : 0 }

      tolerance = [ links.size * 0.01, 0.05 ].max
      if (expense_side - total_expense).abs > tolerance || (income_side - total_income).abs > tolerance
        Rails.logger.warn(
          "[sankey-reconciliation] drift: expense_side=#{expense_side.round(2)} vs #{total_expense} | " \
          "income_side=#{income_side.round(2)} vs #{total_income} (family=#{Current.family&.id})"
        )
      end
    end
end

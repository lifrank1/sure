class AddNeedsReviewToTransactions < ActiveRecord::Migration[7.2]
  # Review queue (Copilot-style): sync-imported transactions default to
  # needs_review = true; manual entry and CSV imports mark themselves
  # reviewed. Existing history starts reviewed so the queue begins empty.
  def up
    add_column :transactions, :needs_review, :boolean, default: true, null: false
    execute "UPDATE transactions SET needs_review = FALSE"
    add_index :transactions, :needs_review,
              where: "needs_review = TRUE",
              name: "index_transactions_on_needs_review_true"
  end

  def down
    remove_index :transactions, name: "index_transactions_on_needs_review_true"
    remove_column :transactions, :needs_review
  end
end

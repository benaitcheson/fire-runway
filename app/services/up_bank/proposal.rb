# One proposed budget row from an Up import: what the budget says now vs the
# monthly average Up's transaction history suggests.
module UpBank
  Proposal = Struct.new(
    :section, :name, :current_amount_cents, :current_frequency,
    :current_monthly_cents, :proposed_monthly_cents,
    :transaction_count, :sample_descriptions, :unmapped,
    keyword_init: true
  ) do
    def new_row? = current_amount_cents.nil?

    # An apply would overwrite a value the user has entered by hand.
    def conflict?
      current_amount_cents.to_i.positive? && current_monthly_cents != proposed_monthly_cents
    end

    # Checked by default only when applying can't lose entered data.
    def preselected? = !unmapped && !conflict?
  end
end

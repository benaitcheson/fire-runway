class UpImportsController < ApplicationController
  # Swapped out in controller tests so previews don't hit the network.
  class_attribute :importer_factory, default: lambda { |user:, lookback_months:|
    UpBank::BudgetImporter.new(user: user, lookback_months: lookback_months)
  }

  # GET /budget/up_import — fetch Up transactions and show proposed amounts.
  def new
    unless helpers.up_bank_configured?
      return redirect_to budget_path, alert: "Set UP_API_TOKEN to enable Up sync."
    end

    @lookback_months = params.fetch(:lookback_months, 3).to_i.clamp(1, 12)
    @proposals = importer_factory.call(user: current_user, lookback_months: @lookback_months).call
  rescue UpBank::AuthError
    redirect_to budget_path, alert: "Up rejected the API token — check UP_API_TOKEN."
  rescue UpBank::Error => e
    redirect_to budget_path, alert: "Couldn't reach Up: #{e.message}"
  end

  # POST /budget/up_import — write the checked proposals. No network calls.
  def create
    applied = 0
    proposal_rows.each do |row|
      next unless row[:include] == "1" && BudgetItem::SECTIONS.key?(row[:section])

      item = current_user.budget_items.find_or_initialize_by(
        section: row[:section], name: row[:name].to_s.strip.first(100)
      )
      item.position = next_position(row[:section]) if item.new_record?
      item.update!(amount_cents: [row[:proposed_monthly_cents].to_i, 0].max, frequency: "monthly")
      applied += 1
    end

    redirect_to budget_path, notice: "Updated #{applied} budget #{"row".pluralize(applied)} from Up."
  end

  private

  def proposal_rows
    params.fetch(:proposals, {}).values.map do |row|
      row.permit(:include, :section, :name, :proposed_monthly_cents)
    end
  end

  def next_position(section)
    (current_user.budget_items.in_section(section).maximum(:position) || 0) + 1
  end
end

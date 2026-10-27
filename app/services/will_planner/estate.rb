# Works out what a will plan actually does with the user's money: which
# assets pass under the will and which go around it, what the estate is worth
# after debts, roughly what each beneficiary ends up with, and what is missing
# or likely to go wrong.
#
# A debt secured on an asset is paid from that asset first, as succession law
# provides in every Australian state unless the will says otherwise: a loan on
# a joint tenancy home goes with the home, and a gifted asset passes with its
# loan. Every other debt comes out of the residue first. If those debts are
# bigger than the residue, specific gifts shrink in proportion ("abate").
module WillPlanner
  class Estate
    Row = Struct.new(:instruction, :asset_name, :value_cents, :estate_cents, :route, :recipient,
                     :secured_cents, keyword_init: true) do
      # The part of the asset's secured loans that travels with the asset.
      def carried_cents
        case route
        when :gift then [secured_cents, estate_cents].min
        when :outside then secured_cents
        else 0
        end
      end
    end
    DebtRow = Struct.new(:instruction, :name, :amount_cents, :asset_row, keyword_init: true) do
      # :estate (paid out of the estate), :with_gift or :with_asset (outside the will)
      def treatment
        case asset_row&.route
        when :gift then :with_gift
        when :outside then :with_asset
        else :estate
        end
      end
    end
    Inheritance = Struct.new(:beneficiary, :gift_names, :gift_cents, :residue_cents, keyword_init: true) do
      def total_cents = gift_cents + residue_cents
    end
    Check = Struct.new(:level, :message, keyword_init: true)

    LEVELS = { action: "Needs doing", warning: "Worth fixing", tip: "Good to know" }.freeze
    SUPER_NAME = /\bsuper(annuation)?\b/i
    PARTNER_WORDS = /partner|spouse|wife|husband|de ?facto|fianc/i

    attr_reader :plan

    def initialize(plan)
      @plan = plan
      @user = plan.user
      @profile = @user.profile
    end

    def rows
      @rows ||= begin
        secured = liability_instructions.select(&:secured_asset_id)
                                        .group_by(&:secured_asset_id)
                                        .transform_values { |list| list.sum { |i| i.user_liability.amount_cents } }
        @plan.instructions_for_assets.map do |instruction|
          route = if !instruction.passes_under_will? then :outside
                  elsif instruction.gift? then :gift
                  else :residue
                  end
          Row.new(instruction: instruction, asset_name: instruction.user_asset.item_name,
                  value_cents: instruction.value_cents, estate_cents: instruction.estate_value_cents,
                  route: route, recipient: recipient_for(instruction, route),
                  secured_cents: secured.fetch(instruction.user_asset_id, 0))
        end
      end
    end

    def debt_rows
      @debt_rows ||= liability_instructions.map do |instruction|
        DebtRow.new(instruction: instruction, name: instruction.user_liability.item_name,
                    amount_cents: instruction.user_liability.amount_cents,
                    asset_row: rows.find { |r| r.instruction.user_asset_id == instruction.secured_asset_id })
      end
    end

    def liabilities = debt_rows.map { |d| d.instruction.user_liability }
    def total_debts_cents = debt_rows.sum(&:amount_cents)

    def gross_cents = rows.sum(&:estate_cents)
    def gross_gift_cents = gift_rows.sum(&:estate_cents)
    # Loans that pass with gifted assets, reducing those gifts.
    def gift_carried_cents = gift_rows.sum(&:carried_cents)
    # Loans that go with assets passing outside the will.
    def outside_debts_cents = rows.select { |r| r.route == :outside }.sum(&:carried_cents)

    # Debts the estate pays, residue first: unsecured debts, loans on residue
    # assets, and any part of a gift's loan bigger than the gift itself.
    def debts_cents
      debt_rows.select { |d| d.treatment == :estate }.sum(&:amount_cents) +
        gift_rows.sum { |r| r.secured_cents - r.carried_cents }
    end

    # Gifts net of the loans they carry.
    def gift_cents = gross_gift_cents - gift_carried_cents
    def net_cents = gross_cents - debts_cents - gift_carried_cents
    def residue_cents = [gross_cents - gross_gift_cents - debts_cents, 0].max

    # How much of the specific gifts must be sold to pay debts the residue can't cover.
    def gift_shortfall_cents
      [debts_cents - (gross_cents - gross_gift_cents), 0].max.clamp(0, gift_cents)
    end

    # Super from the Profile, unless it is already listed as an asset.
    def profile_super_cents
      return 0 if rows.any? { |r| r.asset_name.match?(SUPER_NAME) }

      @profile.super_balance_cents.to_i
    end

    def outside_cents
      rows.select { |r| r.route == :outside }.sum(&:value_cents) + profile_super_cents
    end

    def beneficiaries
      @plan.beneficiaries.select(&:persisted?).reject(&:marked_for_destruction?)
    end

    def inheritances
      abatement = gift_cents.zero? ? 0 : gift_shortfall_cents.to_d / gift_cents
      beneficiaries.map do |beneficiary|
        gifts = rows.select { |r| r.route == :gift && r.instruction.will_beneficiary_id == beneficiary.id }
        gift_total = gifts.sum { |r| r.estate_cents - r.carried_cents }
        Inheritance.new(beneficiary: beneficiary, gift_names: gifts.map(&:asset_name),
                        gift_cents: (gift_total * (1 - abatement)).round,
                        residue_cents: (residue_cents * beneficiary.residue_share_pct.to_d / 100).round)
      end
    end

    def checks
      @checks ||= [
        *people_checks, *beneficiary_checks, *super_checks, *asset_checks, *debt_checks, *status_checks
      ].sort_by { |c| LEVELS.keys.index(c.level) }
    end

    def ready? = checks.none? { |c| c.level == :action }

    private

    def gift_rows = rows.select { |r| r.route == :gift }

    def liability_instructions
      @liability_instructions ||= @plan.instructions_for_liabilities
    end

    def recipient_for(instruction, route)
      case route
      when :gift then instruction.will_beneficiary.name
      when :residue then "Residue"
      else instruction.ownership == "joint_tenants" ? "Surviving co-owner" : "Fund, trust or company rules"
      end
    end

    def money(cents)
      ActiveSupport::NumberHelper.number_to_currency(cents / 100.0, precision: 0)
    end

    def check(level, message) = Check.new(level: level, message: message)

    def people_checks
      out = []
      if @plan.executor_name.nil?
        out << check(:action, "Name an executor: the person who deals with your estate and carries out your will.")
      elsif @plan.backup_executor_name.nil?
        out << check(:tip, "Name a backup executor in case #{@plan.executor_name} can't or won't act.")
      end

      if @profile.dependants_count.to_i.positive? && @plan.guardian_name.nil?
        out << check(:action, "Your Profile says #{@profile.dependants_count} people depend on you. " \
                              "If any are children under 18, name a guardian for them.")
      elsif @plan.guardian_name && @plan.backup_guardian_name.nil?
        out << check(:tip, "Name a backup guardian in case #{@plan.guardian_name} can't take on the children.")
      end
      out << check(:tip, "Pick your state or territory: witnessing rules and Public Trustee services differ.") if @plan.state.nil?
      out
    end

    def beneficiary_checks
      return [check(:action, "Add at least one beneficiary to receive the rest of your estate (the residue).")] if beneficiaries.empty?

      out = []
      total = @plan.residue_share_total
      if total != 100
        out << check(:action, "Residue shares add up to #{total.to_s('F').sub(/\.0\z/, '')}%. They need to total 100%, " \
                              "or the remainder is handed out under intestacy rules instead of your wishes.")
      end

      if @profile.relationship_status.to_s.start_with?("couple") &&
         beneficiaries.none? { |b| "#{b.relationship} #{b.name}".match?(PARTNER_WORDS) }
        out << check(:warning, "Your partner isn't listed as a beneficiary. Partners and children can challenge a " \
                               "will that doesn't adequately provide for them (a family provision claim).")
      end
      out
    end

    def super_checks
      out = []
      super_assets = rows.select { |r| r.asset_name.match?(SUPER_NAME) }
      super_assets.select { |r| r.route != :outside }.each do |row|
        out << check(:warning, "#{row.asset_name} looks like super. Super is paid out by the fund, not under your " \
                               "will: mark it \"Outside my will\".")
      end

      super_cents = super_assets.sum(&:value_cents) + profile_super_cents
      if super_cents.positive?
        case @plan.super_nomination
        when nil, "none", "non_binding", "unsure"
          out << check(:warning, "About #{money(super_cents)} of super doesn't follow your will. Without a binding " \
                                 "death benefit nomination the fund's trustee decides who receives it. Ask your " \
                                 "fund for a binding nomination form.")
        when "binding_lapsing"
          out << check(:tip, "Lapsing binding nominations usually expire after 3 years. Check the date with your fund.")
        end
      end

      if @profile.has_life_insurance
        out << check(:tip, "Life insurance pays out under the policy's nomination (or your super nomination, " \
                           "for cover held in super), not under your will.")
      end
      out
    end

    def asset_checks
      joint = rows.select { |r| r.instruction.ownership == "joint_tenants" }
      return [] if joint.empty?

      [check(:tip, "#{joint.map(&:asset_name).to_sentence} pass#{'es' if joint.one?} to the surviving co-owner " \
                   "automatically and can't be left in your will.")]
    end

    def debt_checks
      out = []
      if net_cents.negative?
        out << check(:warning, "Your estate's debts (#{money(debts_cents + gift_carried_cents)}) are bigger than its " \
                               "assets (#{money(gross_cents)}). Beneficiaries don't personally inherit debts, but " \
                               "co-borrowers and guarantors stay liable.")
      elsif gift_shortfall_cents.positive?
        out << check(:warning, "Debts are #{money(gift_shortfall_cents)} more than what isn't specifically gifted, so " \
                               "gifted assets would have to be sold to pay them. Gift less, or leave more to the residue.")
      end

      debt_rows.reject { |d| d.treatment == :estate }.group_by(&:asset_row).each do |row, debts|
        loans = "#{debts.map(&:name).to_sentence} (#{money(debts.sum(&:amount_cents))})"
        out << if row.route == :gift
                 check(:tip, "#{row.asset_name} passes to #{row.recipient} with #{loans} secured on it. If you'd " \
                             "rather your estate paid it off first, your will has to say so.")
               else
                 check(:tip, "#{loans} goes with #{row.asset_name} outside your will. If it's a joint loan, the " \
                             "co-borrower becomes responsible for all of it.")
               end
      end

      if debt_rows.any? && debt_rows.none? { |d| d.instruction.secured_asset_id }
        out << check(:tip, "If any debt is secured on an asset, like a home or car loan, pick that asset under " \
                           "Your debts: a secured debt is paid from its asset first.")
      end
      out
    end

    def status_checks
      return [] unless @plan.will_status == "signed" && @plan.signed_on && @plan.signed_on < 5.years.ago.to_date

      [check(:tip, "Your will was signed over five years ago. Review it, and always after marriage, separation, " \
                   "divorce or a new child: marriage and divorce can revoke all or part of a will.")]
    end
  end
end

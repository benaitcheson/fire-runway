# The "fact finder": what a financial planner asks about the person before
# giving advice. One per user, every field optional. The forecast and loan tax
# pages read their personal inputs from here and write them back, and the AI
# assistant is given the answered facts before every question.
class FinancialProfile < ApplicationRecord
  belongs_to :user

  Field = Struct.new(:name, :label, :type, :question, :options, :hint, keyword_init: true) do
    def column = type == :money ? :"#{name}_cents" : name
    def money? = type == :money
    def text? = type == :text
  end

  RELATIONSHIP_STATUSES = {
    "single" => "Single",
    "couple_separate" => "Partnered, separate finances",
    "couple_combined" => "Partnered, combined finances"
  }.freeze
  EMPLOYMENT_TYPES = {
    "full_time" => "Full-time employee",
    "part_time" => "Part-time employee",
    "casual" => "Casual",
    "self_employed" => "Self-employed / business owner",
    "contractor" => "Contractor",
    "not_working" => "Not currently working",
    "retired" => "Retired"
  }.freeze
  INCOME_STABILITIES = {
    "stable" => "Stable and predictable",
    "variable" => "Varies month to month",
    "uncertain" => "Uncertain or at risk"
  }.freeze
  HOUSING_STATUSES = {
    "renting" => "Renting",
    "mortgage" => "Own with a mortgage",
    "own_outright" => "Own outright",
    "family" => "Living with family",
    "other" => "Other"
  }.freeze
  RISK_TOLERANCES = {
    "conservative" => "Conservative: protect what I have",
    "balanced" => "Balanced: some ups and downs are fine",
    "growth" => "Growth: comfortable with big swings for higher returns",
    "aggressive" => "Aggressive: maximise returns, volatility doesn't bother me"
  }.freeze
  INVESTMENT_EXPERIENCES = {
    "none" => "None yet",
    "some" => "Some (ETFs, super choices)",
    "experienced" => "Experienced (shares, property, options)"
  }.freeze

  # Sections in the order the page shows them. The question is what the AI
  # assistant asks when the answer is missing.
  SECTIONS = {
    "personal" => {
      title: "About you",
      fields: [
        Field.new(name: :birth_year, label: "Birth year", type: :integer,
                  question: "What year were you born?"),
        Field.new(name: :relationship_status, label: "Relationship", type: :select,
                  options: RELATIONSHIP_STATUSES,
                  question: "Are you single or partnered, and are finances combined?"),
        Field.new(name: :dependants_count, label: "Financial dependants", type: :integer,
                  question: "How many people depend on you financially?",
                  hint: "Children or anyone else you support")
      ]
    },
    "income" => {
      title: "Income and work",
      fields: [
        Field.new(name: :employment_type, label: "Employment", type: :select,
                  options: EMPLOYMENT_TYPES, question: "What is your employment situation?"),
        Field.new(name: :gross_salary, label: "Gross annual salary", type: :money,
                  question: "What is your gross (before tax) annual salary?",
                  hint: "Before tax, excluding super"),
        Field.new(name: :income_stability, label: "Income stability", type: :select,
                  options: INCOME_STABILITIES, question: "How stable is your income?"),
        Field.new(name: :partner_gross_salary, label: "Partner's gross salary", type: :money,
                  question: "If you have a partner, what is their gross annual salary?",
                  hint: "Leave blank if not applicable")
      ]
    },
    "super_tax" => {
      title: "Super and tax",
      fields: [
        Field.new(name: :super_balance, label: "Super balance", type: :money,
                  question: "What is your current superannuation balance?"),
        Field.new(name: :super_employer_rate, label: "Employer super rate", type: :percent,
                  question: "What percentage does your employer pay into super?",
                  hint: "The guarantee is 12%"),
        Field.new(name: :super_salary_sacrifice_monthly, label: "Salary sacrifice per month", type: :money,
                  question: "Do you salary sacrifice extra into super each month, and how much?"),
        Field.new(name: :has_hecs, label: "HECS/HELP debt", type: :boolean,
                  question: "Do you have a HECS/HELP debt?"),
        Field.new(name: :hecs_balance, label: "HECS/HELP balance", type: :money,
                  question: "What is your HECS/HELP balance?"),
        Field.new(name: :private_hospital_cover, label: "Private hospital cover", type: :boolean,
                  question: "Do you hold private hospital cover?")
      ]
    },
    "home" => {
      title: "Home",
      fields: [
        Field.new(name: :housing_status, label: "Housing", type: :select,
                  options: HOUSING_STATUSES, question: "Do you rent, own with a mortgage, or own outright?")
      ]
    },
    "goals" => {
      title: "Goals",
      fields: [
        Field.new(name: :target_retirement_age, label: "Target retirement age", type: :integer,
                  question: "At what age would you like to retire or be financially independent?"),
        Field.new(name: :retirement_spend_monthly, label: "Retirement spending per month", type: :money,
                  question: "How much would you want to spend per month in retirement, in today's dollars?"),
        Field.new(name: :emergency_fund_months, label: "Emergency fund target", type: :integer,
                  question: "How many months of expenses do you want in an emergency fund?",
                  hint: "Months of expenses"),
        Field.new(name: :goals, label: "Major goals and when", type: :text,
                  question: "What are your major financial goals and roughly when do you want them?",
                  hint: "e.g. house deposit in 3 years, kids, a year of travel")
      ]
    },
    "attitudes" => {
      title: "Attitudes",
      fields: [
        Field.new(name: :risk_tolerance, label: "Risk tolerance", type: :select,
                  options: RISK_TOLERANCES, question: "How do you feel about investment risk?"),
        Field.new(name: :investment_experience, label: "Investment experience", type: :select,
                  options: INVESTMENT_EXPERIENCES, question: "How much investing experience do you have?"),
        Field.new(name: :concerns, label: "What worries you about money?", type: :text,
                  question: "What worries you most about your finances?")
      ]
    },
    "protection" => {
      title: "Insurance and estate",
      fields: [
        Field.new(name: :has_income_protection, label: "Income protection insurance", type: :boolean,
                  question: "Do you have income protection insurance?"),
        Field.new(name: :has_life_insurance, label: "Life insurance", type: :boolean,
                  question: "Do you have life insurance (including through super)?"),
        Field.new(name: :has_will, label: "Will in place", type: :boolean,
                  question: "Do you have a current will?")
      ]
    },
    "notes" => {
      title: "Anything else",
      fields: [
        Field.new(name: :notes, label: "Anything else the assistant should know", type: :text,
                  question: "Is there anything else about your situation worth knowing?")
      ]
    }
  }.freeze

  FIELDS = SECTIONS.values.flat_map { |s| s[:fields] }.freeze
  FIELDS_BY_NAME = FIELDS.index_by(&:name).freeze

  # Dollar accessors over the cents columns, e.g. gross_salary / gross_salary=.
  FIELDS.select(&:money?).each do |field|
    define_method(field.name) do
      cents = public_send(field.column)
      cents && cents / 100.0
    end
    define_method(:"#{field.name}=") do |dollars|
      public_send(:"#{field.column}=", dollars.presence && (dollars.to_f * 100).round)
    end
  end

  validates :birth_year, numericality: { only_integer: true, greater_than_or_equal_to: 1900,
                                         less_than_or_equal_to: ->(_) { Date.today.year } }, allow_nil: true
  validates :target_retirement_age, numericality: { only_integer: true, in: 16..110 }, allow_nil: true
  validates :dependants_count, :emergency_fund_months,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :super_employer_rate, numericality: { in: 0..100 }, allow_nil: true
  FIELDS.select(&:money?).each do |field|
    validates field.column, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  end
  validates :relationship_status, inclusion: { in: RELATIONSHIP_STATUSES.keys }, allow_blank: true
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES.keys }, allow_blank: true
  validates :income_stability, inclusion: { in: INCOME_STABILITIES.keys }, allow_blank: true
  validates :housing_status, inclusion: { in: HOUSING_STATUSES.keys }, allow_blank: true
  validates :risk_tolerance, inclusion: { in: RISK_TOLERANCES.keys }, allow_blank: true
  validates :investment_experience, inclusion: { in: INVESTMENT_EXPERIENCES.keys }, allow_blank: true
  validates :goals, :concerns, :notes, length: { maximum: 2000 }

  # Blank strings from the form mean "not answered", never an empty answer.
  FIELDS.reject(&:money?).each do |field|
    normalizes field.name, with: ->(value) { value.is_a?(String) && value.strip.empty? ? nil : value }
  end

  def answered?(field)
    !public_send(field.column).nil?
  end

  def answered_fields = FIELDS.select { |f| answered?(f) }
  def missing_fields = FIELDS.reject { |f| answered?(f) }

  def completeness_pct
    (answered_fields.size * 100.0 / FIELDS.size).round
  end

  def age
    birth_year && Date.today.year - birth_year
  end

  # Human-readable value for a field, or nil when unanswered.
  def display_value(field)
    value = public_send(field.column)
    return nil if value.nil?

    case field.type
    when :money then ActiveSupport::NumberHelper.number_to_currency(value / 100.0, precision: 0)
    when :boolean then value ? "Yes" : "No"
    when :select then field.options.fetch(value, value)
    when :percent then "#{value.to_f % 1 == 0 ? value.to_i : value.to_f}%"
    else value.to_s
    end
  end

  # Answered facts grouped by section title, for the AI assistant. Age is
  # derived so the model never has to do date arithmetic.
  def facts
    SECTIONS.each_with_object({}) do |(_, section), out|
      lines = section[:fields].filter_map do |field|
        next unless answered?(field)

        label = field.name == :birth_year ? "Age" : field.label
        value = field.name == :birth_year ? "#{age} (born #{birth_year})" : display_value(field)
        [label, value]
      end
      out[section[:title]] = lines.to_h if lines.any?
    end
  end
end

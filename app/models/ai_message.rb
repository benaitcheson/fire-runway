class AiMessage < ApplicationRecord
  belongs_to :user

  ROLES = %w[user assistant].freeze

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :chronological, -> { order(:created_at, :id) }

  # Most recent messages formatted for the chat context window.
  def self.recent_context(limit: 10)
    chronological.last(limit).map { |m| { role: m.role, content: m.content } }
  end
end

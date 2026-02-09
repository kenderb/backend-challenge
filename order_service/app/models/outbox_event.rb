# frozen_string_literal: true

class OutboxEvent < ApplicationRecord
  enum :status, { pending: 0, processing: 1, processed: 2, failed: 3 }, default: :pending, validate: true

  validates :aggregate_type, presence: true
  validates :aggregate_id, presence: true
  validates :event_type, presence: true
  validates :payload, presence: true

  scope :pending_events, -> { where(status: :pending).order(created_at: :asc) }
  # For use by PublishingWorker: claim rows so other workers skip them (multi-container safe).
  scope :lockable_pending, -> { pending_events.lock("FOR UPDATE SKIP LOCKED") }
  scope :processed_events, -> { where(status: :processed) }

  def mark_processing!
    update!(status: :processing)
  end

  def mark_processed!
    update!(status: :processed, processed_at: Time.current, error_message: nil)
  end

  def mark_failed!(error_message)
    update!(status: :failed, error_message: error_message)
  end
end

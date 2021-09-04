# frozen_string_literal: true

class ActivityPub::ProcessStatusService < BaseService
  include JsonLdHelper

  def call(status, json)
    @json    = json
    @uri     = @json['id']
    @status  = status
    @account = status.account

    return unless expected_type?

    RedisLock.acquire(lock_options) do |lock|
      if lock.acquired?
        Status.transaction do
          # TODO: Log edit history
          # TODO: Handle media changes
          # TODO: Handle poll changes

          update_immediate_attributes!
        end
      else
        raise Mastodon::RaceConditionError
      end
    end
  end

  private

  def update_immediate_attributes!
    @status.text         = text_from_content
    @status.spoiler_text = text_from_summary
    @status.sensitive    = @account.sensitized? || @json['sensitive'] || false
    @status.language     = detected_language
    @status.edited_at    = @json['updated'] || Time.now.utc
    @status.save
  end

  def expected_type?
    equals_or_includes_any?(@json['type'], %w(Note Question))
  end

  def lock_options
    { redis: Redis.current, key: "create:#{@uri}", autorelease: 15.minutes.seconds }
  end

  def text_from_content
    if @json['content'].present?
      @json['content']
    elsif content_language_map?
      @json['contentMap'].values.first
    end
  end

  def content_language_map?
    @json['contentMap'].is_a?(Hash) && !@json['contentMap'].empty?
  end

  def text_from_summary
    if @json['summary'].present?
      @json['summary']
    elsif summary_language_map?
      @json['summaryMap'].values.first
    end
  end

  def summary_language_map?
    @json['summaryMap'].is_a?(Hash) && !@json['summaryMap'].empty?
  end

  def language_from_content
    if content_language_map?
      @json['contentMap'].keys.first
    elsif summary_language_map?
      @json['summaryMap'].keys.first
    else
      'und'
    end
  end
end

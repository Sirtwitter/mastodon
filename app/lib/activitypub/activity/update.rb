# frozen_string_literal: true

class ActivityPub::Activity::Update < ActivityPub::Activity
  def perform
    dereference_object!

    if equals_or_includes_any?(@object['type'], %w(Application Group Organization Person Service))
      update_account
    elsif equals_or_includes_any?(@object['type'], %w(Question))
      update_poll
    elsif equals_or_includes_any?(@object['type'], %w(Note))
      update_status
    end
  end

  private

  def update_account
    return reject_payload! if @account.uri != object_uri

    ActivityPub::ProcessAccountService.new.call(@account.username, @account.domain, @object, signed_with_known_key: true)
  end

  def update_poll
    return reject_payload! if invalid_origin?(@object['id'])

    status = Status.find_by(uri: object_uri, account_id: @account.id)
    return if status.nil? || status.preloadable_poll.nil?

    ActivityPub::ProcessPollService.new.call(status.preloadable_poll, @object)
  end

  def update_status
    return reject_payload! if invalid_origin?(@object['id'])

    status = Status.find_by(uri: object_uri, account_id: @account.id)
    return if status.nil?

    ActivityPub::ProcessStatusService.new.call(status, @object)
  end
end

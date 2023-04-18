class Event
  def initialize(event:, logger:)
    @event = event
    @logger = logger
  end

  def notify
    return unless %w[Completed Failed PartiallyFailed].include?(phase)

    send_notifications
  end

  private

  attr_reader :event, :logger

  def send_notifications
    logger.info notification

    send_slack_notification
    send_email_notification
    send_webhook_notification
  end

  def phase
    event.resource.status.phase
  end

  def notification_subject
    @notification_subject ||= "#{notification_prefix} #{resource_type} #{resource_name} #{phase}"
  end

  def resource_type
    event.resource.kind.downcase
  end

  def resource_name
    event.resource.metadata.name
  end

  def send_slack_notification
    return unless send_slack_notification?

    at = phase =~ /failed/i ? [:here] : []

    attachment = {
      fallback: notification_subject,
      text: "#{notification_subject} - #{notification_body}}",
      color: phase =~ /failed/i ? 'danger' : 'good'
    }

    slack_notifier.post at:, attachments: [attachment]
  rescue StandardError => e
    logger.error "Something went wrong with the Slack notification: #{e.message}"
  end

  def send_webhook_notification
    return unless send_webhook_notification?

    url = ENV.fetch('WEBHOOK_URL', nil)

    raise 'No webhook URL specified' if url.blank?

    uri = URI(url)
    res = Net::HTTP.get_response(uri)

    raise 'Webhook request resulted in a non 20x status code' unless res.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    logger.error "Something went wrong with the webhook notification: #{e.message}"
  end

  def send_email_notification
    return unless send_email_notification?

    mail = Mail.new do
      from    ENV.fetch('EMAIL_FROM_ADDRESS', nil)
      to      ENV.fetch('EMAIL_TO_ADDRESS', nil)
      subject notification_subject
      body    notification_body
    end

    mail.deliver!
  rescue StandardError => e
    logger.error "Something went wrong with the email notification: #{e.message}"
  end

  def notification_body
    @notification_body ||= "Run `velero #{resource_type} describe #{resource_name} --details` for more information."
  end

  def send_slack_notification?
    send_notification?(:slack)
  end

  def send_email_notification?
    send_notification?(:email)
  end

  def send_webhook_notification?
    send_notification?(:webhook)
  end

  def send_notification?(notification_type)
    enabled = ENV.fetch("ENABLE_#{notification_type.to_s.upcase}_NOTIFICATIONS", 'false').downcase == 'true'
    succeeded = (phase =~ /failed/i).nil?
    failures_only = ENV.fetch("#{notification_type.to_s.upcase}_FAILURES_ONLY", 'false').downcase == 'true'

    enabled && (!failures_only || !(failures_only && succeeded))
  end
end

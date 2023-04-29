require "log"
require "http/client"
require "email"

class Event
  SLACK_WEBHOOK = ENV.fetch("SLACK_WEBHOOK", "")
  EMAIL_SMTP_HOST = ENV.fetch("EMAIL_SMTP_HOST", "")
  EMAIL_SMTP_PORT = ENV.fetch("EMAIL_SMTP_PORT", "")
  EMAIL_SMTP_USERNAME = ENV.fetch("EMAIL_SMTP_USERNAME", "")
  EMAIL_SMTP_PASSWORD = ENV.fetch("EMAIL_SMTP_PASSWORD", "")
  EMAIL_FROM_ADDRESS = ENV.fetch("EMAIL_FROM_ADDRESS", "")
  EMAIL_TO_ADDRESS = ENV.fetch("EMAIL_TO_ADDRESS", "")
  WEBHOOK_URL = ENV.fetch("WEBHOOK_URL", "")

  private getter event : K8S::Kubernetes::WatchEvent(K8S::Velero::V1::Backup)
  private getter notification_prefix : String

  def initialize(@event)
    @notification_prefix = ENV.fetch("NOTIFICATION_PREFIX", "[Velero]")
  end

  def notify
    return unless %w[Completed Failed PartiallyFailed].includes?(phase)

    Log.info { notification_subject }

    send_slack_notification if send_slack_notification?
    send_email_notification if send_email_notification?
    send_webhook_notification if send_webhook_notification?
  end

  private def phase
    event.object["status"].as(Hash).fetch("phase", "Unknown")
  end

  private def backup_name
    event.object["metadata"].as(Hash)["name"]
  end

  def notification_subject
    @notification_subject ||= "#{notification_prefix} Backup #{backup_name} #{phase} #{phase == "Completed" ? "✅" : "❌"}"
  end

  def notification_body
    @notification_body ||= "Run `velero backup describe #{backup_name} --details` for more information."
  end

  def send_notification?(notification_type)
    enabled = ENV.fetch("ENABLE_#{notification_type.to_s.upcase}_NOTIFICATIONS", "false").downcase == "true"

    succeeded = (phase =~ /failed/i).nil?
    failures_only = ENV.fetch("#{notification_type.to_s.upcase}_FAILURES_ONLY", "false").downcase == "true"

    enabled && (!failures_only || !(failures_only && succeeded))
  end

  def send_slack_notification?
    send_notification?(:slack)
  end

  def send_slack_notification
    if SLACK_WEBHOOK.blank?
      Log.info { "Ensure the SLACK_WEBHOOK environment variable is set" }
      raise Exception.new("Slack configuration missing")
    end

    color = phase == "Completed" ? "good" : "danger"
    payload = {
      "attachments" => [
        {
          "fallback" => notification_subject,
          "color" => color,
          "title" => notification_subject,
          "text" => notification_body
        }
      ]
    }.to_json

    HTTP::Client.post(
      SLACK_WEBHOOK,
      headers: HTTP::Headers{"Content-type" => "application/json"},
      body: payload
    )
  end

  private def email_client : EMail::Client
    @email_client ||= begin
      if EMAIL_SMTP_HOST.blank? || EMAIL_SMTP_PORT.blank? || EMAIL_SMTP_USERNAME.blank? || EMAIL_SMTP_PASSWORD.blank? || EMAIL_FROM_ADDRESS.blank? || EMAIL_TO_ADDRESS.blank?
        Log.info { "Ensure EMAIL_SMTP_HOST, EMAIL_SMTP_PORT, EMAIL_SMTP_USERNAME, EMAIL_SMTP_PASSWORD, EMAIL_FROM_ADDRESS and EMAIL_TO_ADDRESS environment variables are set" }
        raise Exception.new("Email configuration missing")
      end

      config = EMail::Client::Config.new(
        EMAIL_SMTP_HOST,
        EMAIL_SMTP_PORT.to_i,
        helo_domain: extract_domain(EMAIL_FROM_ADDRESS)
      )

      config.use_tls(EMail::Client::TLSMode::STARTTLS)
      config.use_auth(EMAIL_SMTP_USERNAME, EMAIL_SMTP_PASSWORD)

      EMail::Client.new(config)
    end
  end

  private def extract_domain(email : String) : String
    at_position = email.index('@')
    return "" if at_position.nil?
    email[at_position + 1..-1]
  end

  private def send_email_notification?
    send_notification?(:email)
  end

  private def send_email_notification
    email = EMail::Message.new
    email.from    EMAIL_FROM_ADDRESS
    email.to      EMAIL_TO_ADDRESS
    email.subject notification_subject
    email.message notification_body

    email_client.start do
      send(email)
    end
  end

  private def send_webhook_notification?
    send_notification?(:webhook)
  end

  private def send_webhook_notification
    if WEBHOOK_URL.blank?
      Log.info { "Ensure the WEBHOOK_URL environment variable is set" }
      raise Exception.new("Webhook configuration missing")
    end

    HTTP::Client.get(WEBHOOK_URL)
  end
end


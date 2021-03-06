# frozen_string_literal: true

require 'bundler/setup'
require 'slack-notifier'
require 'k8s-ruby'
require 'concurrent'
require 'logger'
require 'yaml'
require 'mail'
require 'uri'
require 'net/http'

require_relative 'kubernetes_client'

Mail.defaults do
  delivery_method :smtp,
                  address: ENV.fetch('EMAIL_SMTP_HOST', nil),
                  port: ENV.fetch('EMAIL_SMTP_PORT', nil),
                  user_name: ENV.fetch('EMAIL_SMTP_USERNAME', nil),
                  password: ENV.fetch('EMAIL_SMTP_PASSWORD', nil)
end

class Controller
  TIMEOUT = 3600 * 24 * 365

  def initialize
    @logger = Logger.new($stdout)

    @slack_notifier = Slack::Notifier.new(ENV.fetch('SLACK_WEBHOOK', nil)) do
      defaults channel: ENV.fetch('SLACK_CHANNEL', nil), username: ENV.fetch('SLACK_USERNAME', 'Velero')
    end

    @velero_namespace = ENV.fetch('VELERO_NAMESPACE', 'velero')
    @kubernetes_client = Kubernetes::Client.new
    @notification_prefix = ENV.fetch('NOTIFICATION_PREFIX', '[Velero]')
    @resource_version = {}
  end

  def start
    $stdout.sync = true

    resource_version[:backups] = kubernetes_client.api('velero.io/v1').resource("backups", namespace: velero_namespace).meta_list.metadata.resourceVersion
    resource_version[:restores] = kubernetes_client.api('velero.io/v1').resource("restores", namespace: velero_namespace).meta_list.metadata.resourceVersion

    t1 = Thread.new { watch_resources :backups }
    t2 = Thread.new { watch_resources :restores }

    t1.join
    t2.join
  end

  private

  attr_reader :logger, :slack_notifier, :velero_namespace, :kubernetes_client, :notification_prefix, :resource_version

  def notify(event)
    phase = event.resource.status.phase

    return if phase.nil? || phase.empty? || phase == 'Deleting' || phase == 'InProgress'

    notification = "#{notification_prefix} #{event.resource.kind} #{event.resource.metadata.name} #{phase}"

    logger.info notification

    send_webhook_notification(event: event, notification: notification)

    send_slack_notification(event: event, notification: notification)

    send_email_notification(event: event, notification: notification)
  end

  def watch_resources(resource_type)
    logger.info "Watching #{resource_type}..."

    kubernetes_client.api('velero.io/v1').resource(resource_type.to_s, namespace: velero_namespace).watch(timeout: TIMEOUT, resourceVersion: resource_version[resource_type]) do |event|
      notify event
      resource_version[resource_type] = event.resource.metadata.resourceVersion
    end
  rescue EOFError, Excon::Error::Socket
    logger.info 'Reconnecting to API...'
    retry
  end

  def send_slack_notification(event:, notification:)
    phase = event.resource.status.phase

    return unless send_slack_notification?(phase)

    at = phase =~ /failed/i ? [:here] : []

    attachment = {
      fallback: notification,
      text: "#{notification} - Run `velero #{event.resource.kind.downcase} describe #{event.resource.metadata.name} --details` for more information.",
      color: phase =~ /failed/i ? 'danger' : 'good'
    }

    slack_notifier.post at: at, attachments: [attachment]
  rescue StandardError => e
    logger.error "Something went wrong with the Slack notification: #{e.message}"
  end

  def send_webhook_notification(event:, notification:)
    phase = event.resource.status.phase

    return unless send_webhook_notification?(phase)

    url = ENV.fetch('WEBHOOK_URL', nil)

    raise 'No webhook URL specified' if url.nil?

    uri = URI(url)
    res = Net::HTTP.get_response(uri)

    raise 'Wenbhook request resulted in a non 20x status code' unless res.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    logger.error "Something went wrong with the webhook notification: #{e.message}"
  end

  def send_email_notification(event:, notification:)
    phase = event.resource.status.phase

    return unless send_email_notification?(phase)

    mail = Mail.new do
      from    ENV.fetch('EMAIL_FROM_ADDRESS', nil)
      to      ENV.fetch('EMAIL_TO_ADDRESS', nil)
      subject notification
      body    "Run `velero #{event.resource.kind.downcase} describe #{event.resource.metadata.name} --details` for more information."
    end

    mail.deliver!
  rescue StandardError => e
    logger.error "Something went wrong with the email notification: #{e.message}"
  end

  def send_slack_notification?(phase)
    enabled = ENV.fetch('ENABLE_SLACK_NOTIFICATIONS', 'false').downcase == 'true'
    succeeded = (phase =~ /failed/i).nil?
    failures_only = ENV.fetch('SLACK_FAILURES_ONLY', 'false').downcase == 'true'

    enabled && (!failures_only || !(failures_only && succeeded))
  end

  def send_email_notification?(phase)
    enabled = ENV.fetch('ENABLE_EMAIL_NOTIFICATIONS', 'false').downcase == 'true'
    succeeded = (phase =~ /failed/i).nil?
    failures_only = ENV.fetch('EMAIL_FAILURES_ONLY', 'false').downcase == 'true'

    enabled && (!failures_only || !(failures_only && succeeded))
  end

  def send_webhook_notification?(phase)
    enabled = ENV.fetch('ENABLE_WEBHOOK_NOTIFICATIONS', 'false').downcase == 'true'
    succeeded = (phase =~ /failed/i).nil?
    failures_only = ENV.fetch('WEBHOOK_FAILURES_ONLY', 'false').downcase == 'true'

    enabled && (!failures_only || !(failures_only && succeeded))
  end
end

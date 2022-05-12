# frozen_string_literal: true

require 'bundler/setup'
require 'slack-notifier'
require 'k8s-ruby'
require 'concurrent'
require 'logger'
require 'yaml'
require 'mail'

require_relative 'kubernetes_client'

Mail.defaults do
  delivery_method :smtp,
                  address: ENV['EMAIL_SMTP_HOST'],
                  port: ENV['EMAIL_SMTP_PORT'],
                  user_name: ENV['EMAIL_SMTP_USERNAME'],
                  password: ENV['EMAIL_SMTP_PASSWORD']
end

class Controller
  TIMEOUT = 3600 * 24 * 365

  def initialize
    @logger = Logger.new($stdout)

    @slack_notifier = Slack::Notifier.new(ENV['SLACK_WEBHOOK']) do
      defaults channel: ENV['SLACK_CHANNEL'], username: ENV.fetch('SLACK_USERNAME', 'Velero')
    end

    @velero_namespace = ENV.fetch('VELERO_NAMESPACE', 'velero')
    @kubernetes_client = Kubernetes::Client.new
    @notification_prefix = ENV.fetch('NOTIFICATION_PREFIX', '[Velero]')
  end

  def start
    $stdout.sync = true

    t1 = Thread.new { watch_resources :backups }
    t2 = Thread.new { watch_resources :restores }

    t1.join
    t2.join
  end

  private

  attr_reader :logger, :slack_notifier, :velero_namespace, :kubernetes_client, :notification_prefix

  def notify(event)
    phase = event.resource.status.phase

    return if phase.empty? || phase == 'Deleting' || phase == 'InProgress'

    notification = "#{notification_prefix} #{event.resource.kind} #{event.resource.metadata.name} #{phase}"

    logger.info notification

    send_slack_notification(event: event, notification: notification)

    send_email_notification(event: event, notification: notification)
  end

  def watch_resources(resource_type)
    resource_version = kubernetes_client.api('velero.io/v1').resource(resource_type.to_s, namespace: velero_namespace).meta_list.metadata.resourceVersion

    logger.info "Watching #{resource_type}..."

    kubernetes_client.api('velero.io/v1').resource(resource_type.to_s, namespace: velero_namespace).watch(timeout: TIMEOUT, resourceVersion: resource_version) do |event|
      resource_version = event.resource.metadata.resourceVersion
      notify event
    end
  rescue EOFError, Excon::Error::Socket
    logger.info 'Reconnecting to API...'
    retry
  end

  def send_slack_notification(event:, notification:)
    return unless ENV.fetch('ENABLE_SLACK_NOTIFICATIONS', 'false') =~ /true/i

    phase = event.resource.status.phase

    at = phase =~ /failed/i ? [:here] : []

    attachment = {
      fallback: notification,
      text: "#{notification} - Run `velero #{event.resource.kind.downcase} describe #{event.resource.metadata.name} --details` for more information.",
      color: phase =~ /failed/i ? 'danger' : 'good'
    }

    slack_notifier.post at: at, attachments: [attachment]
  rescue StandardError => e
    logger.error "Something went wrong with the Slack notification: #{e.notification}"
  end

  def send_email_notification(event:, notification:)
    return unless ENV.fetch('ENABLE_EMAIL_NOTIFICATIONS', 'false') =~ /true/i

    mail = Mail.new do
      from    ENV['EMAIL_FROM_ADDRESS']
      to      ENV['EMAIL_TO_ADDRESS']
      subject notification
      body    "Run `velero #{event.resource.kind.downcase} describe #{event.resource.metadata.name} --details` for more information."
    end

    mail.deliver!
  rescue StandardError => e
    logger.error "Something went wrong with the email notification: #{e.notification}"
  end
end

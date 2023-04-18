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
require_relative 'event'

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
    @kubernetes_client = Kubernetes::Client.new
    @namespace = ENV.fetch('VELERO_NAMESPACE', 'velero')
    @resource_version = {}
    @slack_notifier = create_slack_notifier
  end

  def start
    $stdout.sync = true

    resource_version[:backups] = backups_resource_version
    resource_version[:restores] = restores_resource_version

    Thread.new { watch_resources :backups }.join
    Thread.new { watch_resources :restores }.join
  end

  private

  attr_reader :logger, :slack_notifier, :namespace, :kubernetes_client, :resource_version

  def backups_resource_version
    kubernetes_client
      .api('velero.io/v1')
      .resource('backups', namespace:)
      .meta_list
      .metadata
      .resourceVersion
  end

  def restores_resource_version
    kubernetes_client
      .api('velero.io/v1')
      .resource('restores', namespace:)
      .meta_list
      .metadata
      .resourceVersion
  end

  def watch_resources(resource_type)
    logger.info "Watching #{resource_type}..."

    kubernetes_client.api('velero.io/v1').resource(resource_type.to_s, namespace:).watch(timeout: TIMEOUT, resourceVersion: resource_version[resource_type]) do |event|
      Event.new(event:, logger:).notify
      resource_version[resource_type] = event.resource.metadata.resourceVersion
    end
  rescue EOFError, Excon::Error::Socket => e
    logger.info "Connection to API lost: #{e.message}"
    logger.info 'Reconnecting to API...'
    retry
  end

  def create_slack_notifier
    Slack::Notifier.new(ENV.fetch('SLACK_WEBHOOK', nil)) do
      defaults channel: ENV.fetch('SLACK_CHANNEL', nil), username: ENV.fetch('SLACK_USERNAME', 'Velero')
    end
  end
end

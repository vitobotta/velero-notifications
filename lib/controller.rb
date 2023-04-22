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
    @resource_versions = {}
    @slack_notifier = create_slack_notifier
    @release_namespace = ENV.fetch('RELEASE_NAMESPACE', 'velero')
  end

  def start
    $stdout.sync = true

    Thread.new { watch_resources :backups }.join
    Thread.new { watch_resources :restores }.join
  end

  private

  attr_reader :logger, :slack_notifier, :namespace, :kubernetes_client, :resource_versions, :release_namespace

  def last_resource_version(resource_type)
    resource_version = kubernetes_client.api('v1').resource('configmaps', namespace:).get("#{resource_type}-last-resource-version").data['resource-version']

    return resource_version if resource_version && resource_version != '0'

    resource_version = kubernetes_client
      .api('velero.io/v1')
      .resource(resource_type.to_s, namespace:)
      .meta_list
      .metadata
      .resourceVersion

    update_last_resource_version(resource_type, resource_version)

    resource_version
  end

  def watch_resources(resource_type)
    resource_versions[:backups] = last_resource_version(:backups)

    logger.info "Watching #{resource_type} (current resource version #{resource_versions[:backups]})..."

    kubernetes_client.api('velero.io/v1').resource(resource_type.to_s, namespace:).watch(timeout: TIMEOUT, resourceVersion: resource_versions[resource_type]) do |event|
      Event.new(event:, logger:, slack_notifier:).notify

      resource_version = event.resource.metadata.resourceVersion

      logger.info "Resource version for #{resource_type}: #{resource_version}"
      resource_versions[resource_type] = resource_version
      update_last_resource_version(resource_type, resource_version)
    end
  rescue EOFError, Excon::Error::Socket => e
    logger.info "Connection to API lost: #{e.message}"
    logger.info 'Reconnecting to API...'

    resource_versions[:backups] = last_resource_version(:backups)

    retry
  end

  def create_slack_notifier
    Slack::Notifier.new(ENV.fetch('SLACK_WEBHOOK', nil)) do
      defaults channel: ENV.fetch('SLACK_CHANNEL', nil), username: ENV.fetch('SLACK_USERNAME', 'Velero')
    end
  end

  def update_last_resource_version(resource_type, resource_version)
    patch = {
      data: {
        'resource-version': resource_version.to_s
      }
    }

    kubernetes_client.api('v1').resource('configmaps', namespace:).merge_patch("#{resource_type}-last-resource-version", patch)
  end
end

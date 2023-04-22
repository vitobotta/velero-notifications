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
    @resource_version = 0
    @slack_notifier = create_slack_notifier
    @release_namespace = ENV.fetch('RELEASE_NAMESPACE', 'velero')
  end

  def start
    $stdout.sync = true

    watch_backups
  end

  private

  attr_reader :logger, :slack_notifier, :namespace, :kubernetes_client, :resource_version, :release_namespace

  def last_resource_version
    @resource_version = kubernetes_client
      .api('v1')
      .resource('configmaps', namespace:)
      .get('backups-last-resource-version')
      .data['resource-version']

    return @resource_version if @resource_version && @resource_version != '0'

    @resource_version = kubernetes_client
      .api('velero.io/v1')
      .resource('backups', namespace:)
      .meta_list
      .metadata
      .resourceVersion
      .to_s

    update_configmap

    @resource_version
  end

  def watch_backups
    @resource_version = last_resource_version

    logger.info "Watching backups (current resource version #{resource_version})..."

    kubernetes_client.api('velero.io/v1').resource('backups', namespace:).watch(timeout: TIMEOUT, resourceVersion: resource_version) do |event|
      Event.new(event:, logger:, slack_notifier:).notify

      @resource_version = event.resource.metadata.resourceVersion
      update_configmap
    end
  rescue EOFError, Excon::Error::Socket => e
    logger.info "Connection to API lost: #{e.message}"
    logger.info 'Reconnecting to API...'

    @resource_version = last_resource_version

    retry
  end

  def create_slack_notifier
    Slack::Notifier.new(ENV.fetch('SLACK_WEBHOOK', nil)) do
      defaults channel: ENV.fetch('SLACK_CHANNEL', nil), username: ENV.fetch('SLACK_USERNAME', 'Velero')
    end
  end

  def update_configmap
    logger.info "Resource version for backups: #{resource_version}"

    patch = {
      data: {
        'resource-version': resource_version.to_s
      }
    }

    kubernetes_client.api('v1').resource('configmaps', namespace:).merge_patch('backups-last-resource-version', patch)
  end
end

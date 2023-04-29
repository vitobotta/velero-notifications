require "log"
require "kube-client/v1.26"
require "retriable"
require "./crds/velero/v1/backup_spec"
require "./crds/velero/v1/backup_status"
require "./crds/velero/v1/backup"
require "./crds/velero/v1/backup_list"
require "./event"

class Controller
  private getter api_client : Kube::Client
  private getter velero_namespace : String
  private getter release_namespace : String
  private getter resource_version : String

  def initialize
    @api_client = init_api_client
    @velero_namespace = ENV.fetch("VELERO_NAMESPACE", "velero")
    @release_namespace = ENV.fetch("RELEASE_NAMESPACE", "velero")
    @resource_version = "0"
  end

  def run
    Retriable.retry(on: [Exception], backoff: false) do
      watch_backups
    end
  end

  private def init_api_client : Kube::Client
    kubeconfig = ENV.fetch("KUBECONFIG", "")

    client = if kubeconfig.blank?
      Kube::Client.autoconfig
    else
      Kube::Client.config(
        Kube::Config.load_file(
          File.expand_path kubeconfig
        )
      )
    end

    client.apis(prefetch_resources: true)
    client
  end

  private def last_resource_version(reset = false)
    unless reset
      @resource_version = api_client.
        api("v1").
        resource("configmaps", namespace: release_namespace).
        get("backups-last-resource-version")["data"].
        as(Hash)["resourceVersion"].to_s

      return resource_version if resource_version && resource_version != "0"
    end

    @resource_version = api_client.
      api("velero.io/v1").
      resource("backups", namespace: velero_namespace).
      meta_list.not_nil!["metadata"].
      as(Hash)["resourceVersion"].to_s

    update_configmap

    @resource_version
  end

  private def watch_backups
    @resource_version = last_resource_version

    Log.info { "Watching backups from resource version #{resource_version}" }

    resource_client = api_client.
      api("velero.io/v1").
      resource("backups", namespace: velero_namespace)

    resource_client.watch(resource_version: resource_version, auto_resume: true) do |event|
      if event.is_a?(Kube::Error::WatchClosed)
        if event.resource_version
          @resource_version = event.resource_version.not_nil!
          update_configmap
        end

        channel = resource_client.watch(resource_version: event.resource_version)
      elsif event.is_a?(K8S::Kubernetes::WatchEvent(K8S::Velero::V1::Backup))
        Event.new(event).notify
        @resource_version = event.object["metadata"].as(Hash)["resourceVersion"].to_s
        update_configmap
      end
    end
  end

  private def update_configmap
    Log.info { "Resource version for backups: #{resource_version}" }

    patch = {
      data: {
        "resourceVersion": resource_version
      }
    }

    api_client.
      api("v1").
      resource("configmaps", namespace: release_namespace).
      merge_patch("backups-last-resource-version", patch)
  end
end

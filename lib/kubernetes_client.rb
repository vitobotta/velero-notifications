# frozen_string_literal: true

module Kubernetes
  class Client
    KUBE_CONFIG = ENV.fetch('KUBE_CONFIG', '')
    KUBE_HOST = ENV.fetch('KUBE_HOST', 'kubernetes.default.svc.cluster.local')
    KUBE_PORT = ENV.fetch('KUBE_PORT', '443')

    def initialize
      @client = if KUBE_CONFIG.empty?
                  K8s::Client.in_cluster_config
                else
                  K8s::Client.config(K8s::Config.load_file(KUBE_CONFIG), server: "https://#{KUBE_HOST}:#{KUBE_PORT}")
                end
    end

    private

    attr_reader :client

    def method_missing(method_name, *args)
      if client.respond_to?(method_name)
        client.send(method_name, *args)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      client.respond_to?(method) || super
    end
  end
end

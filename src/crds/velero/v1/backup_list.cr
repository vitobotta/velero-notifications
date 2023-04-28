# THIS FILE WAS AUTO GENERATED FROM THE K8S SWAGGER SPEC

require "yaml"
require "json"

::K8S::Kubernetes::Resource.define_resource("velero.io", "v1", "BackupList",
  namespace: "::K8S::Velero::V1",
  list: true,
  list_kind: K8S::Velero::V1::Backup,
  description: nil,
)

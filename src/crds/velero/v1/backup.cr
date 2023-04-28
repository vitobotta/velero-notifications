# THIS FILE WAS AUTO GENERATED FROM THE K8S SWAGGER SPEC

require "yaml"
require "json"

::K8S::Kubernetes::Resource.define_resource("velero.io", "v1", "Backup",
  namespace: "::K8S::Velero::V1",
  properties: [

    {name: "spec", kind: ::K8S::Velero::V1::BackupSpec, key: "spec", nilable: true, read_only: false, description: nil},
    {name: "status", kind: ::K8S::Velero::V1::BackupStatus, key: "status", nilable: true, read_only: false, description: nil},

  ],
  description: "Backup is a Velero resource that represents the capture of Kubernetes cluster state at a point in time (API objects and associated volume state).",
  versions: [{group: "velero.io", kind: "Backup", version: "v1"}],
)

# THIS FILE WAS AUTO GENERATED FROM THE K8S SWAGGER SPEC

require "yaml"
require "json"

::K8S::Kubernetes::Resource.define_object("BackupStatus",
  namespace: "::K8S::Velero::V1",
  properties: [

    {name: "backup_item_operations_attempted", kind: Int32, key: "backupItemOperationsAttempted", nilable: true, read_only: false, description: "BackupItemOperationsAttempted is the total number of attempted async BackupItemAction operations for this backup."},
    {name: "backup_item_operations_completed", kind: Int32, key: "backupItemOperationsCompleted", nilable: true, read_only: false, description: "BackupItemOperationsCompleted is the total number of successfully completed async BackupItemAction operations for this backup."},
    {name: "backup_item_operations_failed", kind: Int32, key: "backupItemOperationsFailed", nilable: true, read_only: false, description: "BackupItemOperationsFailed is the total number of async BackupItemAction operations for this backup which ended with an error."},
    {name: "completion_timestamp", kind: String, key: "completionTimestamp", nilable: true, read_only: false, description: "CompletionTimestamp records the time a backup was completed. Completion time is recorded even on failed backups. Completion time is recorded before uploading the backup object. The server's time is used for CompletionTimestamps"},
    {name: "csi_volume_snapshots_attempted", kind: Int32, key: "csiVolumeSnapshotsAttempted", nilable: true, read_only: false, description: "CSIVolumeSnapshotsAttempted is the total number of attempted CSI VolumeSnapshots for this backup."},
    {name: "csi_volume_snapshots_completed", kind: Int32, key: "csiVolumeSnapshotsCompleted", nilable: true, read_only: false, description: "CSIVolumeSnapshotsCompleted is the total number of successfully completed CSI VolumeSnapshots for this backup."},
    {name: "errors", kind: Int32, key: "errors", nilable: true, read_only: false, description: "Errors is a count of all error messages that were generated during execution of the backup.  The actual errors are in the backup's log file in object storage."},
    {name: "expiration", kind: String, key: "expiration", nilable: true, read_only: false, description: "Expiration is when this Backup is eligible for garbage-collection."},
    {name: "failure_reason", kind: String, key: "failureReason", nilable: true, read_only: false, description: "FailureReason is an error that caused the entire backup to fail."},
    {name: "format_version", kind: String, key: "formatVersion", nilable: true, read_only: false, description: "FormatVersion is the backup format version, including major, minor, and patch version."},
    {name: "phase", kind: String, key: "phase", nilable: true, read_only: false, description: "Phase is the current state of the Backup."},
    {name: "progress", kind: ::Hash(String, Int32), key: "progress", nilable: true, read_only: false, description: "Progress contains information about the backup's execution progress. Note that this information is best-effort only -- if Velero fails to update it during a backup for any reason, it may be [inaccurate/stale.](inaccurate/stale.)"},
    {name: "start_timestamp", kind: String, key: "startTimestamp", nilable: true, read_only: false, description: "StartTimestamp records the time a backup was started. Separate from CreationTimestamp, since that value changes on restores. The server's time is used for StartTimestamps"},
    {name: "validation_errors", kind: ::Array(String), key: "validationErrors", nilable: true, read_only: false, description: "ValidationErrors is a slice of all validation errors (if applicable)."},
    {name: "version", kind: Int32, key: "version", nilable: true, read_only: false, description: "Version is the backup format major version. Deprecated: Please see FormatVersion"},
    {name: "volume_snapshots_attempted", kind: Int32, key: "volumeSnapshotsAttempted", nilable: true, read_only: false, description: "VolumeSnapshotsAttempted is the total number of attempted volume snapshots for this backup."},
    {name: "volume_snapshots_completed", kind: Int32, key: "volumeSnapshotsCompleted", nilable: true, read_only: false, description: "VolumeSnapshotsCompleted is the total number of successfully completed volume snapshots for this backup."},
    {name: "warnings", kind: Int32, key: "warnings", nilable: true, read_only: false, description: "Warnings is a count of all warning messages that were generated during execution of the backup. The actual warnings are in the backup's log file in object storage."},

  ]
)

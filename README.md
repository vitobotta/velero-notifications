# velero-notifications

This is a simple Kubernetes controller written in Ruby that sends email and/or Slack notifications when backups or restores are performed by [Velero](https://velero.io/) in a [Kubernetes](https://kubernetes.io/) cluster.

## Installation

- Clone the repo
- Install with Helm

```bash
helm install ./helm \
  --name velero-backup-notification \
  --namespace velero \
  --set velero_namespace=velero \
  --set notification_prefix="[Velero]"
  --set slack.enabled=true \
  --set slack.webhook=https://... \
  --set slack.channel=velero \
  --set slack.username=Velero \
  --set email.enabled=true \
  --set email.smtp.host=... \
  --set email.smtp.port=587 \
  --set email.smtp.username=... \
  --set email.smtp.password=... \
  --set email.from_address=... \
  --set email.to_address=... \
```

That's it! You should now receive notifications when a backup/restore is completed or fails.

## License

The project is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/vitobotta/velero-notifications)
![GitHub Release Date](https://img.shields.io/github/release-date/vitobotta/velero-notifications)
![GitHub last commit](https://img.shields.io/github/last-commit/vitobotta/velero-notifications)
![GitHub issues](https://img.shields.io/github/issues-raw/vitobotta/velero-notifications)
![GitHub pull requests](https://img.shields.io/github/issues-pr-raw/vitobotta/velero-notifications)
![GitHub](https://img.shields.io/github/license/vitobotta/velero-notifications)
![GitHub Discussions](https://img.shields.io/github/discussions/vitobotta/velero-notifications)
![GitHub top language](https://img.shields.io/github/languages/top/vitobotta/velero-notifications)

![GitHub forks](https://img.shields.io/github/forks/vitobotta/velero-notifications?style=social)
![GitHub Repo stars](https://img.shields.io/github/stars/vitobotta/velero-notifications?style=social)



# velero-notifications

This is a simple Kubernetes controller written in Crystal that sends Email/Slack/webhook notifications when backups are performed by [Velero](https://velero.io/) in a [Kubernetes](https://kubernetes.io/) cluster.



## Installation

- Clone the repo
- Install with Helm

```bash
helm upgrade --install \
  --namespace velero \
  --set velero_namespace=velero \
  --set notification_prefix="[Velero]" \
  --set slack.enabled=true \
  --set slack.failures_only=false \
  --set slack.webhook=https://... \
  --set slack.channel=velero \
  --set slack.username=Velero \
  --set email.enabled=true \
  --set email.failures_only=true \
  --set email.smtp.host=... \
  --set email.smtp.port=587 \
  --set email.smtp.username=... \
  --set email.smtp.password=... \
  --set email.from_address=... \
  --set email.to_address=...
  --set webhook.enabled=true \
  --set webhook.failures_only=false \
  --set webhook.url=https://... \
  velero-backup-notification ./helm
```

That's it! You should now receive notifications when a backup is completed or fails. It couldn't be simpler than that!

![Screenshot](screenshot.jpg?raw=true "Screenshot")

## License

[MIT License](https://github.com/vitobotta/velero-notifications/blob/main/LICENSE)



## Stargazers over time

[![Stargazers over time](https://starchart.cc/vitobotta/velero-notifications.svg)](https://starchart.cc/vitobotta/velero-notifications)

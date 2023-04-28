FROM scratch
COPY velero-notifications /
RUN chmod +x /velero-notifications
CMD ["/velero-notifications"]

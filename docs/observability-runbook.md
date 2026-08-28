# Observability Runbook

This runbook covers day-to-day Prometheus and Grafana usage for the click-counter app.

## Prerequisites
- AKS context is configured and points to the expected cluster.
- Monitoring namespace and stack are present.

## Verify Monitoring Health
```bash
kubectl get ns monitoring
kubectl get pods -n monitoring
kubectl get servicemonitor -n monitoring
```

## Port-Forward Commands
Use separate terminal tabs and keep them open while using dashboards.

### Grafana
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open: http://localhost:3000

Get admin password:
```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath={.data.admin-password} | base64 --decode
```

### Prometheus
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Open: http://localhost:9090/targets

### App endpoint (dev)
```bash
kubectl -n dev port-forward svc/click-counter 8080:80
```

Check metrics:
```bash
curl -s http://localhost:8080/metrics | head
```

## Confirm Target Is UP
```bash
kubectl get svc click-counter -n dev --show-labels
kubectl get endpoints click-counter -n dev -o wide
```

Prometheus API quick check:
```bash
curl -s "http://localhost:9090/api/v1/targets?state=active" | grep -i click-counter
```

## Grafana Query Cheatsheet

### Total requests
```promql
sum(click_counter_http_requests_total)
```

### Request rate (5m)
```promql
sum(rate(click_counter_http_requests_total[5m]))
```

### P95 latency (seconds)
```promql
histogram_quantile(0.95, sum by (le) (rate(click_counter_http_request_duration_seconds_bucket[5m])))
```

### Total clicks (all pods)
```promql
sum(click_counter_click_events_total)
```

### Clicks in last 5 minutes (rounded)
```promql
round(sum(increase(click_counter_click_events_total[5m])))
```

### Clicks in last 5 minutes by pod (debug)
```promql
sum by (pod) (increase(click_counter_click_events_total[5m]))
```

## Notes About Expected Behavior
- Two values can appear for click metrics because the app runs with two replicas.
- Decimal values from increase(...[5m]) are expected due to Prometheus range extrapolation.
- App click count resets can happen on pod restart because the app counter is in-memory.

## Common Troubleshooting
1. Target not visible in Prometheus targets page:
   - Confirm Service labels include app=click-counter.
   - Confirm ServiceMonitor exists in monitoring namespace.
   - Confirm Service has endpoints.
2. Grafana disconnects:
   - The port-forward terminal was closed or interrupted.
   - Restart port-forward in a dedicated terminal tab.
3. No data in last 5m panel:
   - Generate traffic by clicking the app button or posting to /count.
   - Wait one scrape interval and refresh.

# Monitoring

Prometheus and Grafana are installed from the upstream
`kube-prometheus-stack` chart. They are intentionally not dependencies of this
chart. The load-test chart owns only its exporters, monitoring CRs, alert
rules, and Grafana dashboards.

## Install the monitoring stack

The tested upstream chart version is `86.2.2`. The supplied values place
Prometheus, Grafana, Alertmanager, and the operator on `ebpf-bng-cp-01`, away
from the load-test dataplane.

Create the Grafana administrator secret:

```sh
kubectl --kubeconfig ~/ebpf-bng-kubeconfig \
  create namespace monitoring

kubectl --kubeconfig ~/ebpf-bng-kubeconfig \
  -n monitoring create secret generic monitoring-grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password='replace-with-a-long-random-password'
```

Install the upstream stack:

```sh
helm upgrade --install monitoring \
  oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack \
  --version 86.2.2 \
  --namespace monitoring \
  --values examples/kube-prometheus-stack-values.yaml \
  --wait \
  --timeout 15m
```

The example exposes Grafana on NodePort `30300` and Prometheus on `30900`.
Restrict both ports to the management network.

The Grafana dashboard sidecar searches all namespaces so it can discover this
chart's dashboard ConfigMap. The example also sets
`grafana.sidecar.skipTlsVerify: true` for MicroK8s API certificates that omit
the CA key-usage extension expected by newer Python/OpenSSL clients. This
affects only the sidecar's in-cluster Kubernetes API connection.

## Enable application monitoring

Install or upgrade the workload chart after the Prometheus Operator CRDs are
available:

```sh
helm upgrade --install upf-loadtest \
  oci://ghcr.io/infinitydon/travelping-upf-loadtest \
  --version 0.1.15 \
  --namespace upf-loadtest \
  --create-namespace \
  --reuse-values \
  --set monitoring.enabled=true \
  --wait \
  --timeout 10m
```

This enables:

- VPP's native Prometheus exporter on port `9482`.
- A TRex STL RPC exporter on port `9483`.
- Services and `ServiceMonitor` resources for both exporters.
- `PrometheusRule` alerts for exporter health, queue pressure, worker CPU,
  VPP receive misses, and no-buffer drops.
- The `Travelping UPF Load Test` Grafana dashboard.

The exporter containers request `100m` CPU each with matching limits. They
remain in the shared CPU pool; the VPP and TRex dataplane containers retain
their dynamically assigned exclusive CPUs.

## Metrics

TRex exports instantaneous PPS and L1/L2 bandwidth as well as cumulative
packet and byte counters. Important metrics include:

- `trex_port_tx_pps` and `trex_port_rx_pps`
- `trex_port_tx_l1_bps` and `trex_port_rx_l1_bps`
- `trex_port_tx_l2_bps` and `trex_port_rx_l2_bps`
- `trex_port_tx_packets_total` and `trex_port_rx_packets_total`
- `trex_cpu_util_percent` and `trex_worker_cpu_percent`
- `trex_queue_full_total`

VPP exports cumulative interface counters from `/run/vpp/stats.sock`.
Prometheus derives packet throughput and bandwidth with `rate()`:

```promql
rate(_if_rx_packets[30s])
rate(_if_tx_bytes[30s]) * 8 / 1e6
```

The second expression is interface receive throughput in Mbps. The
`ServiceMonitor` maps VPP's numeric interface indexes to the chart interface
names `n3`, `n4`, and `n6` through the `interface_name` label.

## Verify

```sh
kubectl --kubeconfig ~/ebpf-bng-kubeconfig \
  -n upf-loadtest get servicemonitor,prometheusrule

kubectl --kubeconfig ~/ebpf-bng-kubeconfig \
  -n upf-loadtest port-forward svc/upf-loadtest-travelping-upf-loadtest-trex-metrics 9483

curl http://127.0.0.1:9483/metrics
```

In Prometheus, query `trex_up` and `up{namespace="upf-loadtest"}`. Grafana's
dashboard sidecar discovers the dashboard ConfigMap from the workload
namespace automatically.

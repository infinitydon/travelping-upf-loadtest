# Travelping UPF load test

This chart targets the `ebpf-bng-node-01` VFIO layout defined in
`values.yaml`. It deploys Travelping UPG-VPP, TRex v3.06, and a patched
`pfcpsim` compatible with UPG-VPP v2. The simulator patch supplies Network
Instance IEs, corrects downlink matching and heartbeat handling, removes
invalid placeholder encapsulation, disables reporting rules that disrupt bulk
provisioning, and raises the test QER limits.

Source and release documentation:

- https://github.com/infinitydon/pfcpsim-travelping
- https://github.com/infinitydon/pfcpsim-travelping/releases/tag/v1.4.4-11

The chart and patched simulator image are public, so installation does not
require GHCR credentials.

## Install from GHCR

```sh
helm upgrade --install upf-loadtest \
  oci://ghcr.io/infinitydon/travelping-upf-loadtest \
  --version 0.1.9 \
  --namespace upf-loadtest \
  --create-namespace \
  --wait
```

To inspect the chart locally:

```sh
helm pull oci://ghcr.io/infinitydon/travelping-upf-loadtest \
  --version 0.1.9 \
  --untar
```

The test result is written to `/results/gtpu-uplink.json` in the TRex
`test-runner` container and is also printed to its logs.

The node uses kubelet CPU Manager `static` with reserved CPUs. Both
packet-processing pods have Guaranteed QoS and discover their exclusive
container cpusets at runtime; the chart does not contain host CPU IDs. The
entrypoints support both cgroup cpuset files and the process affinity exposed
by `/proc/self/status`.

- UPG-VPP requests 3 CPUs and assigns the first to its main thread and the
  remaining 2 to workers.
- TRex requests 6 CPUs and assigns the first to master, the second to latency,
  and the remaining 4 to dataplane workers.

TRex's four workers match the four virtio queues configured on both traffic
interfaces. VPP polls four RX/TX queues on N3 and N6. N4 uses one queue in
both VPP and the PFCP simulator because multiqueue virtio does not preserve
PFCP request/response delivery reliably on this path. Change CPU and queue
counts, not physical CPU IDs, when tuning the chart.

## Publish a release

Chart releases are immutable. Update `version` in `Chart.yaml`, commit the
change, and push a matching tag:

```sh
git tag chart-v0.1.1
git push origin main chart-v0.1.1
```

The GitHub Actions workflow validates the tag against `Chart.yaml`, packages
the chart, and publishes it to GHCR.

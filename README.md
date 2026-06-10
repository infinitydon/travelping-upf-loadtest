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
  --version 0.1.10 \
  --namespace upf-loadtest \
  --create-namespace \
  --wait
```

To inspect the chart locally:

```sh
helm pull oci://ghcr.io/infinitydon/travelping-upf-loadtest \
  --version 0.1.10 \
  --untar
```

The test result is written to `/results/gtpu-uplink.json` in the TRex
`test-runner` container and is also printed to its logs.

The node uses kubelet CPU Manager `static` with reserved CPUs. Both
packet-processing pods have Guaranteed QoS and discover their exclusive
container cpusets at runtime; the chart does not contain host CPU IDs. The
entrypoints support both cgroup cpuset files and the process affinity exposed
by `/proc/self/status`.

- UPG-VPP requests 8 CPUs and assigns the first to its main thread and the
  remaining 7 to workers.
- TRex requests 6 CPUs and assigns the first to master, the second to latency,
  and the remaining 4 to dataplane workers.

TRex's four workers match the four queues configured on both Intel VF traffic
interfaces. VPP uses separate Intel VFs for N3, N4, and N6, while PFCP-sim
receives the kernel-backed `enp6s0` peer through Multus. N4 uses one queue in
both VPP and the PFCP simulator. Change CPU and queue counts, not physical CPU
IDs, when tuning the chart.

The GTP-U profile assigns a deterministic outer UDP source port to each
simulated session. The destination remains UDP 2152. This supplies RSS entropy
so the Intel N3 VF distributes uplink traffic across its four receive queues.
N3 uses 4,096 RX descriptors per queue to absorb short scheduling bursts.

## Performance notes

The Intel interfaces in this topology are SR-IOV VFs backed by physical
Intel 700 Series NICs, rather than direct physical functions. In this
environment they were materially more performant than the earlier
Proxmox/QEMU virtio-net interfaces: the virtio path repeatedly saturated TRex
during a 600 Kpps, 300-second run, while the tuned Intel VF path completed
1.2 Mpps for 300 seconds with no TRex queue-full events and low packet loss.

The VPP interfaces use the DPDK `iAVF` driver. Runtime inspection confirms
active RSS, IPv4 receive checksum, scatter, IPv4/UDP/TCP transmit checksum,
and multi-segment transmit support. The gain is not solely an offload result:
the four-queue layout, per-session outer UDP source-port entropy, dynamic CPU
allocation, and the 4,096-descriptor N3 receive rings are also part of the
tested configuration.

TRex reports the VFs as `net_iavf`, enables multi-queue mode, and has AVX2
available in the guest. Its reduced CPU use is primarily attributable to
direct SR-IOV DMA and the DPDK vector data path instead of the former
virtio/QEMU software path. TRex still constructs and schedules every packet;
checksum offload does not make the NIC act as the traffic generator.

An A/B test at 1.2 Mpps and 96-byte frames showed:

- Four workers: 9-16% peak utilization per worker and no queue-full events.
- Two workers: 20-25% peak utilization per worker and no queue-full events.

The default remains four workers for higher-rate and burst headroom. For tests
that remain close to 1.2 Mpps, `trex.cpu.cores=2` and TRex CPU requests/limits
of `4` return two exclusive CPUs to Kubernetes without reducing the requested
rate.

Additional host-side checks cannot be enforced by this chart. Keep the Intel
PF NVM and `i40e` driver compatible and current, configure the PF MTU for any
jumbo-frame tests, disable pause/PFC unless it is intentionally under test,
and keep host housekeeping interrupts away from kubelet-exclusive CPUs. The
guest already exposes AVX2 and a single NUMA node; manual core pinning inside
the chart is neither needed nor desirable.

For uplink tests, the configured packet size is the outer N3 Ethernet frame
without FCS. VPP removes the 36-byte outer IPv4/UDP/GTP-U encapsulation before
transmitting on N6, so N6 bandwidth is expected to be lower than N3 bandwidth
even when packet forwarding is lossless. A 96-byte N3 frame becomes roughly a
60-byte N6 frame; at 1.2 Mpps their calculated L1 rates are approximately
1,152 Mbps and 768 Mbps, respectively.

## Publish a release

Chart releases are immutable. Update `version` in `Chart.yaml`, commit the
change, and push a matching tag:

```sh
git tag chart-v0.1.1
git push origin main chart-v0.1.1
```

The GitHub Actions workflow validates the tag against `Chart.yaml`, packages
the chart, and publishes it to GHCR.

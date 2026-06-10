# Travelping UPF load test

This chart targets the `ebpf-bng-node-01` VFIO layout defined in
`values.yaml`. It deploys Travelping UPG-VPP, TRex v3.06, and a patched
`pfcpsim` compatible with UPG-VPP v2. The simulator patch supplies Network
Instance IEs, corrects downlink matching and heartbeat handling, removes
invalid placeholder encapsulation, disables reporting rules that disrupt bulk
provisioning, and raises the test QER limits.

Source and release documentation:

- https://github.com/infinitydon/pfcpsim-travelping
- https://github.com/infinitydon/pfcpsim-travelping/releases/tag/v1.4.4-8

The chart and patched simulator image are public, so installation does not
require GHCR credentials.

## Install from GHCR

```sh
helm upgrade --install upf-loadtest \
  oci://ghcr.io/infinitydon/travelping-upf-loadtest \
  --version 0.1.2 \
  --namespace upf-loadtest \
  --create-namespace \
  --wait
```

To inspect the chart locally:

```sh
helm pull oci://ghcr.io/infinitydon/travelping-upf-loadtest \
  --version 0.1.2 \
  --untar
```

The test result is written to `/results/gtpu-uplink.json` in the TRex
`test-runner` container and is also printed to its logs.

## Publish a release

Chart releases are immutable. Update `version` in `Chart.yaml`, commit the
change, and push a matching tag:

```sh
git tag chart-v0.1.1
git push origin main chart-v0.1.1
```

The GitHub Actions workflow validates the tag against `Chart.yaml`, packages
the chart, and publishes it to GHCR.

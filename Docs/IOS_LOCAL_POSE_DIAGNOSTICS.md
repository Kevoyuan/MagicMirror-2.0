# iOS on-device pose delivery diagnostics

**Status:** Source implementation, not a measured iPhone benchmark.

## Why this exists

MagicMirror's camera frame, MediaPipe's asynchronous inference and the
Metal presentation can have different update rates. A render pipeline
compiling on an arm64 Simulator is NOT evidence that real-world tracking
meets our >=30 FPS or <=150ms movement-to-display targets.

The small local debug overlay is **hidden by default**. Tap the waveform
icon beside SEARCHING/TRACKING to show it. No account, camera recording,
network request or telemetry upload is involved.

## What the reported values actually mean

- **POSE FPS**: estimate derived from the average wall-clock interval
  between accepted, same-capture-frame MediaPipe **result callbacks**.
  It is not the camera sensor FPS, Metal redraw FPS, or display refresh.
- **p95 gap (ms)**: nearest-rank 95th percentile of the callback intervals
  currently retained in a maximum 120-sample window. It captures stalls,
  but does **not** measure camera-to-photon latency or human motion error.
- **Accepted frames**: number of accepted pose observations in the
  current session; resets when capture stops, user pauses or the subject
  disappears for too long.

The monitor uses the monotonic
`ProcessInfo.processInfo.systemUptime` clock **at pose callback receipt**,
never mixes pose-source PTS units with the process uptime clock. It also
validates strictly increasing pose timestamps to reject stale or
replayed results.

Metrics are published at most once every 1 second to avoid invalidating
the whole SwiftUI screen at camera frame rate. Long callback gaps >=2 s,
tracking loss and session interruption reset the sample window.

## Scope of the user-visible diagnostic

The indicator intentionally says "Local delivery estimate — not display
FPS or camera latency." This avoids overstating sample-only performance.
It is not a scientific acceptance result until run with a named physical
iPhone and a reproducible motion sequence.

### What still needs actual hardware

- End-to-end source camera timestamp -> inference -> Metal GPU submission
  -> real screen photon measurement, or an explicitly narrower surrogate.
- Measured body-motion onset to visibly aligned anatomy response p95.
- p50/p95 sustained camera source FPS, GPU frame time, thermal throttling,
  current draw and battery drain for >=10 minutes.
- Actual frame quality/occlusion under crouching, reaching and turning;
  no device performance values have been observed by this PR.

## Privacy & safety

The monitor stores a bounded array of up to 120 **time intervals only**.
It never stores people, body landmarks, video buffers, camera identifiers
or network URLs. The real camera and skeleton are strictly on device.
The rendered overlay remains an educational standard reference, not
medical imaging, X-ray or a measured reconstruction of someone's bones.

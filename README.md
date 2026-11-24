# opus-watch-units

Baseline snapshot of the **custom systemd units and scripts** running on an
AsteroidOS watch (OPPO Watch *beluga*, AsteroidOS 2.1, kernel 4.9.112) for the
OpusOS health/connectivity work — captured **before** a battery-trim pass, so the
pre-trim behaviour is recoverable.

## Provenance
Captured over ADB from the watch on **2026-11-24** (`systemctl cat` / file read),
verbatim. These are the *on-watch* copies as deployed, not the upstream build
sources (the daemon source lives in the OpusOS tree).

| Repo path | On-watch path | Role |
|---|---|---|
| `etc/systemd/system/opus-pulse.service` | `/etc/systemd/system/opus-pulse.service` | Runs `/usr/bin/opus-pulsed` (root, CAP_WAKE_ALARM): low-power HR + step sampling and upload. |
| `etc/systemd/system/pan-autoconnect.service` | `/etc/systemd/system/pan-autoconnect.service` | Supervises the Bluetooth-PAN reconnect watchdog. |
| `usr/local/bin/pan-autoconnect.sh` | `/usr/local/bin/pan-autoconnect.sh` | The watchdog: nudges ConnMan to re-attach the phone PAN, with hard backoff so it never churns Bluetooth. |

Not included: the compiled `/usr/bin/opus-pulsed` binary (build artifact) and any
keys — none of these files contain secrets.

## Why this snapshot exists
The watch currently discharges in ~a day. Measurement (same session) showed it
rarely suspends — a held upload wakelock plus a `performance` cpufreq governor
pinned at max — so a trim pass follows. Restoring any file here returns that piece
to its pre-trim state:

```sh
adb push etc/systemd/system/opus-pulse.service /etc/systemd/system/opus-pulse.service
adb push etc/systemd/system/pan-autoconnect.service /etc/systemd/system/pan-autoconnect.service
adb push usr/local/bin/pan-autoconnect.sh /usr/local/bin/pan-autoconnect.sh
adb shell 'chmod +x /usr/local/bin/pan-autoconnect.sh; systemctl daemon-reload; \
           systemctl restart opus-pulse.service pan-autoconnect.service'
```

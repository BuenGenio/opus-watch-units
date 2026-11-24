#!/bin/sh
# Gentle Bluetooth PAN reconnect watchdog for the AsteroidOS watch.
#
# ConnMan --autoconnect on a TRUSTED device already reconnects PAN when a paired phone
# comes into range — that path is event-driven and does NOT poll or churn Bluetooth.
# This watchdog only nudges the occasional case where ConnMan's first connect after a
# re-link stalls in the "failure" state.
#
# IMPORTANT: an earlier version ran `bluetoothctl connect <phone>` for every paired phone
# every 20s whenever bnep0 was down. When no phone was actually serving PAN (e.g. watch on
# the desk) that hammered the Bluetooth stack non-stop → constant connect/disconnect,
# battery drain and overheating. So here we NEVER force the classic link in a loop, we only
# ask ConnMan to connect, and we back off hard (up to 10 min) when nothing is serving PAN.

pan_services() {
    connmanctl services 2>/dev/null | grep -oE 'bluetooth_[0-9A-Fa-f]+_[0-9A-Fa-f]+'
}

# service id -> peer MAC, e.g. bluetooth_801D00AAA5CB_04292ECDCC58 -> 04:29:2E:CD:CC:58
svc_mac() {
    echo "$1" | sed -E 's/^bluetooth_[0-9A-Fa-f]+_//; s/(..)(..)(..)(..)(..)(..)/\1:\2:\3:\4:\5:\6/'
}

# Trust every paired phone ONCE at startup so BlueZ auto-reconnects it when in range.
# (Cheap, idempotent DBus call — not the per-loop `bluetoothctl connect` that churned.)
for svc in $(pan_services); do
    bluetoothctl trust "$(svc_mac "$svc")" >/dev/null 2>&1
done

backoff=60
while true; do
    if ! ip link show bnep0 >/dev/null 2>&1; then
        for svc in $(pan_services); do
            connmanctl connect "$svc" >/dev/null 2>&1
            ip link show bnep0 >/dev/null 2>&1 && break
        done
    fi

    if ip link show bnep0 >/dev/null 2>&1; then
        backoff=60                                   # connected: just monitor, cheaply
    else
        backoff=$(( backoff * 2 ))                   # nothing serving: back off hard so
        [ "$backoff" -gt 600 ] && backoff=600        # we never churn Bluetooth (10 min cap)
    fi
    sleep "$backoff"
done

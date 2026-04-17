# thingino-mqtt-ha-discovery

Automatic Home Assistant MQTT discovery for Thingino cameras. Dynamically detects camera capabilities (GPIO, PTZ, image controls, audio, motion, recording) and registers all entities in Home Assistant — no manual YAML configuration required.

## How it works

The script reads your camera's configuration directly from `/etc/thingino.json` and `/etc/prudynt.json`, detects available hardware (GPIOs, PTZ motors, supported image parameters), and publishes MQTT discovery messages to your Home Assistant broker. A companion wrapper script (`/usr/sbin/thingino-cmd`) handles all camera commands, keeping the MQTT payloads clean and JSON-safe.

Entities are named after your camera's hostname (e.g. `FloorCam Brightness`, `FloorCam Motion Detection`) and grouped as a single device in Home Assistant.

On every boot, the script re-publishes discovery messages automatically so your entities stay in sync.

## Prerequisites

- [Thingino firmware](https://github.com/themactep/thingino-firmware) installed on your camera
- MQTT broker (e.g. Mosquitto) accessible from both the camera and Home Assistant
- Home Assistant with the MQTT integration enabled
- MQTT Subscription configured on the camera (see below)

## Camera MQTT Subscription setup

In the Thingino Web UI, go to **Services → MQTT Subscriptions** and add a subscription:

| Field  | Value                |
|--------|----------------------|
| Topic  | `%hostname/cmd`      |
| QoS    | `0`                  |
| Action | `eval $MQTT_PAYLOAD` |

The topic `%hostname/cmd` uses your camera's hostname automatically (e.g. `FloorCam/cmd`). You can also use a custom name like `Cam01/cmd` — just make sure it ends in `/cmd` since the discovery script derives the entity prefix from it.

## Installation

SSH into your camera:

```sh
ssh root@YOUR_CAMERA_IP
```

The SSH password is the same as your Thingino Web UI login password.

Then run this single command:

```sh
wget -O /usr/sbin/thingino-ha-discovery.sh https://raw.githubusercontent.com/AsDinFlames/thingino-mqtt-ha-discovery/main/thingino-ha-discovery.sh \
  && chmod +x /usr/sbin/thingino-ha-discovery.sh \
  && /usr/sbin/thingino-ha-discovery.sh \
  && printf '#!/bin/sh\ncase "$1" in\n  start) sleep 10 && /usr/sbin/thingino-ha-discovery.sh &;;\nesac\n' > /etc/init.d/S99ha-discovery \
  && chmod +x /etc/init.d/S99ha-discovery
```

That's it. All entities will appear in Home Assistant automatically and re-register on every boot.

To re-run discovery manually at any time:

```sh
/usr/sbin/thingino-ha-discovery.sh
```

## Entities

The script dynamically publishes the following entities based on what your camera supports:

### Switches
- Privacy, IR Cut, IR Light 850nm, IR Light 940nm, White Light, Status LED
- Color Mode, Horizontal Flip, Vertical Flip
- Mic, Mic AGC, Mic HPF, Force Stereo
- Motion Detection
- Recording Ch0, Recording Ch1, Recording Autostart, Recording Cleanup
- Timelapse

### Buttons
- Day Mode, Night Mode, Reboot
- PTZ Left, Right, Up, Down *(if motors present)*
- PTZ Presets 0–7 Load, Save, Delete *(if presets supported)*

### Numbers (Sliders)
- Brightness, Contrast, Saturation, Sharpness, Hue
- AE Compensation, Backlight Compensation, Defog, DRC, Highlight Depress
- Denoise Spatial, Denoise Temporal, Max Analog Gain, Max Digital Gain
- WB Red Gain, WB Blue Gain
- Wide Dynamic Range, Tone, Noise Reduction *(via imaging CGI)*
- Mic Volume, Mic Gain, Mic Noise Suppression, Mic ALC Gain
- Mic AGC Compression, Mic AGC Target Level, Mic Bitrate
- Speaker Volume, Speaker Gain
- Motion Sensitivity, Motion Cooldown
- Clip Duration, Storage Limit, Min Free Space
- Timelapse Interval, Timelapse Retention
- Stream 0 Bitrate, Stream 1 Bitrate

### Selects
- Anti-Flicker (Auto / 50Hz / 60Hz)
- White Balance Mode
- Running Mode
- Mic Codec (AAC, G711A, G711U, G726, OPUS, PCM)
- Mic Sample Rate, Speaker Sample Rate

## Known limitations

- `mic_enabled` toggle crashes prudynt after 2 toggles — use the Reboot button to recover
- `ispmode` (ISP Day/Night) and `dpc_strength` are not supported by prudynt on this hardware
- Force Stereo toggle causes a brief audio glitch due to audio thread restart

## Compatibility

Tested on:
- Sonoff CAM-PT2 with [Thingino firmware](https://github.com/themactep/thingino-firmware)

Should work on any Thingino camera. GPIO-dependent entities (IR LEDs, Status LED) are only published if the corresponding GPIO is defined in `/etc/thingino.json`.

## Related

- [Thingino Firmware](https://github.com/themactep/thingino-firmware) — the open source firmware this project is built on
- [Thingino Documentation](https://thingino.com) — official Thingino docs

## License

MIT

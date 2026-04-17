# thingino-mqtt-ha-discovery

Automatic Home Assistant MQTT discovery for Thingino cameras. Dynamically detects camera capabilities (GPIO, PTZ, image controls, audio, motion, recording) and registers all entities in Home Assistant — no manual YAML configuration required.

## How it works

The script runs on the camera itself and:
- Reads the camera's configuration from `/etc/thingino.json` and `/etc/prudynt.json`
- Dynamically detects available hardware (GPIOs, PTZ motors, supported image parameters via prudyntctl and imaging CGI)
- Publishes MQTT discovery messages to Home Assistant
- Creates a companion wrapper script (`/usr/sbin/thingino-cmd`) that handles all camera commands

All entities are named after the camera's hostname and grouped as a single device in HA. An init.d script re-publishes discovery on every boot so entities stay in sync.

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

SSH into your camera — the password is the same as your Thingino Web UI login:

```sh
ssh root@YOUR_CAMERA_IP
```

The camera needs temporary internet access to download the script. Once installed, internet access can be blocked again.

Then run this single command:

```sh
curl -o /usr/sbin/thingino-ha-discovery.sh https://raw.githubusercontent.com/AsDinFlames/thingino-mqtt-ha-discovery/main/thingino-ha-discovery.sh \
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
- Motion Alarm (used with HA automation to play a sound on motion)

### Buttons
- Reboot, Stop Sound
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
- Day/Night Mode (day / night / auto)
- Anti-Flicker (Auto / 50Hz / 60Hz)
- White Balance Mode, Running Mode
- Mic Codec (AAC, G711A, G711U, G726, OPUS, PCM)
- Mic Sample Rate, Speaker Sample Rate
- Sound *(dynamic list of all .opus files in /usr/share/sounds/ — selecting plays the sound)*

## Motion Alarm Sound

The **Motion Alarm** switch and **Sound** select work together with a HA automation to play a sound on motion detection:

```yaml
alias: Camera Motion Alarm Sound
triggers:
  - entity_id: binary_sensor.YOUR_CAMERA_motion_alarm
    to: "on"
    trigger: state
conditions:
  - condition: state
    entity_id: switch.YOUR_CAMERA_alarm
    state: "on"
actions:
  - device_id: YOUR_DEVICE_ID
    domain: select
    entity_id: YOUR_SOUND_SELECT_ENTITY_ID
    type: select_option
    option: motiondetectionactivated.opus
mode: single
max_exceeded: silent
```

Replace the entity IDs with your actual values from HA.

## Known limitations

- `mic_enabled` toggle crashes prudynt after 2 toggles — use the Reboot button to recover. This is a prudynt bug.
- `ispmode` (ISP Day/Night) and `dpc_strength` are not supported by prudynt on this hardware.
- Force Stereo toggle causes a brief audio glitch due to audio thread restart.
- `motion.playonspeaker` appears unimplemented in current Thingino firmware.

## Compatibility

Tested on:
- Sonoff CAM-PT2 with [Thingino firmware](https://github.com/themactep/thingino-firmware)

Should work on any Thingino camera. GPIO-dependent entities are only published if the corresponding GPIO is defined in `/etc/thingino.json`.

## Status & Contributing

This script is currently hosted here and still under active development. A pull request to the [Thingino firmware](https://github.com/themactep/thingino-firmware) project is planned — the install path may change in the future.

Feedback, bug reports and contributions are very welcome — either here or in the Thingino GitHub!

## Related

- [Thingino Firmware](https://github.com/themactep/thingino-firmware) — the open source firmware this project is built on
- [Thingino Documentation](https://thingino.com) — official Thingino docs

## License

MIT

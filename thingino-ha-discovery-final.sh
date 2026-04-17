#!/bin/sh
# Thingino Home Assistant MQTT Auto-Discovery Script
# Strategy: all complex commands are wrapped in /usr/sbin/thingino-cmd.sh
# MQTT discovery only references simple commands without quote issues

# ============================================
# READ CONFIG
# ============================================
BROKER=$(jct /etc/thingino.json get mqtt_sub.host 2>/dev/null | tr -d '"')
PORT=$(jct /etc/thingino.json get mqtt_sub.port 2>/dev/null | tr -d '"')
MQUSER=$(jct /etc/thingino.json get mqtt_sub.username 2>/dev/null | tr -d '"')
MQPASS=$(jct /etc/thingino.json get mqtt_sub.password 2>/dev/null | tr -d '"')
TOPIC=$(jct /etc/thingino.json get mqtt_sub.subscriptions.0.topic 2>/dev/null | tr -d '"')
CAM=$(echo "$TOPIC" | sed 's|/cmd||')
TOKEN=$(cat /etc/thingino-api.key)
HOST=$(hostname)

DEVICE="{\"identifiers\":[\"$CAM\"],\"name\":\"$HOST\",\"model\":\"Thingino\",\"manufacturer\":\"Thingino\"}"

# ============================================
# CREATE WRAPPER SCRIPT ON CAM
# This avoids all JSON quoting issues
# ============================================
cat > /usr/sbin/thingino-cmd << 'WRAPPER'
#!/bin/sh
# Thingino command wrapper - called by HA via MQTT
# Usage: thingino-cmd <command> [args...]
TOKEN=$(cat /etc/thingino-api.key)
API="http://localhost/x/json-prudynt.cgi?token=$TOKEN"
SEND2="http://localhost/x/json-send2.cgi?token=$TOKEN"
RECORD="http://localhost/x/tool-record.cgi?token=$TOKEN"
IMAGING="http://localhost/x/json-imaging.cgi?token=$TOKEN"
MOUNT=$(jct /etc/prudynt.json get recorder.mount 2>/dev/null | tr -d '"')

CMD="$1"
VAL="$2"

case "$CMD" in
  # Image via prudyntctl
  brightness|contrast|saturation|sharpness|hue|ae_compensation|defog_strength|drc_strength|highlight_depress|sinter_strength|temper_strength|backlight_compensation|max_again|max_dgain|wb_rgain|wb_bgain)
    printf '{"image":{"%s":%s}}' "$CMD" "$VAL" | prudyntctl json -
    curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"action":{"save_config":null}}'
    ;;
  # Image boolean
  hflip_on)   printf '{"image":{"hflip":true}}'  | prudyntctl json - ;;
  hflip_off)  printf '{"image":{"hflip":false}}' | prudyntctl json - ;;
  vflip_on)   printf '{"image":{"vflip":true}}'  | prudyntctl json - ;;
  vflip_off)  printf '{"image":{"vflip":false}}' | prudyntctl json - ;;
  # Image selects
  anti_flicker|core_wb_mode|running_mode)
    printf '{"image":{"%s":%s}}' "$CMD" "$VAL" | prudyntctl json -
    curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"action":{"save_config":null}}'
    ;;
  # Imaging CGI
  wide_dynamic_range|tone|noise_reduction)
    curl -s "$IMAGING" -d "${CMD}=${VAL}"
    ;;
  # Audio numbers
  mic_vol|mic_gain|mic_noise_suppression|mic_alc_gain|mic_agc_compression_gain_db|mic_agc_target_level_dbfs|mic_bitrate|spk_vol|spk_gain)
    curl -s -X POST "$API" -H "Content-Type: application/json" \
      -d "{\"audio\":{\"${CMD}\":${VAL}},\"action\":{\"restart_thread\":4}}"
    ;;
  # Audio format/rate selects
  mic_format)
    curl -s -X POST "$API" -H "Content-Type: application/json" \
      -d "{\"audio\":{\"mic_format\":\"${VAL}\"},\"action\":{\"restart_thread\":4}}"
    ;;
  mic_sample_rate|spk_sample_rate)
    curl -s -X POST "$API" -H "Content-Type: application/json" \
      -d "{\"audio\":{\"${CMD}\":${VAL}},\"action\":{\"restart_thread\":4}}"
    ;;
  # Audio switches
  mic_on)    curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_enabled":true}}'  ;;
  mic_off)   curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_enabled":false}}' ;;
  mic_agc_on)  curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_agc_enabled":true},"action":{"restart_thread":4}}'  ;;
  mic_agc_off) curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_agc_enabled":false},"action":{"restart_thread":4}}' ;;
  mic_hpf_on)  curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_high_pass_filter":true},"action":{"restart_thread":4}}'  ;;
  mic_hpf_off) curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_high_pass_filter":false},"action":{"restart_thread":4}}' ;;
  stereo_on)   curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"force_stereo":true},"action":{"restart_thread":4}}'  ;;
  stereo_off)  curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"force_stereo":false},"action":{"restart_thread":4}}' ;;
  # Motion
  motion_on)  curl -s -X POST "$SEND2" -H "Content-Type: application/json" -d '{"motion":{"enabled":true}}'  ;;
  motion_off) curl -s -X POST "$SEND2" -H "Content-Type: application/json" -d '{"motion":{"enabled":false}}' ;;
  motion_sensitivity)
    curl -s -X POST "$SEND2" -H "Content-Type: application/json" -d "{\"motion\":{\"sensitivity\":${VAL}}}"
    ;;
  motion_cooldown)
    curl -s -X POST "$SEND2" -H "Content-Type: application/json" -d "{\"motion\":{\"cooldown_time\":${VAL}}}"
    ;;
  # Recording
  rec_ch0_on)  curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"mp4":{"start":{"channel":0}}}' ;;
  rec_ch0_off) curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"mp4":{"stop":{"channel":0}}}'  ;;
  rec_ch1_on)  curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"mp4":{"start":{"channel":1}}}' ;;
  rec_ch1_off) curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"mp4":{"stop":{"channel":1}}}'  ;;
  rec_autostart_on)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=video&vr_mount=${MOUNT}&vr_device_path=%25hostname&vr_filename=%25Y/%25m/%25d/%25H-%25M-%25S&vr_channel=0&vr_duration=60&vr_limit=15&vr_min_free_mb=500&vr_check_interval=60&vr_autostart=true&vr_cleanup_enabled=false"
    ;;
  rec_autostart_off)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=video&vr_mount=${MOUNT}&vr_device_path=%25hostname&vr_filename=%25Y/%25m/%25d/%25H-%25M-%25S&vr_channel=0&vr_duration=60&vr_limit=15&vr_min_free_mb=500&vr_check_interval=60&vr_autostart=false&vr_cleanup_enabled=false"
    ;;
  rec_cleanup_on)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=video&vr_mount=${MOUNT}&vr_device_path=%25hostname&vr_filename=%25Y/%25m/%25d/%25H-%25M-%25S&vr_channel=0&vr_duration=60&vr_limit=15&vr_min_free_mb=500&vr_check_interval=60&vr_autostart=false&vr_cleanup_enabled=true"
    ;;
  rec_cleanup_off)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=video&vr_mount=${MOUNT}&vr_device_path=%25hostname&vr_filename=%25Y/%25m/%25d/%25H-%25M-%25S&vr_channel=0&vr_duration=60&vr_limit=15&vr_min_free_mb=500&vr_check_interval=60&vr_autostart=false&vr_cleanup_enabled=false"
    ;;
  clip_duration)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=video&vr_mount=${MOUNT}&vr_device_path=%25hostname&vr_filename=%25Y/%25m/%25d/%25H-%25M-%25S&vr_channel=0&vr_duration=${VAL}&vr_limit=15&vr_min_free_mb=500&vr_check_interval=60&vr_autostart=false&vr_cleanup_enabled=false"
    ;;
  storage_limit)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=video&vr_mount=${MOUNT}&vr_device_path=%25hostname&vr_filename=%25Y/%25m/%25d/%25H-%25M-%25S&vr_channel=0&vr_duration=60&vr_limit=${VAL}&vr_min_free_mb=500&vr_check_interval=60&vr_autostart=false&vr_cleanup_enabled=false"
    ;;
  min_free_space)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=video&vr_mount=${MOUNT}&vr_device_path=%25hostname&vr_filename=%25Y/%25m/%25d/%25H-%25M-%25S&vr_channel=0&vr_duration=60&vr_limit=15&vr_min_free_mb=${VAL}&vr_check_interval=60&vr_autostart=false&vr_cleanup_enabled=false"
    ;;
  # Timelapse
  tl_on)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=timelapse&tl_enabled=true&tl_mount=${MOUNT}&tl_filepath=%25hostname/timelapses&tl_filename=%25Y%25m%25d/%25Y%25m%25dT%25H%25M%25S.jpg&tl_interval=1&tl_keep_days=7&tl_preset_enabled=false&tl_ircut=false&tl_ir850=false&tl_ir940=false&tl_white=false&tl_color=false"
    ;;
  tl_off)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=timelapse&tl_enabled=false&tl_mount=${MOUNT}&tl_filepath=%25hostname/timelapses&tl_filename=%25Y%25m%25d/%25Y%25m%25dT%25H%25M%25S.jpg&tl_interval=1&tl_keep_days=7&tl_preset_enabled=false&tl_ircut=false&tl_ir850=false&tl_ir940=false&tl_white=false&tl_color=false"
    ;;
  tl_interval)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=timelapse&tl_enabled=true&tl_mount=${MOUNT}&tl_filepath=%25hostname/timelapses&tl_filename=%25Y%25m%25d/%25Y%25m%25dT%25H%25M%25S.jpg&tl_interval=${VAL}&tl_keep_days=7&tl_preset_enabled=false&tl_ircut=false&tl_ir850=false&tl_ir940=false&tl_white=false&tl_color=false"
    ;;
  tl_retention)
    curl -s -X POST "$RECORD" -H "Content-Type: application/x-www-form-urlencoded" \
      -d "form=timelapse&tl_enabled=true&tl_mount=${MOUNT}&tl_filepath=%25hostname/timelapses&tl_filename=%25Y%25m%25d/%25Y%25m%25dT%25H%25M%25S.jpg&tl_interval=1&tl_keep_days=${VAL}&tl_preset_enabled=false&tl_ircut=false&tl_ir850=false&tl_ir940=false&tl_white=false&tl_color=false"
    ;;
  # Stream bitrate
  bitrate_0|bitrate_1)
    CH=$(echo "$CMD" | sed 's/bitrate_//')
    /sbin/imp-control bitrate "$CH" "$VAL"
    ;;
  *)
    echo "Unknown command: $CMD"
    exit 1
    ;;
esac
WRAPPER
chmod +x /usr/sbin/thingino-cmd

echo "Wrapper script created at /usr/sbin/thingino-cmd"

# ============================================
# HELPER FUNCTIONS
# ============================================

pub() {
  mosquitto_pub -h "$BROKER" -p "$PORT" -u "$MQUSER" -P "$MQPASS" -r -t "$1" -m "$2"
}

pub_state() {
  mosquitto_pub -h "$BROKER" -p "$PORT" -u "$MQUSER" -P "$MQPASS" -r -t "$CAM/state/$1" -m "$2"
}

has_gpio() {
  jct /etc/thingino.json get "gpio.$1" 2>/dev/null | grep -qv "Key.*not found"
}

pget() {
  jct /etc/prudynt.json get "$1" 2>/dev/null | tr -d '"'
}

pub_switch() {
  local uid="$1" name="$2" on="$3" off="$4"
  pub "homeassistant/switch/${CAM}_${uid}/config" \
    "{\"name\":\"$name\",\"unique_id\":\"${CAM}_${uid}\",\"command_topic\":\"$TOPIC\",\"payload_on\":\"$on\",\"payload_off\":\"$off\",\"optimistic\":true,\"device\":$DEVICE}"
  echo "  [switch] $name"
}

pub_button() {
  local uid="$1" name="$2" payload="$3"
  pub "homeassistant/button/${CAM}_${uid}/config" \
    "{\"name\":\"$name\",\"unique_id\":\"${CAM}_${uid}\",\"command_topic\":\"$TOPIC\",\"payload_press\":\"$payload\",\"device\":$DEVICE}"
  echo "  [button] $name"
}

pub_number() {
  local uid="$1" name="$2" cmd="$3" min="$4" max="$5" step="$6" unit="$7" initial="$8"
  local extra=""
  [ -n "$unit" ] && extra=",\"unit_of_measurement\":\"$unit\""
  pub "homeassistant/number/${CAM}_${uid}/config" \
    "{\"name\":\"$name\",\"unique_id\":\"${CAM}_${uid}\",\"command_topic\":\"$TOPIC\",\"command_template\":\"$cmd\",\"state_topic\":\"$CAM/state/$uid\",\"min\":$min,\"max\":$max,\"step\":$step$extra,\"optimistic\":true,\"device\":$DEVICE}"
  [ -n "$initial" ] && pub_state "$uid" "$initial"
  echo "  [number] $name ($min-$max, default: $initial)"
}

pub_select() {
  local uid="$1" name="$2" cmd="$3" options="$4" initial="$5"
  pub "homeassistant/select/${CAM}_${uid}/config" \
    "{\"name\":\"$name\",\"unique_id\":\"${CAM}_${uid}\",\"command_topic\":\"$TOPIC\",\"command_template\":\"$cmd\",\"state_topic\":\"$CAM/state/$uid\",\"options\":$options,\"optimistic\":true,\"device\":$DEVICE}"
  [ -n "$initial" ] && pub_state "$uid" "$initial"
  echo "  [select] $name"
}

echo "Starting HA Discovery for $HOST ($CAM) -> $BROKER:$PORT"

# ============================================
# PRIVACY
# ============================================
echo "--- Privacy & Basic ---"
pub_switch "privacy" "$HOST Privacy" "/sbin/privacy on" "/sbin/privacy off"

# ============================================
# LIGHTS (GPIO-dependent)
# ============================================
echo "--- Lights ---"
has_gpio "ircut" && pub_switch "ircut" "$HOST IR Cut" "/sbin/ircut on" "/sbin/ircut off"
has_gpio "ir850" && pub_switch "ir_light" "$HOST IR Light 850nm" "/sbin/light ir850 on" "/sbin/light ir850 off"
has_gpio "ir940" && pub_switch "ir940" "$HOST IR Light 940nm" "/sbin/light ir940 on" "/sbin/light ir940 off"
has_gpio "white" && pub_switch "white_light" "$HOST White Light" "/sbin/light white on" "/sbin/light white off"
if has_gpio "led_b"; then
  LED_PIN=$(jct /etc/thingino.json get gpio.led_b.pin | tr -d '"')
  pub_switch "status_led" "$HOST Status LED" \
    "echo 1 > /sys/class/gpio/gpio${LED_PIN}/value" \
    "echo 0 > /sys/class/gpio/gpio${LED_PIN}/value"
fi

# ============================================
# COLOR & DAY/NIGHT
# ============================================
echo "--- Color/DayNight ---"
[ -x /sbin/color ] && pub_switch "color" "$HOST Color Mode" "/sbin/color on" "/sbin/color off"
[ -x /sbin/daynight ] && pub_button "day_mode" "$HOST Day Mode" "/sbin/daynight day"
[ -x /sbin/daynight ] && pub_button "night_mode" "$HOST Night Mode" "/sbin/daynight night"
pub_button "reboot" "$HOST Reboot" "reboot"

# ============================================
# PTZ
# ============================================
echo "--- PTZ ---"
if [ -x /usr/sbin/ptz-ctrl ]; then
  pub_button "ptz_left"  "$HOST PTZ Left"  "echo a | timeout 1 /usr/sbin/ptz-ctrl"
  pub_button "ptz_right" "$HOST PTZ Right" "echo d | timeout 1 /usr/sbin/ptz-ctrl"
  pub_button "ptz_up"    "$HOST PTZ Up"    "echo w | timeout 1 /usr/sbin/ptz-ctrl"
  pub_button "ptz_down"  "$HOST PTZ Down"  "echo s | timeout 1 /usr/sbin/ptz-ctrl"
fi
if [ -x /usr/sbin/ptz_presets ]; then
  for i in 0 1 2 3 4 5 6 7; do
    pub_button "preset_${i}_load"   "$HOST Preset $i Load"   "/usr/sbin/ptz_presets $i"
    pub_button "preset_${i}_save"   "$HOST Preset $i Save"   "/usr/sbin/ptz_presets -a $i Preset$i"
    pub_button "preset_${i}_delete" "$HOST Preset $i Delete" "/usr/sbin/ptz_presets -r $i"
  done
fi

# ============================================
# IMAGE CONTROLS
# Now using wrapper: thingino-cmd <field> {{ value | int }}
# ============================================
echo "--- Image Controls ---"

for field in brightness contrast saturation sharpness hue ae_compensation defog_strength drc_strength highlight_depress sinter_strength temper_strength; do
  val=$(pget "image.$field")
  [ -z "$val" ] && continue
  result=$(printf "{\"image\":{\"%s\":0}}" "$field" | prudyntctl json - 2>/dev/null)
  echo "$result" | grep -q "\"$field\"" || continue
  name=$(echo "$field" | sed 's/_/ /g')
  pub_number "${field}" "$HOST $name" "/usr/sbin/thingino-cmd $field {{ value | int }}" 0 255 1 "" "$val"
done

val=$(pget "image.backlight_compensation")
result=$(printf '{"image":{"backlight_compensation":0}}' | prudyntctl json - 2>/dev/null)
echo "$result" | grep -q "backlight_compensation" && \
  pub_number "backlight_compensation" "$HOST backlight compensation" "/usr/sbin/thingino-cmd backlight_compensation {{ value | int }}" 0 10 1 "" "${val:-0}"

val=$(pget "image.max_again")
result=$(printf '{"image":{"max_again":0}}' | prudyntctl json - 2>/dev/null)
echo "$result" | grep -q "max_again" && \
  pub_number "max_again" "$HOST max analog gain" "/usr/sbin/thingino-cmd max_again {{ value | int }}" 0 160 1 "" "${val:-160}"

val=$(pget "image.max_dgain")
result=$(printf '{"image":{"max_dgain":0}}' | prudyntctl json - 2>/dev/null)
echo "$result" | grep -q "max_dgain" && \
  pub_number "max_dgain" "$HOST max digital gain" "/usr/sbin/thingino-cmd max_dgain {{ value | int }}" 0 80 1 "" "${val:-80}"

for field in wb_rgain wb_bgain; do
  val=$(pget "image.$field")
  result=$(printf "{\"image\":{\"%s\":0}}" "$field" | prudyntctl json - 2>/dev/null)
  echo "$result" | grep -q "\"$field\"" || continue
  name=$(echo "$field" | sed 's/wb_rgain/WB Red Gain/;s/wb_bgain/WB Blue Gain/')
  pub_number "$field" "$HOST $name" "/usr/sbin/thingino-cmd $field {{ value | int }}" 0 255 1 "" "${val:-0}"
done

pub_switch "hflip" "$HOST Horizontal Flip" "/usr/sbin/thingino-cmd hflip_on" "/usr/sbin/thingino-cmd hflip_off"
pub_switch "vflip" "$HOST Vertical Flip" "/usr/sbin/thingino-cmd vflip_on" "/usr/sbin/thingino-cmd vflip_off"

# ============================================
# IMAGING CGI CONTROLS
# ============================================
echo "--- Imaging CGI Controls ---"
IMAGING_RESPONSE=$(curl -s "http://localhost/x/json-imaging.cgi?token=$TOKEN" 2>/dev/null)
for field in wide_dynamic_range tone noise_reduction; do
  supported=$(echo "$IMAGING_RESPONSE" | grep -o "\"$field\":{[^}]*}" | grep -oE '"supported": ?[a-z]+' | cut -d: -f2)
  [ "$supported" = "true" ] || continue
  min=$(echo "$IMAGING_RESPONSE" | grep -o "\"$field\":{[^}]*}" | grep -oE '"min": ?[0-9]+' | cut -d: -f2)
  max=$(echo "$IMAGING_RESPONSE" | grep -o "\"$field\":{[^}]*}" | grep -oE '"max": ?[0-9]+' | cut -d: -f2)
  default=$(echo "$IMAGING_RESPONSE" | grep -o "\"$field\":{[^}]*}" | grep -oE '"default": ?[0-9]+' | cut -d: -f2)
  name=$(echo "$field" | sed 's/_/ /g')
  pub_number "$field" "$HOST $name" "/usr/sbin/thingino-cmd $field {{ value | int }}" "${min:-0}" "${max:-255}" 1 "" "${default:-128}"
done

pub_select "anti_flicker" "$HOST Anti-Flicker" "/usr/sbin/thingino-cmd anti_flicker {{ value | int }}" \
  "[\"0\",\"1\",\"2\"]" "$(pget image.anti_flicker)"
pub_select "core_wb_mode" "$HOST White Balance Mode" "/usr/sbin/thingino-cmd core_wb_mode {{ value | int }}" \
  "[\"0\",\"1\",\"2\"]" "$(pget image.core_wb_mode)"
pub_select "running_mode" "$HOST Running Mode" "/usr/sbin/thingino-cmd running_mode {{ value | int }}" \
  "[\"0\",\"1\"]" "$(pget image.running_mode)"

# ============================================
# AUDIO CONTROLS
# ============================================
echo "--- Audio Controls ---"
pub_switch "mic"         "$HOST Mic"          "/usr/sbin/thingino-cmd mic_on"    "/usr/sbin/thingino-cmd mic_off"
pub_switch "mic_agc"     "$HOST Mic AGC"      "/usr/sbin/thingino-cmd mic_agc_on"  "/usr/sbin/thingino-cmd mic_agc_off"
pub_switch "mic_hpf"     "$HOST Mic HPF"      "/usr/sbin/thingino-cmd mic_hpf_on"  "/usr/sbin/thingino-cmd mic_hpf_off"
pub_switch "force_stereo" "$HOST Force Stereo" "/usr/sbin/thingino-cmd stereo_on"  "/usr/sbin/thingino-cmd stereo_off"

pub_number "mic_vol"                   "$HOST Mic Volume"          "/usr/sbin/thingino-cmd mic_vol {{ value | int }}"                   0  100 1 ""    "$(pget audio.mic_vol)"
pub_number "mic_gain"                  "$HOST Mic Gain"            "/usr/sbin/thingino-cmd mic_gain {{ value | int }}"                  0   31 1 ""    "$(pget audio.mic_gain)"
pub_number "mic_noise_suppression"     "$HOST Mic Noise Suppress"  "/usr/sbin/thingino-cmd mic_noise_suppression {{ value | int }}"     0    3 1 ""    "$(pget audio.mic_noise_suppression)"
pub_number "mic_alc_gain"              "$HOST Mic ALC Gain"        "/usr/sbin/thingino-cmd mic_alc_gain {{ value | int }}"              0    7 1 ""    "$(pget audio.mic_alc_gain)"
pub_number "mic_agc_compression_gain_db" "$HOST Mic AGC Compress"  "/usr/sbin/thingino-cmd mic_agc_compression_gain_db {{ value | int }}" 0 90 1 ""  "$(pget audio.mic_agc_compression_gain_db)"
pub_number "mic_agc_target_level_dbfs" "$HOST Mic AGC Target"      "/usr/sbin/thingino-cmd mic_agc_target_level_dbfs {{ value | int }}" 0   31 1 ""   "$(pget audio.mic_agc_target_level_dbfs)"
pub_number "mic_bitrate"               "$HOST Mic Bitrate"         "/usr/sbin/thingino-cmd mic_bitrate {{ value | int }}"               8  320 8 "kbps" "$(pget audio.mic_bitrate)"
pub_number "spk_vol"                   "$HOST Speaker Volume"      "/usr/sbin/thingino-cmd spk_vol {{ value | int }}"                   0  100 1 ""    "$(pget audio.spk_vol)"
pub_number "spk_gain"                  "$HOST Speaker Gain"        "/usr/sbin/thingino-cmd spk_gain {{ value | int }}"                  0   31 1 ""    "$(pget audio.spk_gain)"

pub_select "mic_format"     "$HOST Mic Codec"         "/usr/sbin/thingino-cmd mic_format {{ value }}" \
  "[\"AAC\",\"G711A\",\"G711U\",\"G726\",\"OPUS\",\"PCM\"]" "$(pget audio.mic_format)"
pub_select "mic_sample_rate" "$HOST Mic Sample Rate"  "/usr/sbin/thingino-cmd mic_sample_rate {{ value | int }}" \
  "[\"8000\",\"12000\",\"16000\",\"24000\",\"48000\"]" "$(pget audio.mic_sample_rate)"
pub_select "spk_sample_rate" "$HOST Speaker Sample Rate" "/usr/sbin/thingino-cmd spk_sample_rate {{ value | int }}" \
  "[\"8000\",\"12000\",\"16000\",\"24000\",\"48000\"]" "$(pget audio.spk_sample_rate)"

# ============================================
# MOTION DETECTION
# ============================================
echo "--- Motion Detection ---"
pub_switch "motion" "$HOST Motion Detection" "/usr/sbin/thingino-cmd motion_on" "/usr/sbin/thingino-cmd motion_off"
pub_number "motion_sensitivity" "$HOST Motion Sensitivity" "/usr/sbin/thingino-cmd motion_sensitivity {{ value | int }}" 1 8 1 "" "$(pget motion.sensitivity)"
pub_number "motion_cooldown"    "$HOST Motion Cooldown"    "/usr/sbin/thingino-cmd motion_cooldown {{ value | int }}"    1 60 1 "s" "$(pget motion.cooldown_time)"

# ============================================
# RECORDING
# ============================================
echo "--- Recording ---"
pub_switch "recording_ch0"      "$HOST Recording Ch0"      "/usr/sbin/thingino-cmd rec_ch0_on"       "/usr/sbin/thingino-cmd rec_ch0_off"
pub_switch "recording_ch1"      "$HOST Recording Ch1"      "/usr/sbin/thingino-cmd rec_ch1_on"       "/usr/sbin/thingino-cmd rec_ch1_off"
pub_switch "recording_autostart" "$HOST Recording Autostart" "/usr/sbin/thingino-cmd rec_autostart_on" "/usr/sbin/thingino-cmd rec_autostart_off"
pub_switch "recording_cleanup"  "$HOST Recording Cleanup"  "/usr/sbin/thingino-cmd rec_cleanup_on"   "/usr/sbin/thingino-cmd rec_cleanup_off"

pub_number "clip_duration"  "$HOST Clip Duration"   "/usr/sbin/thingino-cmd clip_duration {{ value | int }}"  10  3600 10  "s"  "$(pget recorder.duration)"
pub_number "storage_limit"  "$HOST Storage Limit"   "/usr/sbin/thingino-cmd storage_limit {{ value | int }}"   1   128  1  "GB" "$(pget recorder.limit)"
pub_number "min_free_space" "$HOST Min Free Space"  "/usr/sbin/thingino-cmd min_free_space {{ value | int }}" 100 2000 100 "MB" "$(pget recorder.min_free_mb)"

# ============================================
# TIMELAPSE
# ============================================
echo "--- Timelapse ---"
pub_switch "timelapse" "$HOST Timelapse" "/usr/sbin/thingino-cmd tl_on" "/usr/sbin/thingino-cmd tl_off"
pub_number "timelapse_interval"  "$HOST Timelapse Interval"  "/usr/sbin/thingino-cmd tl_interval {{ value | int }}"  1 60 1 "min"  "1"
pub_number "timelapse_retention" "$HOST Timelapse Retention" "/usr/sbin/thingino-cmd tl_retention {{ value | int }}" 1 30 1 "days" "7"

# ============================================
# STREAM BITRATE
# ============================================
echo "--- Stream ---"
pub_number "bitrate_0" "$HOST Stream 0 Bitrate" "/usr/sbin/thingino-cmd bitrate_0 {{ value | int }}" 256 8192 128 "kbps" "2048"
pub_number "bitrate_1" "$HOST Stream 1 Bitrate" "/usr/sbin/thingino-cmd bitrate_1 {{ value | int }}" 256 4096 128 "kbps" "1024"

echo ""
echo "HA Discovery complete! All entities published for $HOST"

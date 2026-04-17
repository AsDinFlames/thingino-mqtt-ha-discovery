#!/bin/sh
# Thingino Home Assistant MQTT Auto-Discovery Script
# Strategy: all complex commands are wrapped in /usr/sbin/thingino-cmd
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
# ============================================
cat > /usr/sbin/thingino-cmd << 'WRAPPER'
#!/bin/sh
TOKEN=$(cat /etc/thingino-api.key)
API="http://localhost/x/json-prudynt.cgi?token=$TOKEN"
SEND2="http://localhost/x/json-send2.cgi?token=$TOKEN"
RECORD="http://localhost/x/tool-record.cgi?token=$TOKEN"
IMAGING="http://localhost/x/json-imaging.cgi?token=$TOKEN"
MOUNT=$(jct /etc/prudynt.json get recorder.mount 2>/dev/null | tr -d '"')
CMD="$1"
VAL="$2"

case "$CMD" in
  brightness|contrast|saturation|sharpness|hue|ae_compensation|defog_strength|drc_strength|highlight_depress|sinter_strength|temper_strength|backlight_compensation|max_again|max_dgain|wb_rgain|wb_bgain)
    printf '{"image":{"%s":%s}}' "$CMD" "$VAL" | prudyntctl json -
    curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"action":{"save_config":null}}'
    ;;
  hflip_on)   printf '{"image":{"hflip":true}}'  | prudyntctl json - ;;
  hflip_off)  printf '{"image":{"hflip":false}}' | prudyntctl json - ;;
  vflip_on)   printf '{"image":{"vflip":true}}'  | prudyntctl json - ;;
  vflip_off)  printf '{"image":{"vflip":false}}' | prudyntctl json - ;;
  anti_flicker|core_wb_mode|running_mode)
    printf '{"image":{"%s":%s}}' "$CMD" "$VAL" | prudyntctl json -
    curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"action":{"save_config":null}}'
    ;;
  wide_dynamic_range|tone|noise_reduction)
    curl -s "$IMAGING" -d "${CMD}=${VAL}"
    ;;
  mic_vol|mic_gain|mic_noise_suppression|mic_alc_gain|mic_agc_compression_gain_db|mic_agc_target_level_dbfs|mic_bitrate|spk_vol|spk_gain)
    curl -s -X POST "$API" -H "Content-Type: application/json" \
      -d "{\"audio\":{\"${CMD}\":${VAL}},\"action\":{\"restart_thread\":4}}"
    ;;
  mic_format)
    curl -s -X POST "$API" -H "Content-Type: application/json" \
      -d "{\"audio\":{\"mic_format\":\"${VAL}\"},\"action\":{\"restart_thread\":4}}"
    ;;
  mic_sample_rate|spk_sample_rate)
    curl -s -X POST "$API" -H "Content-Type: application/json" \
      -d "{\"audio\":{\"${CMD}\":${VAL}},\"action\":{\"restart_thread\":4}}"
    ;;
  mic_on)      curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_enabled":true}}'  ;;
  mic_off)     curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_enabled":false}}' ;;
  mic_agc_on)  curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_agc_enabled":true},"action":{"restart_thread":4}}'  ;;
  mic_agc_off) curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_agc_enabled":false},"action":{"restart_thread":4}}' ;;
  mic_hpf_on)  curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_high_pass_filter":true},"action":{"restart_thread":4}}'  ;;
  mic_hpf_off) curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"mic_high_pass_filter":false},"action":{"restart_thread":4}}' ;;
  stereo_on)   curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"force_stereo":true},"action":{"restart_thread":4}}'  ;;
  stereo_off)  curl -s -X POST "$API" -H "Content-Type: application/json" -d '{"audio":{"force_stereo":false},"action":{"restart_thread":4}}' ;;
  motion_on)   curl -s -X POST "$SEND2" -H "Content-Type: application/json" -d '{"motion":{"enabled":true}}'  ;;
  motion_off)  curl -s -X POST "$SEND2" -H "Content-Type: application/json" -d '{"motion":{"enabled":false}}' ;;
  motion_sensitivity)
    curl -s -X POST "$SEND2" -H "Content-Type: application/json" -d "{\"motion\":{\"sensitivity\":${VAL}}}"
    ;;
  motion_cooldown)
    curl -s -X POST "$SEND2" -H "Content-Type: application/json" -d "{\"motion\":{\"cooldown_time\":${VAL}}}"
    ;;
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
  bitrate_0|bitrate_1)
    CH=$(echo "$CMD" | sed 's/bitrate_//')
    /sbin/imp-control bitrate "$CH" "$VAL"
    ;;
  daynight)
    curl -s -X POST "http://localhost/x/json-imp.cgi?token=$TOKEN" \
      -H "Content-Type: application/json" -d "{\"cmd\":\"daynight\",\"val\":\"${VAL}\"}"
    ;;
  color_on)
    curl -s -X POST "http://localhost/x/json-imp.cgi?token=$TOKEN" \
      -H "Content-Type: application/json" -d '{"cmd":"color","val":0}'
    ;;
  color_off)
    curl -s -X POST "http://localhost/x/json-imp.cgi?token=$TOKEN" \
      -H "Content-Type: application/json" -d '{"cmd":"color","val":1}'
    ;;
  play)
    play "$VAL"
    ;;
  play_stop)
    play stop
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
pub_switch "privacy" "Privacy" "/sbin/privacy on" "/sbin/privacy off"

# ============================================
# LIGHTS (GPIO-dependent)
# ============================================
echo "--- Lights ---"
has_gpio "ircut" && pub_switch "ircut" "IR Cut" "/sbin/ircut on" "/sbin/ircut off"
has_gpio "ir850" && pub_switch "ir_light" "IR Light 850nm" "/sbin/light ir850 on" "/sbin/light ir850 off"
has_gpio "ir940" && pub_switch "ir940" "IR Light 940nm" "/sbin/light ir940 on" "/sbin/light ir940 off"
has_gpio "white" && pub_switch "white_light" "White Light" "/sbin/light white on" "/sbin/light white off"
if has_gpio "led_b"; then
  LED_PIN=$(jct /etc/thingino.json get gpio.led_b.pin | tr -d '"')
  pub_switch "status_led" "Status LED" \
    "echo 1 > /sys/class/gpio/gpio${LED_PIN}/value" \
    "echo 0 > /sys/class/gpio/gpio${LED_PIN}/value"
fi

# ============================================
# COLOR & DAY/NIGHT
# ============================================
echo "--- Color/DayNight ---"
pub_switch "color" "Color Mode" "/usr/sbin/thingino-cmd color_on" "/usr/sbin/thingino-cmd color_off"
pub_select "daynight_mode" "Day/Night Mode" "/usr/sbin/thingino-cmd daynight {{ value }}" \
  "[\"day\",\"night\",\"auto\"]" "auto"
pub_button "reboot" "Reboot" "reboot"

# ============================================
# PTZ
# ============================================
echo "--- PTZ ---"
if [ -x /usr/sbin/ptz-ctrl ]; then
  pub_button "ptz_left"  "PTZ Left"  "echo a | timeout 1 /usr/sbin/ptz-ctrl"
  pub_button "ptz_right" "PTZ Right" "echo d | timeout 1 /usr/sbin/ptz-ctrl"
  pub_button "ptz_up"    "PTZ Up"    "echo w | timeout 1 /usr/sbin/ptz-ctrl"
  pub_button "ptz_down"  "PTZ Down"  "echo s | timeout 1 /usr/sbin/ptz-ctrl"
fi
if [ -x /usr/sbin/ptz_presets ]; then
  for i in 0 1 2 3 4 5 6 7; do
    pub_button "preset_${i}_load"   "Preset $i Load"   "/usr/sbin/ptz_presets $i"
    pub_button "preset_${i}_save"   "Preset $i Save"   "/usr/sbin/ptz_presets -a $i Preset$i"
    pub_button "preset_${i}_delete" "Preset $i Delete" "/usr/sbin/ptz_presets -r $i"
  done
fi

# ============================================
# IMAGE CONTROLS
# ============================================
echo "--- Image Controls ---"

for field in brightness contrast saturation sharpness hue ae_compensation defog_strength drc_strength highlight_depress sinter_strength temper_strength; do
  val=$(pget "image.$field")
  [ -z "$val" ] && continue
  name=$(echo "$field" | sed 's/_/ /g')
  pub_number "${field}" "$name" "/usr/sbin/thingino-cmd $field {{ value | int }}" 0 255 1 "" "$val"
done

val=$(pget "image.backlight_compensation")
[ -n "$val" ] && pub_number "backlight_compensation" "backlight compensation" \
  "/usr/sbin/thingino-cmd backlight_compensation {{ value | int }}" 0 10 1 "" "${val:-0}"

val=$(pget "image.max_again")
[ -n "$val" ] && pub_number "max_again" "max analog gain" \
  "/usr/sbin/thingino-cmd max_again {{ value | int }}" 0 160 1 "" "${val:-160}"

val=$(pget "image.max_dgain")
[ -n "$val" ] && pub_number "max_dgain" "max digital gain" \
  "/usr/sbin/thingino-cmd max_dgain {{ value | int }}" 0 80 1 "" "${val:-80}"

for field in wb_rgain wb_bgain; do
  val=$(pget "image.$field")
  [ -z "$val" ] && continue
  name=$(echo "$field" | sed 's/wb_rgain/WB Red Gain/;s/wb_bgain/WB Blue Gain/')
  pub_number "$field" "$name" "/usr/sbin/thingino-cmd $field {{ value | int }}" 0 255 1 "" "${val:-0}"
done

pub_switch "hflip" "Horizontal Flip" "/usr/sbin/thingino-cmd hflip_on" "/usr/sbin/thingino-cmd hflip_off"
pub_switch "vflip" "Vertical Flip"   "/usr/sbin/thingino-cmd vflip_on" "/usr/sbin/thingino-cmd vflip_off"

# ============================================
# IMAGING CGI CONTROLS
# ============================================
echo "--- Imaging CGI Controls ---"
IMAGING_RESPONSE=$(curl -s "http://localhost/x/json-imaging.cgi?token=$TOKEN" 2>/dev/null | tr -d "\n")
for field in wide_dynamic_range tone noise_reduction; do
  supported=$(echo "$IMAGING_RESPONSE" | grep -o "\"$field\":{[^}]*}" | grep -oE '"supported": ?[a-z]+' | cut -d: -f2 | tr -d " ")
  [ "$supported" = "true" ] || continue
  min=$(echo "$IMAGING_RESPONSE" | grep -o "\"$field\":{[^}]*}" | grep -oE '"min": ?[0-9]+' | cut -d: -f2 | tr -d " ")
  max=$(echo "$IMAGING_RESPONSE" | grep -o "\"$field\":{[^}]*}" | grep -oE '"max": ?[0-9]+' | cut -d: -f2 | tr -d " ")
  default=$(echo "$IMAGING_RESPONSE" | grep -o "\"$field\":{[^}]*}" | grep -oE '"default": ?[0-9]+' | cut -d: -f2 | tr -d " ")
  name=$(echo "$field" | sed 's/_/ /g')
  pub_number "$field" "$name" "/usr/sbin/thingino-cmd $field {{ value | int }}" "${min:-0}" "${max:-255}" 1 "" "${default:-128}"
done

pub_select "anti_flicker" "Anti-Flicker" "/usr/sbin/thingino-cmd anti_flicker {{ value | int }}" \
  "[\"0\",\"1\",\"2\"]" "$(pget image.anti_flicker)"
pub_select "core_wb_mode" "White Balance Mode" "/usr/sbin/thingino-cmd core_wb_mode {{ value | int }}" \
  "[\"0\",\"1\",\"2\"]" "$(pget image.core_wb_mode)"
pub_select "running_mode" "Running Mode" "/usr/sbin/thingino-cmd running_mode {{ value | int }}" \
  "[\"0\",\"1\"]" "$(pget image.running_mode)"

# ============================================
# AUDIO CONTROLS
# ============================================
echo "--- Audio Controls ---"
pub_switch "mic"          "Mic"          "/usr/sbin/thingino-cmd mic_on"     "/usr/sbin/thingino-cmd mic_off"
pub_switch "mic_agc"      "Mic AGC"      "/usr/sbin/thingino-cmd mic_agc_on" "/usr/sbin/thingino-cmd mic_agc_off"
pub_switch "mic_hpf"      "Mic HPF"      "/usr/sbin/thingino-cmd mic_hpf_on" "/usr/sbin/thingino-cmd mic_hpf_off"
pub_switch "force_stereo" "Force Stereo" "/usr/sbin/thingino-cmd stereo_on"  "/usr/sbin/thingino-cmd stereo_off"

pub_number "mic_vol"                     "Mic Volume"          "/usr/sbin/thingino-cmd mic_vol {{ value | int }}"                     0   100 1 ""     "$(pget audio.mic_vol)"
pub_number "mic_gain"                    "Mic Gain"            "/usr/sbin/thingino-cmd mic_gain {{ value | int }}"                    0    31 1 ""     "$(pget audio.mic_gain)"
pub_number "mic_noise_suppression"       "Mic Noise Suppress"  "/usr/sbin/thingino-cmd mic_noise_suppression {{ value | int }}"       0     3 1 ""     "$(pget audio.mic_noise_suppression)"
pub_number "mic_alc_gain"                "Mic ALC Gain"        "/usr/sbin/thingino-cmd mic_alc_gain {{ value | int }}"                0     7 1 ""     "$(pget audio.mic_alc_gain)"
pub_number "mic_agc_compression_gain_db" "Mic AGC Compress"    "/usr/sbin/thingino-cmd mic_agc_compression_gain_db {{ value | int }}" 0    90 1 ""     "$(pget audio.mic_agc_compression_gain_db)"
pub_number "mic_agc_target_level_dbfs"   "Mic AGC Target"      "/usr/sbin/thingino-cmd mic_agc_target_level_dbfs {{ value | int }}"   0    31 1 ""     "$(pget audio.mic_agc_target_level_dbfs)"
pub_number "mic_bitrate"                 "Mic Bitrate"         "/usr/sbin/thingino-cmd mic_bitrate {{ value | int }}"                 8   320 8 "kbps" "$(pget audio.mic_bitrate)"
pub_number "spk_vol"                     "Speaker Volume"      "/usr/sbin/thingino-cmd spk_vol {{ value | int }}"                     0   100 1 ""     "$(pget audio.spk_vol)"
pub_number "spk_gain"                    "Speaker Gain"        "/usr/sbin/thingino-cmd spk_gain {{ value | int }}"                    0    31 1 ""     "$(pget audio.spk_gain)"

pub_select "mic_format"      "Mic Codec"           "/usr/sbin/thingino-cmd mic_format {{ value }}" \
  "[\"AAC\",\"G711A\",\"G711U\",\"G726\",\"OPUS\",\"PCM\"]" "$(pget audio.mic_format)"
pub_select "mic_sample_rate" "Mic Sample Rate"     "/usr/sbin/thingino-cmd mic_sample_rate {{ value | int }}" \
  "[\"8000\",\"12000\",\"16000\",\"24000\",\"48000\"]" "$(pget audio.mic_sample_rate)"
pub_select "spk_sample_rate" "Speaker Sample Rate" "/usr/sbin/thingino-cmd spk_sample_rate {{ value | int }}" \
  "[\"8000\",\"12000\",\"16000\",\"24000\",\"48000\"]" "$(pget audio.spk_sample_rate)"

# ============================================
# MOTION DETECTION
# ============================================
echo "--- Motion Detection ---"
pub_switch "motion" "Motion Detection" "/usr/sbin/thingino-cmd motion_on" "/usr/sbin/thingino-cmd motion_off"
pub_number "motion_sensitivity" "Motion Sensitivity" "/usr/sbin/thingino-cmd motion_sensitivity {{ value | int }}" 1 8 1 "" "$(pget motion.sensitivity)"
pub_number "motion_cooldown"    "Motion Cooldown"    "/usr/sbin/thingino-cmd motion_cooldown {{ value | int }}"    1 60 1 "s" "$(pget motion.cooldown_time)"

# ============================================
# RECORDING
# ============================================
echo "--- Recording ---"
pub_switch "recording_ch0"       "Recording Ch0"       "/usr/sbin/thingino-cmd rec_ch0_on"       "/usr/sbin/thingino-cmd rec_ch0_off"
pub_switch "recording_ch1"       "Recording Ch1"       "/usr/sbin/thingino-cmd rec_ch1_on"       "/usr/sbin/thingino-cmd rec_ch1_off"
pub_switch "recording_autostart" "Recording Autostart" "/usr/sbin/thingino-cmd rec_autostart_on" "/usr/sbin/thingino-cmd rec_autostart_off"
pub_switch "recording_cleanup"   "Recording Cleanup"   "/usr/sbin/thingino-cmd rec_cleanup_on"   "/usr/sbin/thingino-cmd rec_cleanup_off"

pub_number "clip_duration"  "Clip Duration"  "/usr/sbin/thingino-cmd clip_duration {{ value | int }}"  10   3600  10 "s"  "$(pget recorder.duration)"
pub_number "storage_limit"  "Storage Limit"  "/usr/sbin/thingino-cmd storage_limit {{ value | int }}"   1    128   1 "GB" "$(pget recorder.limit)"
pub_number "min_free_space" "Min Free Space" "/usr/sbin/thingino-cmd min_free_space {{ value | int }}" 100  2000 100 "MB" "$(pget recorder.min_free_mb)"

# ============================================
# TIMELAPSE
# ============================================
echo "--- Timelapse ---"
pub_switch "timelapse" "Timelapse" "/usr/sbin/thingino-cmd tl_on" "/usr/sbin/thingino-cmd tl_off"
pub_number "timelapse_interval"  "Timelapse Interval"  "/usr/sbin/thingino-cmd tl_interval {{ value | int }}"  1 60 1 "min"  "1"
pub_number "timelapse_retention" "Timelapse Retention" "/usr/sbin/thingino-cmd tl_retention {{ value | int }}" 1 30 1 "days" "7"

# ============================================
# SOUNDS
# ============================================
echo "--- Sounds ---"

# Alarm switch - state stored as retained MQTT, used by HA automation
pub "homeassistant/switch/${CAM}_alarm/config" \
  "{\"name\":\"Motion Alarm\",\"unique_id\":\"${CAM}_alarm\",\"command_topic\":\"$CAM/alarm\",\"state_topic\":\"$CAM/alarm\",\"payload_on\":\"ON\",\"payload_off\":\"OFF\",\"device\":$DEVICE}"
mosquitto_pub -h "$BROKER" -p "$PORT" -u "$MQUSER" -P "$MQPASS" -r -t "$CAM/alarm" -m "OFF"
echo "  [switch] Motion Alarm"

# Stop sound button
pub_button "play_stop" "Stop Sound" "/usr/sbin/thingino-cmd play_stop"

# Dynamic sound list from /usr/share/sounds/
if [ -n "$(ls /usr/share/sounds/*.opus 2>/dev/null)" ]; then
  SOUND_OPTIONS="["
  first=1
  for sound in $(ls /usr/share/sounds/*.opus 2>/dev/null | xargs -I{} basename {}); do
    [ $first -eq 0 ] && SOUND_OPTIONS="${SOUND_OPTIONS},"
    SOUND_OPTIONS="${SOUND_OPTIONS}\"${sound}\""
    first=0
  done
  SOUND_OPTIONS="${SOUND_OPTIONS}]"
  FIRST_SOUND=$(ls /usr/share/sounds/*.opus 2>/dev/null | head -1 | xargs basename)
  pub_select "sound_select" "Sound" \
    "/usr/sbin/thingino-cmd play /usr/share/sounds/{{ value }}" \
    "$SOUND_OPTIONS" "$FIRST_SOUND"
fi

# ============================================
# STREAM BITRATE
# ============================================
echo "--- Stream ---"
pub_number "bitrate_0" "Stream 0 Bitrate" "/usr/sbin/thingino-cmd bitrate_0 {{ value | int }}" 256 8192 128 "kbps" "2048"
pub_number "bitrate_1" "Stream 1 Bitrate" "/usr/sbin/thingino-cmd bitrate_1 {{ value | int }}" 256 4096 128 "kbps" "1024"

echo ""
echo "HA Discovery complete! All entities published for $HOST"

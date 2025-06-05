#!/bin/bash

# ====== CONFIGURATION ======
INPUT_FILE="/home/ubuntu/Documents/VS_Code/Sopya_Git/EcourtSO/Ubuntu_Setting/IPlist.txt"
OUTPUT_DIR="/home/ubuntu/Documents/VS_Code/Sopya_Git/EcourtSO/Ubuntu_Setting/Taluka_court_ping_report"
PROFILE_TO_SET="CIS"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
OUTPUT_FILE="${OUTPUT_DIR}/court_ping_${TIMESTAMP}.txt"

# ====== SETUP ======
mkdir -p "$OUTPUT_DIR"  # Ensure output directory exists

# Save original profile
ORIGINAL_PROFILE=$(nmcli -t -f NAME,DEVICE connection show --active | head -n1 | cut -d: -f1)

echo "Original network profile: $ORIGINAL_PROFILE" | tee -a "$OUTPUT_FILE"
echo "Switching to profile: $PROFILE_TO_SET" | tee -a "$OUTPUT_FILE"

# Switch to CIS profile
nmcli connection up "$PROFILE_TO_SET" | tee -a "$OUTPUT_FILE"
if [ $? -ne 0 ]; then
  echo "Failed to switch to profile $PROFILE_TO_SET" | tee -a "$OUTPUT_FILE"
  exit 1
fi

echo "Pinging IPs from $INPUT_FILE ..." | tee -a "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Initialize counters and arrays
alive_count=0
unreachable_count=0
unreachable_courts=()

# ====== PING LOOP ======
while read -r line || [ -n "$line" ]; do
  # Extract IP and Court Name (space or tab separated)
  ip=$(echo "$line" | awk '{print $1}')
  name=$(echo "$line" | cut -d' ' -f2-)

  # Only ping if IP and name are present
  if [[ -n "$ip" && -n "$name" ]]; then
    if ping -c 1 -W 1 "$ip" &> /dev/null; then
      status="[✓]"
      reach="ALIVE"
      ((alive_count++))
    else
      status="[✗]"
      reach="UNREACHABLE"
      ((unreachable_count++))
      unreachable_courts+=("$name")
    fi

    now=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$now $status $name ($ip) is $reach" | tee -a "$OUTPUT_FILE"
  fi
done < "$INPUT_FILE"

# ====== RESTORE PROFILE ======
echo "" | tee -a "$OUTPUT_FILE"
echo "Restoring original profile: $ORIGINAL_PROFILE" | tee -a "$OUTPUT_FILE"
nmcli connection up "$ORIGINAL_PROFILE" | tee -a "$OUTPUT_FILE"

# ====== SUMMARY ======
echo "" | tee -a "$OUTPUT_FILE"
echo "========== SUMMARY ==========" | tee -a "$OUTPUT_FILE"
echo "Total ALIVE courts: $alive_count" | tee -a "$OUTPUT_FILE"
echo "Total UNREACHABLE courts: $unreachable_count" | tee -a "$OUTPUT_FILE"
if [ $unreachable_count -gt 0 ]; then
  echo "List of UNREACHABLE courts:" | tee -a "$OUTPUT_FILE"
  for court in "${unreachable_courts[@]}"; do
    echo "- $court" | tee -a "$OUTPUT_FILE"
  done
fi

echo "" | tee -a "$OUTPUT_FILE"
echo "✅ Ping test completed. Results saved in $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"


RECIPIENT="dcpuneping@gmail.com"
SUBJECT="Court Ping Report - $(date +'%Y-%m-%d %H:%M:%S')"
BODY="Please find the latest Court Ping Report attached."
ATTACHMENT="$OUTPUT_FILE"

echo "$BODY" | mutt -a "$ATTACHMENT" -s "$SUBJECT" -- "$RECIPIENT"

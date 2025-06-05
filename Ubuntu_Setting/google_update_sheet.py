import os
import glob
import datetime
import re
import gspread
from oauth2client.service_account import ServiceAccountCredentials
from gspread_formatting import CellFormat, Color, format_cell_range, set_column_width

# === CONFIGURATION ===
log_dir = "/home/ubuntu/Documents/VS_Code/Sopya_Git/EcourtSO/Ubuntu_Setting/Taluka_court_ping_report"
fallback_log_path = "/home/ubuntu/Documents/VS_Code/Sopya_Git/EcourtSO/Ubuntu_Setting/Taluka_court_ping_report/court_ping_2025-06-03-15-51-11.txt"
spreadsheet_title = "Pinging Status 2025"
credentials_file = "/home/ubuntu/Documents/DOC/MPLS_Link_data/credentials.json"

# === AUTHENTICATE GOOGLE SHEETS ===
scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]
creds = ServiceAccountCredentials.from_json_keyfile_name(credentials_file, scope)
client = gspread.authorize(creds)

# === OPEN OR CREATE SHEET ===
try:
    sheet = client.open(spreadsheet_title)
except gspread.exceptions.SpreadsheetNotFound:
    sheet = client.create(spreadsheet_title)
    sheet.share("dcpuneping@gmail.com", perm_type="user", role="writer")
    print(f"✅ Created spreadsheet: {sheet.url}")

# === FIND TODAY'S LOG FILE ===
today_str = datetime.date.today().strftime("%Y-%m-%d")
pattern = os.path.join(log_dir, f"court_ping_{today_str}*.txt")
log_files = sorted(glob.glob(pattern), key=os.path.getmtime)

if log_files:
    log_path = log_files[-1]
else:
    log_path = fallback_log_path
    if not os.path.exists(log_path):
        raise FileNotFoundError(f"No log file found for today and fallback is missing: {fallback_log_path}")

print(f"📄 Using log file: {log_path}")

# === DATE FORMATTING ===
date_obj = datetime.datetime.strptime(today_str, "%Y-%m-%d")
date_col = date_obj.strftime("%d-%b")     # e.g. "03-Jun"
month_name = date_obj.strftime("%B")      # e.g. "June"

# === PARSE LOG FILE ===
with open(log_path, "r") as f:
    log_data = f.read()

pattern = re.compile(r"\[([✓✗])\] (.+?) \((\d+\.\d+\.\d+\.\d+)\) is (ALIVE|UNREACHABLE)")
status_data = []
for m in pattern.finditer(log_data):
    _, court, ip, status_word = m.groups()
    status = "OK" if status_word == "ALIVE" else "FAULTY"
    status_data.append((court.strip(), ip, status))

status_data.sort(key=lambda x: x[0])

# === ACCESS OR CREATE MONTH SHEET ===
try:
    worksheet = sheet.worksheet(month_name)
except gspread.exceptions.WorksheetNotFound:
    worksheet = sheet.add_worksheet(title=month_name, rows="100", cols="40")
    worksheet.update("A1:C1", [["Court Name", "IP Address", date_col]])

data = worksheet.get_all_values()
if not data:
    data = [["Court Name", "IP Address", date_col]]

header = data[0]

# Ensure date column exists
if date_col not in header:
    header.append(date_col)
    for row in data[1:]:
        while len(row) < len(header):
            row.append("")

date_col_index = header.index(date_col)

# Build court name map
court_map = {row[0]: i+1 for i, row in enumerate(data[1:])}

# Update rows or append new
for court, ip, status in status_data:
    if court in court_map:
        row = data[court_map[court]]
        while len(row) < len(header):
            row.append("")
        if len(row) < 2 or not row[1]:
            row[1] = ip
        row[date_col_index] = status
    else:
        new_row = [court, ip] + [""] * (len(header) - 2)
        new_row[date_col_index] = status
        data.append(new_row)

# Final write to sheet
last_col_letter = chr(ord('A') + len(header) - 1)
worksheet.update(f"A1:{last_col_letter}{len(data)}", data)

# === FORMAT FAULTY CELLS ===
red_bg_format = CellFormat(backgroundColor=Color(1, 0.6, 0.6))
for i, row in enumerate(data[1:], start=2):
    if len(row) > date_col_index and row[date_col_index] == "FAULTY":
        col_letter = chr(ord('A') + date_col_index)
        format_cell_range(worksheet, f"{col_letter}{i}", red_bg_format)

# === COLUMN WIDTH ===
set_column_width(worksheet, "A", 200)
set_column_width(worksheet, "B", 150)
set_column_width(worksheet, chr(ord('A') + date_col_index), 100)

# === DONE ===
print(f"✅ Updated sheet '{spreadsheet_title}' → Tab '{month_name}' with column {date_col}")
print("🔗 Sheet URL:", sheet.url)

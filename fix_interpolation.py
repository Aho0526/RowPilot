import os
import re

loc_file = "/Users/kaitonakahira/Desktop/開発/RowPilot/Utilities/LocalizationManager.swift"
with open(loc_file, "r") as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if "MARK: - Auto Added" in line:
        new_lines.append(line)
        continue
    # if it's a dictionary entry and contains \(, skip it
    if re.match(r'^\s*".*":\s*\[\.japanese', line) and '\\(' in line:
        continue
    new_lines.append(line)

with open(loc_file, "w") as f:
    f.writelines(new_lines)

swift_files = []
for root, dirs, files in os.walk("/Users/kaitonakahira/Desktop/開発/RowPilot"):
    for file in files:
        if file.endswith(".swift") and "LocalizationManager.swift" not in file:
            swift_files.append(os.path.join(root, file))

for file in swift_files:
    with open(file, "r") as f:
        content = f.read()
    orig = content

    lines = content.split('\n')
    for i, line in enumerate(lines):
        if '.localized' in line and '\\(' in line:
            # We want to remove .localized if it follows a string with interpolation.
            # Just remove all .localized on this line.
            lines[i] = line.replace('".localized', '"')
                
    new_content = '\n'.join(lines)
    if new_content != orig:
        with open(file, "w") as f:
            f.write(new_content)

print("Fixed interpolations.")

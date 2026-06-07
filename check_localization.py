import os
import re

loc_file = "/Users/kaitonakahira/Desktop/開発/RowPilot/Utilities/LocalizationManager.swift"
with open(loc_file, "r") as f:
    loc_content = f.read()

# Extract keys from LocalizationManager.swift
# They look like: "Key": [.japanese: "...", .english: "..."]
keys_in_loc = set(re.findall(r'"((?:[^"\\]|\\.)*)":\s*\[\s*\.japanese', loc_content))

swift_files = []
for root, dirs, files in os.walk("/Users/kaitonakahira/Desktop/開発/RowPilot"):
    for file in files:
        if file.endswith(".swift"):
            swift_files.append(os.path.join(root, file))

# Regex for finding "..."
string_literal_re = re.compile(r'"((?:[^"\\]|\\.)*)"')

missing_from_loc = set()
unlocalized_japanese = set()

japanese_re = re.compile(r'[ぁ-んァ-ヶ一-龠]')

for file in swift_files:
    if "LocalizationManager.swift" in file:
        continue
    with open(file, "r") as f:
        content = f.read()
    
    # find all strings with .localized
    localized_calls = set(re.findall(r'"((?:[^"\\]|\\.)*)"\.localized', content))
    for k in localized_calls:
        if k not in keys_in_loc:
            missing_from_loc.add(k)
            
    # find all Text("...") where ... contains Japanese
    text_calls = re.findall(r'Text\(\s*"((?:[^"\\]|\\.)*)"\s*\)', content)
    for text in text_calls:
        if japanese_re.search(text):
            # check if it is not using .localized
            # Wait, the regex above only matches Text("...") exactly, so it doesn't match Text("...".localized)
            unlocalized_japanese.add(text)
            
    # Also find Label("...", systemImage: ...)
    label_calls = re.findall(r'Label\(\s*"((?:[^"\\]|\\.)*)"\s*,', content)
    for label in label_calls:
        if japanese_re.search(label):
            unlocalized_japanese.add(label)
            
    # Also find button titles Button("...")
    button_calls = re.findall(r'Button\(\s*"((?:[^"\\]|\\.)*)"\s*,', content)
    for button in button_calls:
        if japanese_re.search(button):
            unlocalized_japanese.add(button)
            
    button_calls_2 = re.findall(r'Button\(\s*"((?:[^"\\]|\\.)*)"\s*\)', content)
    for button in button_calls_2:
        if japanese_re.search(button):
            unlocalized_japanese.add(button)
            
    # Also navigation titles .navigationTitle("...")
    nav_calls = re.findall(r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"\s*\)', content)
    for nav in nav_calls:
        if japanese_re.search(nav):
            unlocalized_japanese.add(nav)

print("MISSING FROM LOC:")
for k in sorted(missing_from_loc):
    print(" - " + k)

print("\nUNLOCALIZED JAPANESE:")
for text in sorted(unlocalized_japanese):
    print(" - " + text)


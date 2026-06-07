import json
import re

with open("strings_to_add.json", "r") as f:
    strings_to_add = json.load(f)

loc_file = "/Users/kaitonakahira/Desktop/開発/RowPilot/Utilities/LocalizationManager.swift"
with open(loc_file, "r") as f:
    content = f.read()

# find the end of the dictionary
# it ends with `    ]`
# Let's search for `    ]\n\n    \n    \n    /// Get localized string`
# or just the last `    ]` before `/// Get localized string`

insert_idx = content.rfind("    ]\n")
if insert_idx == -1:
    insert_idx = content.rfind("    ]")

if insert_idx != -1:
    new_entries = "\n        // MARK: - Auto Added\n"
    for s in sorted(strings_to_add):
        # escape double quotes
        escaped_s = s.replace('"', '\\"')
        escaped_s = escaped_s.replace('\n', '\\n')
        new_entries += f'        "{escaped_s}": [.japanese: "{escaped_s}", .english: "{escaped_s}"],\n'
        
    content = content[:insert_idx] + new_entries + content[insert_idx:]
    with open(loc_file, "w") as f:
        f.write(content)
    print("Injected new translations.")
else:
    print("Could not find insertion point.")

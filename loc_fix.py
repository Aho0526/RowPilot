import os
import re

loc_file = "/Users/kaitonakahira/Desktop/開発/RowPilot/Utilities/LocalizationManager.swift"
with open(loc_file, "r") as f:
    loc_content = f.read()

keys_in_loc = set(re.findall(r'"((?:[^"\\]|\\.)*)":\s*\[\s*\.japanese', loc_content))
japanese_re = re.compile(r'[ぁ-んァ-ヶ一-龠]')

swift_files = []
for root, dirs, files in os.walk("/Users/kaitonakahira/Desktop/開発/RowPilot"):
    for file in files:
        if file.endswith(".swift"):
            swift_files.append(os.path.join(root, file))

strings_to_add = set()

for file in swift_files:
    if "LocalizationManager.swift" in file:
        continue
    with open(file, "r") as f:
        content = f.read()
    orig_content = content
    
    # 1. find already .localized but missing from loc
    localized_calls = re.findall(r'"((?:[^"\\]|\\.)*)"\.localized', content)
    for k in localized_calls:
        if k not in keys_in_loc:
            strings_to_add.add(k)
            
    # 2. replace and collect Text("XXX") -> Text("XXX".localized)
    def repl_text(m):
        s = m.group(1)
        if japanese_re.search(s):
            strings_to_add.add(s)
            return f'Text("{s}".localized)'
        return m.group(0)
    content = re.sub(r'Text\(\s*"((?:[^"\\]|\\.)*)"\s*\)', repl_text, content)
    
    # 3. Label("XXX",
    def repl_label(m):
        s = m.group(1)
        if japanese_re.search(s):
            strings_to_add.add(s)
            return f'Label("{s}".localized,'
        return m.group(0)
    content = re.sub(r'Label\(\s*"((?:[^"\\]|\\.)*)"\s*,', repl_label, content)
    
    # 4. Button("XXX",
    def repl_btn1(m):
        s = m.group(1)
        if japanese_re.search(s):
            strings_to_add.add(s)
            return f'Button("{s}".localized,'
        return m.group(0)
    content = re.sub(r'Button\(\s*"((?:[^"\\]|\\.)*)"\s*,', repl_btn1, content)
    
    # 5. Button("XXX")
    def repl_btn2(m):
        s = m.group(1)
        if japanese_re.search(s):
            strings_to_add.add(s)
            return f'Button("{s}".localized)'
        return m.group(0)
    content = re.sub(r'Button\(\s*"((?:[^"\\]|\\.)*)"\s*\)', repl_btn2, content)
    
    # 6. .navigationTitle("XXX")
    def repl_nav(m):
        s = m.group(1)
        if japanese_re.search(s):
            strings_to_add.add(s)
            return f'.navigationTitle("{s}".localized)'
        return m.group(0)
    content = re.sub(r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"\s*\)', repl_nav, content)
    
    # Special cases for SubscriptionView.swift
    if "SubscriptionView.swift" in file:
        def repl_return(m):
            s = m.group(1)
            if japanese_re.search(s):
                strings_to_add.add(s)
                return f'return "{s}".localized'
            return m.group(0)
        content = re.sub(r'return\s*"((?:[^"\\]|\\.)*)"', repl_return, content)
        
        def repl_tuple(m):
            s = m.group(1)
            if japanese_re.search(s):
                strings_to_add.add(s)
                return f'("{s}".localized,'
            return m.group(0)
        content = re.sub(r'\(\s*"((?:[^"\\]|\\.)*)"\s*,', repl_tuple, content)

    if orig_content != content:
        with open(file, "w") as f:
            f.write(content)

# Now prepare to insert `strings_to_add` into LocalizationManager.swift
import json
with open("strings_to_add.json", "w") as f:
    json.dump(list(strings_to_add), f, ensure_ascii=False, indent=2)

print(f"Found {len(strings_to_add)} new strings to localize.")

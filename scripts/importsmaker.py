import os
from collections import defaultdict

SOURCE_DIR = "../source"
OUTPUT_FILE = os.path.join(SOURCE_DIR, "import.hx")

groups = defaultdict(list)

for root, dirs, files in os.walk(SOURCE_DIR):
    for file in files:
        if not file.endswith(".hx"):
            continue

        if file == "import.hx":
            continue

        class_name = file[:-3]

        rel = os.path.relpath(root, SOURCE_DIR)

        if rel == ".":
            import_path = class_name
            group = "root"
        else:
            package = rel.replace(os.sep, ".")
            import_path = f"{package}.{class_name}"
            group = package

        groups[group].append(import_path)

for g in groups:
    groups[g].sort()

sorted_groups = sorted(groups.keys())

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write("// Auto-generated import from source folder\n\n")

    for group in sorted_groups:
        f.write(f"// {group}\n")

        for imp in groups[group]:
            f.write(f"import {imp};\n")

        f.write("\n")

print(f"Generated {OUTPUT_FILE}")
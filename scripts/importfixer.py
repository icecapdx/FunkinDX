import os
import re

SOURCE_DIR = "../source"

class_map = {}

for root, dirs, files in os.walk(SOURCE_DIR):
    for file in files:
        if file.endswith(".hx"):
            class_name = file[:-3]

            rel = os.path.relpath(root, SOURCE_DIR)
            if rel == ".":
                package = ""
            else:
                package = rel.replace(os.sep, ".")

            class_map[class_name] = package

import_regex = re.compile(r'^\s*import\s+([a-zA-Z0-9_.]+);', re.MULTILINE)

for root, dirs, files in os.walk(SOURCE_DIR):
    for file in files:
        if not file.endswith(".hx"):
            continue

        path = os.path.join(root, file)

        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        def fix_import(match):
            full_import = match.group(1)
            parts = full_import.split(".")

            base_class = parts[0]

            if base_class in class_map:
                correct_pkg = class_map[base_class]

                suffix = ""
                if len(parts) > 1:
                    suffix = "." + ".".join(parts[1:])

                if correct_pkg:
                    new_import = f"import {correct_pkg}.{base_class}{suffix};"
                else:
                    new_import = f"import {base_class}{suffix};"

                if new_import != match.group(0).strip():
                    print(f"{path}: {match.group(0).strip()} -> {new_import}")

                return new_import

            return match.group(0)

        new_content = import_regex.sub(fix_import, content)

        if new_content != content:
            with open(path, "w", encoding="utf-8") as f:
                f.write(new_content)
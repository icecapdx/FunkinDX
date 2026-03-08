import os
import re

SOURCE_DIR = "../source"

package_regex = re.compile(r'^\s*package\s*.*;', re.MULTILINE)

for root, dirs, files in os.walk(SOURCE_DIR):
    for file in files:
        if file.endswith(".hx"):
            filepath = os.path.join(root, file)
            rel_path = os.path.relpath(root, SOURCE_DIR)

            if rel_path == ".":
                package = ""
            else:
                package = rel_path.replace(os.sep, ".")

            if package:
                new_package_line = f"package {package};"
            else:
                new_package_line = "package;"

            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()

            if package_regex.search(content):
                new_content = package_regex.sub(new_package_line, content, count=1)
            else:
                new_content = new_package_line + "\n\n" + content

            if new_content != content:
                print(f"Fixing: {filepath} -> {new_package_line}")
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(new_content)

def save_and_load(lines, filename):
    with open(filename, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    with open(filename, "r", encoding="utf-8") as f:
        content = f.read()

    return content.splitlines()

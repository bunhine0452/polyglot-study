def summary(text):
    cleaned = text.strip()
    return f"[{cleaned.upper()}] len={len(cleaned)}"

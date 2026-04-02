#!/usr/bin/env python3
import argparse
import json
import os
import sys
from datetime import datetime
from urllib.parse import urlparse


def warn(message: str) -> None:
    print(f"Warning: {message}", file=sys.stderr)


def is_valid_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
    except Exception:
        return False
    return parsed.scheme in ("http", "https") and bool(parsed.netloc)


def validate_item(item, index: int):
    required_fields = ("date", "title", "category", "url")

    if not isinstance(item, dict):
        warn(f"news[{index}] is not an object; skipped")
        return None

    for field in required_fields:
        value = item.get(field)
        if not isinstance(value, str) or not value.strip():
            warn(f"news[{index}] has invalid or empty '{field}'; skipped")
            return None

    date_str = item["date"].strip()
    try:
        parsed_date = datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        warn(f"news[{index}] has invalid date format '{date_str}'; skipped")
        return None

    url = item["url"].strip()
    if not is_valid_url(url):
        warn(f"news[{index}] has invalid url '{url}'; skipped")
        return None

    return {
        "date": date_str,
        "title": item["title"].strip(),
        "category": item["category"].strip(),
        "url": url,
        "_parsed_date": parsed_date,
    }


def load_input(path: str):
    if not os.path.exists(path):
        print(f"Error: input file not found: {path}", file=sys.stderr)
        sys.exit(1)

    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as exc:
        print(f"Error: failed to parse JSON: {exc}", file=sys.stderr)
        sys.exit(1)
    except OSError as exc:
        print(f"Error: failed to read file: {exc}", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Format news JSON for spreadsheet input."
    )
    parser.add_argument("--input", required=True, help="Path to input JSON file")
    args = parser.parse_args()

    data = load_input(args.input)

    news = data.get("news")
    if not isinstance(news, list):
        print("Error: input JSON must contain a 'news' array", file=sys.stderr)
        sys.exit(1)

    valid_items = []
    for index, item in enumerate(news):
        validated = validate_item(item, index)
        if validated is not None:
            valid_items.append(validated)

    valid_items.sort(key=lambda x: x["_parsed_date"], reverse=True)
    valid_items = valid_items[:10]

    output = {
        "headers": ["日付", "タイトル", "カテゴリ", "URL"],
        "rows": [
            [item["date"], item["title"], item["category"], item["url"]]
            for item in valid_items
        ],
    }

    json.dump(output, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()

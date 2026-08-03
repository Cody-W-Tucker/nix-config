"""Miniflux auto-curator: title normalization helpers.

Separates the pure-text transformations that feed both reference
selection and entry scoring from the I/O and scoring concerns.
"""

import re

MIN_REFERENCE_TITLE_CHARS = 4
BARE_SOURCE_TITLES = {
    "x",
    "twitter",
    "threads",
    "facebook",
    "instagram",
    "linkedin",
    "reddit",
    "youtube",
    "medium",
    "substack",
    "mastodon",
    "bluesky",
    "bsky",
}


def normalize_title(title):
    """Remove conservative source-wrapper chrome from feed titles."""
    if not title:
        return ""

    normalized = re.sub(r"\s+", " ", str(title)).strip()
    normalized = strip_title_source_suffix(normalized)

    quoted = extract_wrapped_quoted_title(normalized)
    if quoted:
        normalized = strip_title_source_suffix(quoted)

    return normalized or str(title)


def strip_title_source_suffix(title):
    """Strip obvious trailing site markers without touching short titles."""
    stripped = title.strip()
    for separator in (" | ", " / ", " - "):
        if separator not in stripped:
            continue

        before, after = stripped.rsplit(separator, 1)
        before = before.strip()
        after = after.strip()
        if is_source_suffix(before, after, separator):
            return before

    return stripped


def is_source_suffix(title, suffix, separator):
    """Return True when suffix looks like publisher/source chrome."""
    if len(title) < 12 or not suffix or len(suffix) > 40:
        return False

    known_markers = {"x", "twitter"}
    if suffix.lower() in known_markers:
        return True

    looks_like_domain = re.fullmatch(
        r"[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+",
        suffix,
    )
    if looks_like_domain:
        return True

    source_words = suffix.split()
    source_like_words = all(
        re.fullmatch(r"[A-Z][A-Za-z0-9&.]*|[A-Z0-9&.]{2,}", word)
        for word in source_words
    )
    if not source_like_words:
        return False

    if separator in (" | ", " / "):
        return True

    return len(title) >= 30 and len(source_words) <= 4


def extract_wrapped_quoted_title(title):
    """Extract quoted content from clear attribution wrappers."""
    match = re.fullmatch(
        r"([^:]{1,120}):\s*[\"“”‘’'](.+?)[\"“”‘’']\s*",
        title,
    )
    if not match:
        return None

    prefix = match.group(1).strip()
    quoted = re.sub(r"\s+", " ", match.group(2)).strip()
    if len(quoted) < 12:
        return None

    attribution_cue = re.search(
        r"(@\w+|\b(on|via|from|at)\s+[A-Za-z0-9][\w .-]{0,40}$|"
        r"\b(posted|shared|wrote|writes|says)\b)",
        prefix,
        re.IGNORECASE,
    )
    if attribution_cue:
        return quoted

    return None


def is_good_reference_title(title):
    """Return True when a normalized bookmark title is worth embedding."""
    normalized = re.sub(r"\s+", " ", str(title or "")).strip()
    if not normalized:
        return False

    if normalized.startswith("GitHub - "):
        return False

    semantic_chars = re.sub(r"[^A-Za-z0-9]+", "", normalized)
    if len(semantic_chars) < MIN_REFERENCE_TITLE_CHARS:
        return False

    source_key = re.sub(r"[^A-Za-z0-9]+", "", normalized).lower()
    return source_key not in BARE_SOURCE_TITLES


def get_bookmark_reference_title(bookmark):
    """Return a normalized bookmark title only if it is safe as a reference."""
    content = bookmark.get("content")
    if isinstance(content, dict) and content.get("title"):
        title = normalize_title(content["title"])
    elif bookmark.get("title"):
        title = normalize_title(bookmark["title"])
    else:
        return ""

    if not is_good_reference_title(title):
        return ""
    return title


def build_bookmark_text(bookmark):
    """Build clean title-only embedding text for Karakeep references."""
    return get_bookmark_reference_title(bookmark)


def build_entry_text(entry):
    """Build clean title-only embedding text for unread Miniflux entries."""
    return normalize_title(entry.get("title"))


def get_bookmark_title(bookmark):
    """Return the best available bookmark title for logging/scoring reasons."""
    content = bookmark.get("content")
    if isinstance(content, dict) and content.get("title"):
        return normalize_title(content["title"])
    if bookmark.get("title"):
        return normalize_title(bookmark["title"])
    return "Untitled bookmark"


def get_tag_names(bookmark):
    """Extract tag names from Karakeep bookmark payloads."""
    names = []
    for tag in bookmark.get("tags") or []:
        if isinstance(tag, dict):
            name = tag.get("name")
        else:
            name = tag
        if name:
            names.append(str(name))
    return names

"""Conservative spoken-name suggestions; never silently select fuzzy matches."""
import re
from difflib import SequenceMatcher

from sqlalchemy import select

from app.models import Component


def spoken_tokens(text: str) -> list[str]:
    text = text.lower()
    text = re.sub(r"\bi\s+(?:to|two|2)\s+(?:see|sea|c)\b", "i2c", text)
    text = re.sub(r"\beye\s+(?:to|two)\s+see\b", "i2c", text)
    return [word for word in re.findall(r"[a-z0-9]+", text)
            if word not in {"a", "an", "the", "please", "find", "me"}]


def match_score(query: str, name: str) -> float:
    requested, candidate = spoken_tokens(query), spoken_tokens(name)
    if not requested or not candidate:
        return 0.0
    overlap = len(set(requested) & set(candidate)) / len(set(requested))
    similarity = SequenceMatcher(None, " ".join(requested), " ".join(candidate)).ratio()
    return 0.65 * overlap + 0.35 * similarity


def suggest_components(db, workspace_id: str, query: str) -> list[dict]:
    rows = db.execute(select(Component.name, Component.inventory_code, Component.part_number).where(
        Component.workspace_id == workspace_id,
        Component.is_archived.is_(False),
    ))
    matches = []
    for name, code, part_number in rows:
        score = max(match_score(query, value) for value in (name, code or "", part_number or ""))
        if score >= 0.55:
            matches.append({"part": name, "inventory_code": code, "score": round(score, 3)})
    return sorted(matches, key=lambda item: (-item["score"], item["part"], item["inventory_code"]))[:3]

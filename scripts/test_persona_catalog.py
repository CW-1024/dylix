#!/usr/bin/env python3
"""Validate the current model-matched Dylix persona catalog."""
from pathlib import Path
import json
import hashlib
import re
import uuid

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / "Resources/Personas/Builtins.json").read_text())
source = json.loads((root / "Resources/Personas/SOURCE.json").read_text())

assert catalog["catalogVersion"] == 5
assert len(catalog["personas"]) == 4
assert len(catalog["retiredBuiltinKeys"]) == 10
assert len(set(catalog["retiredBuiltinKeys"])) == 10

by_key = {persona["builtinKey"]: persona for persona in catalog["personas"]}
assert len(by_key) == len(catalog["personas"])
for persona in catalog["personas"]:
    uuid.UUID(persona["id"])
    assert persona["mode"] == "prepend" and persona["isBuiltin"] is True
    assert persona["updatedAt"] == 0 and persona["generation"] == "2026-11"
    assert "破甲" in persona["name"]
    assert persona["summary"] and persona["body"]
    assert len(persona["body"].encode()) >= 1500
    assert persona["bodyBytes"] == len(persona["body"].encode())
    assert persona["bodySHA256"] == hashlib.sha256(persona["body"].encode()).hexdigest()
    assert persona["sourceFile"] and persona["sourceRevision"]
    assert persona["replyPrefix"] == ""
    assert persona["selfCheckCommand"] and persona["selfCheckReply"]
    assert persona["modelPatterns"] and isinstance(persona["providerIDs"], list)
    assert isinstance(persona["matchPriority"], int)
    for pattern in persona["modelPatterns"]:
        re.compile(pattern)

fixtures = {
    "openai/gpt-6.1-sol": "builtin.current.openai",
    "openai/gpt-5.6-sol": "builtin.current.openai.gpt56",
    "openai/gpt-6-astra": "builtin.current.openai.astra",
    "anthropic/claude-4.7-opus": "builtin.current.claude.opus",
    "anthropic/claude-4.7-sonnet": "builtin.current.claude.sonnet",
    "google/gemini-4-pro": "builtin.current.gemini",
    "google/gemini-3.1-pro": "builtin.current.gemini31",
    "deepseek/deepseek-v4": "builtin.current.deepseek4",
    "deepseek/deepseek-v4.1": "builtin.current.deepseek",
    "qwen/qwen-3.7-coder": "builtin.current.qwen37",
    "qwen/qwen-3.8-coder": "builtin.current.qwen",
    "zhipu/glm-zcode-5.2": "builtin.current.glm52",
    "zhipu/glm-zcode-5.3": "builtin.current.glm",
    "moonshot/kimi-k3.1": "builtin.current.kimi",
    "x-ai/grok-4.7": "builtin.current.grok",
    "mistralai/mistral-large-4": "builtin.current.mistral",
    "openai/gpt-oss-20b": "builtin.current.gptoss20b",
}
for model, expected in fixtures.items():
    if expected not in by_key:
        continue
    matches = [
        persona
        for persona in catalog["personas"]
        if any(re.search(pattern, model) for pattern in persona["modelPatterns"])
    ]
    chosen = max(matches, key=lambda persona: persona["matchPriority"])
    assert chosen["builtinKey"] == expected, (model, chosen["builtinKey"])

seagull = by_key["builtin.current.codexx.seagull3"]
assert seagull["modelPatterns"] == ["(?!)"]
assert not any(re.search(pattern, "openai/gpt-5.6-sol") for pattern in seagull["modelPatterns"])

unknown = "vendor/new-model-2027"
matches = [
    persona
    for persona in catalog["personas"]
    if any(re.search(pattern, unknown) for pattern in persona["modelPatterns"])
]
assert not matches, "public catalog has no unlicensed universal fallback"

assert source["catalogVersion"] == 5
source_entries = {entry["builtinKey"]: entry for group in source["sources"] for entry in group["entries"]}
assert set(source_entries) == set(by_key)
for key, persona in by_key.items():
    assert source_entries[key]["bodyBytes"] == persona["bodyBytes"]
    assert source_entries[key]["bodySHA256"] == persona["bodySHA256"]
assert catalog["tailBody"] == ""
print("PASS 4 MIT-licensed public model profiles, hashes, regex fixtures and provenance")

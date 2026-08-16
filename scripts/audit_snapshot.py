#!/usr/bin/env python3
"""Trava fatos da validação total contra o código e trechos de docs.

Stdlib apenas. Não é Play: conta testes, lê catálogos Luau e recusa frases
documentais que já foram desmentidas pelo snapshot. Uso:

  python3 scripts/audit_snapshot.py --check
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT_PATH = ROOT / "docs" / "ci-snapshot.json"
NPCS_PATH = ROOT / "src" / "shared" / "Data" / "Npcs.luau"
AUDIO_PATH = ROOT / "src" / "shared" / "Data" / "CombatAudio.luau"
COMBAT_PATH = ROOT / "src" / "server" / "Services" / "CombatService.luau"
ABILITY_PATH = ROOT / "src" / "server" / "Services" / "AbilityService.luau"
BOOTSTRAP_PATH = ROOT / "src" / "server" / "init.server.lua"
AUDIO_BANK = ROOT / "assets" / "audio"

TEST_FILES = {
    "domain": ROOT / "tests" / "run.luau",
    "animation": ROOT / "tests" / "animation.luau",
    "combatE2e": ROOT / "tests" / "combat_e2e.luau",
}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_snapshot() -> dict:
    if not SNAPSHOT_PATH.is_file():
        fail(f"snapshot ausente: {SNAPSHOT_PATH.relative_to(ROOT)}")
    return json.loads(SNAPSHOT_PATH.read_text(encoding="utf-8"))


def count_test_calls(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    return len(re.findall(r"^test\(", text, flags=re.M))


def count_fuzz_cases(path: Path) -> int:
    """Cada caso do fuzz chama `check(` uma vez; loops `for x = 1, N` geram N."""
    lines = path.read_text(encoding="utf-8").splitlines()
    total = 0
    index = 0
    while index < len(lines):
        line = lines[index]
        stripped = line.strip()
        if line.startswith("local function "):
            index += 1
            while index < len(lines) and lines[index] != "end":
                index += 1
            index += 1
            continue
        for_match = re.match(r"^for\s+\w+\s*=\s*(\d+)\s*,\s*(\d+)\s+do\s*$", line)
        if for_match:
            total += int(for_match.group(2)) - int(for_match.group(1)) + 1
            index += 1
            while index < len(lines) and lines[index] != "end":
                index += 1
            index += 1
            continue
        if stripped.startswith("expectRejected(") or stripped.startswith("check("):
            total += 1
        index += 1
    return total


def npc_block(src: str, npc_id: str) -> str:
    match = re.search(rf"{re.escape(npc_id)}\s*=\s*\{{(.*?)\n\t\}}", src, flags=re.S)
    if not match:
        fail(f"NPC {npc_id} não encontrado em Npcs.luau")
    return match.group(1)


def npc_number(block: str, field: str) -> int:
    match = re.search(rf"{re.escape(field)}\s*=\s*(-?\d+)", block)
    if not match:
        fail(f"campo {field} ausente no bloco de NPC")
    return int(match.group(1))


def count_audio_cues(src: str) -> int:
    return len(re.findall(r"^\t[a-z0-9_]+ = cue\(\{", src, flags=re.M))


def count_audio_source_files(src: str) -> int:
    files: set[str] = set()
    for match in re.finditer(r'sourceFile = "([^"]+)"', src):
        files.add(match.group(1))
    for match in re.finditer(r'"((?:rpg-audio|impact-sounds|sci-fi-sounds|ui-audio)/Audio/[^"]+\.ogg)"', src):
        files.add(match.group(1))
    return len(files)


def count_kenney_ogg() -> int:
    if not AUDIO_BANK.is_dir():
        fail("banco de áudio ausente em assets/audio")
    return sum(1 for path in AUDIO_BANK.rglob("*.ogg") if path.is_file())


def require_contains(path: Path, needle: str) -> None:
    text = path.read_text(encoding="utf-8")
    if needle not in text:
        fail(f"{path.relative_to(ROOT)} deveria conter {needle!r}")


def forbid_contains(path: Path, needle: str) -> None:
    text = path.read_text(encoding="utf-8")
    if needle in text:
        fail(f"{path.relative_to(ROOT)} ainda contém frase obsoleta {needle!r}")


def check_tests(expected: dict) -> None:
    domain = count_test_calls(TEST_FILES["domain"])
    animation = count_test_calls(TEST_FILES["animation"])
    e2e = count_test_calls(TEST_FILES["combatE2e"])
    fuzz = count_fuzz_cases(ROOT / "tests" / "security_fuzz.luau")
    if domain != expected["domain"]:
        fail(f"testes de domínio: esperado {expected['domain']}, obtido {domain}")
    if animation != expected["animation"]:
        fail(f"testes de animação: esperado {expected['animation']}, obtido {animation}")
    if e2e != expected["combatE2e"]:
        fail(f"testes e2e: esperado {expected['combatE2e']}, obtido {e2e}")
    if fuzz != expected["fuzz"]:
        fail(f"casos de fuzz: esperado {expected['fuzz']}, obtido {fuzz}")
    total = domain + animation + fuzz + e2e
    if total != expected["total"]:
        fail(f"total de casos: esperado {expected['total']}, obtido {total}")


def check_npcs(expected: dict) -> None:
    src = NPCS_PATH.read_text(encoding="utf-8")
    for npc_id, fields in expected.items():
        block = npc_block(src, npc_id)
        for field, value in fields.items():
            got = npc_number(block, field)
            if got != value:
                fail(f"{npc_id}.{field}: esperado {value}, obtido {got}")


def check_audio(expected: dict) -> None:
    src = AUDIO_PATH.read_text(encoding="utf-8")
    cues = count_audio_cues(src)
    files = count_audio_source_files(src)
    oggs = count_kenney_ogg()
    if cues != expected["cues"]:
        fail(f"deixas de áudio: esperado {expected['cues']}, obtido {cues}")
    if files != expected["distinctSourceFiles"]:
        fail(f"ogg distintos no catálogo: esperado {expected['distinctSourceFiles']}, obtido {files}")
    if oggs != expected["kenneyOggOnDisk"]:
        fail(f"ogg no banco Kenney: esperado {expected['kenneyOggOnDisk']}, obtido {oggs}")
    placeholders = len(re.findall(r'assetId = RBX_', src))
    if expected["placeholderAssetIdsFilled"] and placeholders != expected["cues"]:
        fail(f"placeholders preenchidos: esperado {expected['cues']} deixas, obtido {placeholders}")


def check_combat(expected: dict) -> None:
    combat = COMBAT_PATH.read_text(encoding="utf-8")
    ability = ABILITY_PATH.read_text(encoding="utf-8")
    pulse = re.search(r"local PULSE_COUNTER_DAMAGE = (\d+)", combat)
    if not pulse or int(pulse.group(1)) != expected["pulseCounterDamage"]:
        fail(f"PULSE_COUNTER_DAMAGE esperado {expected['pulseCounterDamage']}")
    comet = re.search(r"applyHit\(target, now, (\d+), (\d+), (\d+), facing, true\)", combat)
    if not comet:
        fail("applyHit do Ombro Cometa não encontrado")
    if (
        int(comet.group(1)) != expected["cometOpenHp"]
        or int(comet.group(2)) != expected["cometGuardHp"]
        or int(comet.group(3)) != expected["cometBlockedHp"]
    ):
        fail(
            "Ombro Cometa fora do baseline "
            f"({expected['cometOpenHp']}/{expected['cometGuardHp']}/{expected['cometBlockedHp']})"
        )
    if f"applyCadenceHit(userId, target, {expected['cadenceFirst']}," not in ability:
        fail(f"Cadência golpe 1 deveria ser {expected['cadenceFirst']}")
    if f"applyCadenceHit(userId, target, {expected['cadenceSecond']}," not in ability:
        fail(f"Cadência golpe 2 deveria ser {expected['cadenceSecond']}")
    if f"applyCadenceHit(userId, target, {expected['cadenceEcho']}," not in ability:
        fail(f"Cadência eco deveria ser {expected['cadenceEcho']}")


def check_bootstrap(expected: dict) -> None:
    text = BOOTSTRAP_PATH.read_text(encoding="utf-8")
    present = "tryDummyAttack" in text
    if present != expected["heartbeatCallsTryDummyAttack"]:
        fail(
            "init.server.lua "
            + ("chama" if present else "não chama")
            + " tryDummyAttack; o snapshot espera "
            + str(expected["heartbeatCallsTryDummyAttack"])
        )


def check_docs(rules: dict) -> None:
    for relative, spec in rules.items():
        path = ROOT / relative
        if not path.is_file():
            fail(f"doc ausente: {relative}")
        for needle in spec.get("forbidden", []):
            forbid_contains(path, needle)
        for needle in spec.get("required", []):
            require_contains(path, needle)


def main() -> None:
    parser = argparse.ArgumentParser(description="Audita o snapshot canônico da validação total.")
    parser.add_argument("--check", action="store_true", help="falha se código ou docs divergirem do JSON")
    args = parser.parse_args()
    if not args.check:
        parser.print_help()
        raise SystemExit(2)

    snapshot = load_snapshot()
    check_tests(snapshot["tests"])
    check_npcs(snapshot["npcs"])
    check_audio(snapshot["audio"])
    check_combat(snapshot["combat"])
    check_bootstrap(snapshot["bootstrap"])
    check_docs(snapshot["docs"])
    print(
        "OK snapshot: "
        f"{snapshot['tests']['total']} casos, "
        f"{snapshot['audio']['cues']} deixas, "
        f"{snapshot['audio']['kenneyOggOnDisk']} ogg Kenney, "
        "dummy fora do Heartbeat"
    )


if __name__ == "__main__":
    main()

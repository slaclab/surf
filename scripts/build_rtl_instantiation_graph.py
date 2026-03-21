#!/usr/bin/env python3
##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

from __future__ import annotations

import argparse
import json
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path
import re


RE_ENTITY_DECL = re.compile(r"\bentity\s+(?P<name>[A-Za-z][A-Za-z0-9_]*)\s+is\b", re.IGNORECASE)
RE_ARCH_DECL = re.compile(
    r"\barchitecture\s+(?P<arch>[A-Za-z][A-Za-z0-9_]*)\s+of\s+(?P<entity>[A-Za-z][A-Za-z0-9_]*)\s+is\b",
    re.IGNORECASE,
)
RE_DIRECT_ENTITY_INST = re.compile(
    r":\s*entity\s+(?:(?P<library>[A-Za-z][A-Za-z0-9_]*)\.)?(?P<target>[A-Za-z][A-Za-z0-9_]*)(?:\s*\(|\s|$)",
    re.IGNORECASE,
)
RE_COMPONENT_INST = re.compile(
    r"^\s*(?P<label>[A-Za-z][A-Za-z0-9_]*)\s*:\s*(?P<target>[A-Za-z][A-Za-z0-9_]*)\b",
    re.IGNORECASE,
)

ARCH_BODY_SKIP_TOKENS = {
    "architecture",
    "assert",
    "block",
    "case",
    "component",
    "configuration",
    "entity",
    "for",
    "function",
    "if",
    "loop",
    "package",
    "procedure",
    "process",
    "record",
    "when",
    "while",
}

DEFAULT_SCAN_DIRS = ("base", "axi", "protocols", "ethernet", "devices", "xilinx")
EXCLUDED_PARTS = {"tb", "build", ".venv", "__pycache__"}


@dataclass(frozen=True)
class EntityDefinition:
    name: str
    path: str
    subsystem: str


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _strip_comments(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def _is_in_scope(path: Path) -> bool:
    return path.suffix.lower() == ".vhd" and not any(part in EXCLUDED_PARTS for part in path.parts)


def _discover_vhdl_files(repo_root: Path, scan_dirs: tuple[str, ...]) -> list[Path]:
    files: list[Path] = []
    for scan_dir in scan_dirs:
        for path in sorted((repo_root / scan_dir).rglob("*.vhd")):
            if _is_in_scope(path):
                files.append(path)
    return files


def _entity_definitions(repo_root: Path, files: list[Path]) -> dict[str, list[EntityDefinition]]:
    entities: dict[str, list[EntityDefinition]] = defaultdict(list)

    for path in files:
        text = _strip_comments(path.read_text(encoding="utf-8"))
        for match in RE_ENTITY_DECL.finditer(text):
            relative_path = path.relative_to(repo_root).as_posix()
            subsystem = path.relative_to(repo_root).parts[0]
            entities[match.group("name")].append(
                EntityDefinition(
                    name=match.group("name"),
                    path=relative_path,
                    subsystem=subsystem,
                )
            )

    return dict(sorted(entities.items()))


def _entity_instantiations(files: list[Path], known_entities: set[str]) -> dict[str, set[str]]:
    graph: dict[str, set[str]] = defaultdict(set)

    for path in files:
        text = _strip_comments(path.read_text(encoding="utf-8"))
        lines = text.splitlines()
        current_entity: str | None = None
        in_architecture_body = False

        for line in lines:
            arch_match = RE_ARCH_DECL.search(line)
            if arch_match:
                current_entity = arch_match.group("entity")
                in_architecture_body = False
                graph.setdefault(current_entity, set())
                continue

            if current_entity is None:
                continue

            if not in_architecture_body:
                if line.strip().lower() == "begin":
                    in_architecture_body = True
                continue

            direct_match = RE_DIRECT_ENTITY_INST.search(line)
            if direct_match:
                target = direct_match.group("target")
                if target in known_entities and target != current_entity:
                    graph[current_entity].add(target)
                continue

            component_match = RE_COMPONENT_INST.search(line)
            if component_match:
                target = component_match.group("target")
                # Component instantiations are ambiguous in plain text parsing, so
                # only count them when the target token matches a discovered entity.
                if target.lower() in ARCH_BODY_SKIP_TOKENS:
                    continue
                if target in known_entities and target != current_entity:
                    graph[current_entity].add(target)

    for entity in known_entities:
        graph.setdefault(entity, set())

    return dict(sorted((entity, set(sorted(targets))) for entity, targets in graph.items()))


def _reverse_graph(graph: dict[str, set[str]]) -> dict[str, set[str]]:
    reverse: dict[str, set[str]] = {entity: set() for entity in graph}
    for source, targets in graph.items():
        for target in targets:
            reverse.setdefault(target, set()).add(source)
    return reverse


def _topological_layers(graph: dict[str, set[str]]) -> list[list[str]]:
    indegree = {entity: 0 for entity in graph}
    for targets in graph.values():
        for target in targets:
            indegree[target] += 1

    queue = deque(sorted(entity for entity, degree in indegree.items() if degree == 0))
    layers: list[list[str]] = []

    while queue:
        layer = list(queue)
        layers.append(layer)
        queue.clear()
        next_layer: list[str] = []
        for entity in layer:
            for target in sorted(graph[entity]):
                indegree[target] -= 1
                if indegree[target] == 0:
                    next_layer.append(target)
        queue.extend(sorted(next_layer))

    if sum(len(layer) for layer in layers) != len(graph):
        remaining = sorted(entity for entity, degree in indegree.items() if degree > 0)
        if remaining:
            layers.append(remaining)

    return layers


def _suggest_bottom_up_candidates(
    entity_defs: dict[str, list[EntityDefinition]],
    graph: dict[str, set[str]],
    reverse_graph: dict[str, set[str]],
) -> list[dict[str, object]]:
    candidates: list[dict[str, object]] = []
    for entity, definitions in entity_defs.items():
        primary = definitions[0]
        if primary.subsystem != "base":
            continue

        fanout = len(graph.get(entity, set()))
        fanin = len(reverse_graph.get(entity, set()))
        # Candidate selection is intentionally broad within base/: inferred and
        # vendor-specific leaves are still useful rollout waypoints even when
        # they do not live under an rtl/ directory.
        if fanout == 0 and fanin > 0:
            candidates.append(
                {
                    "entity": entity,
                    "path": primary.path,
                    "instantiated_by_count": fanin,
                    "instantiates_count": fanout,
                }
            )

    candidates.sort(key=lambda item: (-item["instantiated_by_count"], item["entity"]))
    return candidates[:20]


def _graph_summary(
    entity_defs: dict[str, list[EntityDefinition]],
    graph: dict[str, set[str]],
    reverse_graph: dict[str, set[str]],
) -> dict[str, object]:
    duplicates = {
        entity: [definition.path for definition in definitions]
        for entity, definitions in entity_defs.items()
        if len(definitions) > 1
    }

    top_instantiated = sorted(
        (
            {
                "entity": entity,
                "instantiated_by_count": len(reverse_graph.get(entity, set())),
                "instantiates_count": len(graph.get(entity, set())),
                "path": entity_defs[entity][0].path,
            }
            for entity in entity_defs
        ),
        key=lambda item: (-item["instantiated_by_count"], item["entity"]),
    )[:20]

    top_assemblers = sorted(
        (
            {
                "entity": entity,
                "instantiates_count": len(graph.get(entity, set())),
                "instantiated_by_count": len(reverse_graph.get(entity, set())),
                "path": entity_defs[entity][0].path,
            }
            for entity in entity_defs
        ),
        key=lambda item: (-item["instantiates_count"], item["entity"]),
    )[:20]

    leaf_entities = sorted(
        (
            {
                "entity": entity,
                "instantiated_by_count": len(reverse_graph.get(entity, set())),
                "path": entity_defs[entity][0].path,
            }
            for entity in entity_defs
            if len(graph.get(entity, set())) == 0
        ),
        key=lambda item: (-item["instantiated_by_count"], item["entity"]),
    )[:20]

    return {
        "entity_count": len(entity_defs),
        "edge_count": sum(len(targets) for targets in graph.values()),
        "duplicate_entity_names": duplicates,
        "top_instantiated_entities": top_instantiated,
        "top_assemblers": top_assemblers,
        "top_leaf_entities": leaf_entities,
        "base_bottom_up_candidates": _suggest_bottom_up_candidates(entity_defs, graph, reverse_graph),
    }


def _write_json(
    output_path: Path,
    *,
    scan_dirs: tuple[str, ...],
    entity_defs: dict[str, list[EntityDefinition]],
    graph: dict[str, set[str]],
    reverse_graph: dict[str, set[str]],
) -> None:
    summary = _graph_summary(entity_defs, graph, reverse_graph)
    output = {
        "generated_from": {
            "scan_dirs": list(scan_dirs),
            "parser_scope": "VHDL entities outside tb/build/.venv paths",
            "parser_limitations": [
                "Package calls are not graph nodes.",
                "Direct entity instantiations are handled explicitly.",
                "Component-style instantiations are inferred only when the instantiated name matches a known entity name inside an architecture body.",
            ],
        },
        "summary": summary,
        "entities": [
            {
                "entity": entity,
                "paths": [definition.path for definition in definitions],
                "subsystem": definitions[0].subsystem,
                "instantiates": sorted(graph.get(entity, set())),
                "instantiated_by": sorted(reverse_graph.get(entity, set())),
                "instantiates_count": len(graph.get(entity, set())),
                "instantiated_by_count": len(reverse_graph.get(entity, set())),
                "topological_layer": next(
                    (layer_index for layer_index, layer in enumerate(_topological_layers(graph)) if entity in layer),
                    None,
                ),
            }
            for entity, definitions in entity_defs.items()
        ],
    }

    output_path.write_text(json.dumps(output, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def _write_markdown(
    output_path: Path,
    *,
    scan_dirs: tuple[str, ...],
    entity_defs: dict[str, list[EntityDefinition]],
    graph: dict[str, set[str]],
    reverse_graph: dict[str, set[str]],
) -> None:
    summary = _graph_summary(entity_defs, graph, reverse_graph)
    topological_layers = _topological_layers(graph)

    def format_table(rows: list[dict[str, object]], columns: tuple[str, ...]) -> list[str]:
        if not rows:
            return ["No rows."]
        header = "| " + " | ".join(columns) + " |"
        separator = "| " + " | ".join("---" for _ in columns) + " |"
        body = [
            "| " + " | ".join(str(row.get(column, "")) for column in columns) + " |"
            for row in rows
        ]
        return [header, separator, *body]

    lines = [
        "# SURF RTL Instantiation Graph",
        "",
        "## Scope",
        f"- Scan dirs: `{', '.join(scan_dirs)}`",
        "- Included files: VHDL files outside `tb/`, `build/`, and `.venv/` paths.",
        "- Direct entity instantiations are parsed explicitly.",
        "- Component-style instantiations are included only when the instantiated token matches a known entity name inside an architecture body.",
        "- Packages are not graph nodes.",
        "",
        "## Summary",
        f"- Entities: `{summary['entity_count']}`",
        f"- Edges: `{summary['edge_count']}`",
        f"- Topological layers: `{len(topological_layers)}`",
        f"- Duplicate entity names: `{len(summary['duplicate_entity_names'])}`",
        "",
        "## Top Instantiated Entities",
        *format_table(summary["top_instantiated_entities"], ("entity", "instantiated_by_count", "instantiates_count", "path")),
        "",
        "## Top Assemblers",
        *format_table(summary["top_assemblers"], ("entity", "instantiates_count", "instantiated_by_count", "path")),
        "",
        "## Top Leaf Entities",
        *format_table(summary["top_leaf_entities"], ("entity", "instantiated_by_count", "path")),
        "",
        "## Base Bottom-Up Candidates",
        *format_table(summary["base_bottom_up_candidates"], ("entity", "instantiated_by_count", "instantiates_count", "path")),
        "",
        "## Duplicate Entity Names",
    ]

    if summary["duplicate_entity_names"]:
        for entity, paths in summary["duplicate_entity_names"].items():
            lines.append(f"- `{entity}`")
            for path in paths:
                lines.append(f"  - `{path}`")
    else:
        lines.append("- None")

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_graph(repo_root: Path, output_dir: Path, scan_dirs: tuple[str, ...]) -> None:
    files = _discover_vhdl_files(repo_root, scan_dirs)
    entity_defs = _entity_definitions(repo_root, files)
    graph = _entity_instantiations(files, set(entity_defs))
    reverse_graph = _reverse_graph(graph)

    output_dir.mkdir(parents=True, exist_ok=True)
    _write_json(output_dir / "rtl_instantiation_graph.json", scan_dirs=scan_dirs, entity_defs=entity_defs, graph=graph, reverse_graph=reverse_graph)
    _write_markdown(output_dir / "rtl_instantiation_graph.md", scan_dirs=scan_dirs, entity_defs=entity_defs, graph=graph, reverse_graph=reverse_graph)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate a first-pass SURF RTL instantiation graph.")
    parser.add_argument(
        "--output-dir",
        default=str(_repo_root() / "docs" / "_meta"),
        help="Directory for generated graph artifacts.",
    )
    parser.add_argument(
        "--scan-dir",
        action="append",
        dest="scan_dirs",
        help="Restrict the scan to one or more top-level directories. Defaults to the main RTL subsystems.",
    )
    args = parser.parse_args()

    repo_root = _repo_root()
    scan_dirs = tuple(args.scan_dirs) if args.scan_dirs else DEFAULT_SCAN_DIRS
    build_graph(repo_root=repo_root, output_dir=Path(args.output_dir), scan_dirs=scan_dirs)


if __name__ == "__main__":
    main()

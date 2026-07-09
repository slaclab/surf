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
import tempfile


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

DEFAULT_SCAN_DIRS = ("base", "axi", "dsp", "protocols", "ethernet", "devices", "xilinx")
EXCLUDED_PARTS = {"tb", "build", ".venv", "__pycache__"}
PHASE1_QUEUE_OVERRIDES_FILENAME = "rtl_phase1_queue_overrides.json"


@dataclass(frozen=True)
class EntityDefinition:
    name: str
    path: str
    subsystem: str

    @property
    def node_id(self) -> str:
        return f"{self.path}::{self.name}"


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _default_output_dir() -> Path:
    return Path(tempfile.gettempdir()) / "surf_rtl_instantiation_graph"


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


def _default_phase1_queue_overrides() -> dict[str, object]:
    return {
        "force_include_entities": [],
        "force_include_paths": [],
        "deferred_subsystems": [
            {"name": "devices", "reason": "Subsystem is currently dominated by vendor-heavy modules in phase 1."},
            {"name": "xilinx", "reason": "Subsystem is currently dominated by vendor-heavy modules in phase 1."},
        ],
        "deferred_entities": [
            {
                "entity": "LutFixedDelay",
                "reason": "Depends on SinglePortRamPrimitive under the current open-source flow.",
            }
        ],
        "deferred_paths": [],
        "deferred_path_substrings": [
            {
                "pattern": "axi/simlink/",
                "reason": "Simulation support models are not part of the synthesizable phase-1 queue.",
            },
            {
                "pattern": "/dummy/",
                "reason": "Dummy-backed variants are deferred from the phase-1 executable queue.",
            },
            {
                "pattern": "/altera/",
                "reason": "Vendor-specific implementation branches are deferred in phase 1.",
            },
            {
                "pattern": "/xilinx/",
                "reason": "Vendor-specific implementation branches are deferred in phase 1.",
            },
            {
                "pattern": "/7Series/",
                "reason": "Family-specific implementation branches are deferred in phase 1.",
            },
            {
                "pattern": "/UltraScale/",
                "reason": "Family-specific implementation branches are deferred in phase 1.",
            },
            {
                "pattern": "/UltraScale+/",
                "reason": "Family-specific implementation branches are deferred in phase 1.",
            },
            {
                "pattern": "/gth",
                "reason": "GT-family implementation branches are deferred in phase 1.",
            },
            {
                "pattern": "/gtp",
                "reason": "GT-family implementation branches are deferred in phase 1.",
            },
            {
                "pattern": "/gty",
                "reason": "GT-family implementation branches are deferred in phase 1.",
            },
        ],
        "preferred_paths_by_entity": {},
        "order_overrides": [],
    }


def _load_phase1_queue_overrides(output_dir: Path) -> tuple[Path, dict[str, object]]:
    override_path = output_dir / PHASE1_QUEUE_OVERRIDES_FILENAME
    if override_path.exists():
        return override_path, json.loads(override_path.read_text(encoding="utf-8"))
    return override_path, _default_phase1_queue_overrides()


def _definition_sort_key(definition: EntityDefinition) -> tuple[str, str, str]:
    return (definition.subsystem, definition.path, definition.name)


def _phase1_filter_reason(definition: EntityDefinition, overrides: dict[str, object]) -> str | None:
    if definition.name in set(overrides.get("force_include_entities", [])):
        return None
    if definition.path in set(overrides.get("force_include_paths", [])):
        return None

    for item in overrides.get("deferred_subsystems", []):
        if definition.subsystem == item["name"]:
            return item["reason"]

    for item in overrides.get("deferred_entities", []):
        if definition.name == item["entity"]:
            return item["reason"]

    for item in overrides.get("deferred_paths", []):
        if definition.path == item["path"]:
            return item["reason"]

    for item in overrides.get("deferred_path_substrings", []):
        if item["pattern"] in definition.path:
            return item["reason"]

    return None


def _phase1_definitions(
    entity_defs: dict[str, list[EntityDefinition]],
    overrides: dict[str, object],
) -> tuple[dict[str, EntityDefinition], list[dict[str, str]]]:
    included: dict[str, EntityDefinition] = {}
    deferred: list[dict[str, str]] = []

    for definitions in entity_defs.values():
        for definition in definitions:
            reason = _phase1_filter_reason(definition, overrides)
            if reason is None:
                included[definition.node_id] = definition
            else:
                deferred.append(
                    {
                        "entity": definition.name,
                        "path": definition.path,
                        "subsystem": definition.subsystem,
                        "reason": reason,
                    }
                )

    deferred.sort(key=lambda item: (item["subsystem"], item["path"], item["entity"]))
    return included, deferred


def _common_prefix_length(left: tuple[str, ...], right: tuple[str, ...]) -> int:
    prefix_length = 0
    for left_part, right_part in zip(left, right):
        if left_part != right_part:
            break
        prefix_length += 1
    return prefix_length


def _resolve_phase1_target(
    source_definition: EntityDefinition,
    target_name: str,
    candidates: list[EntityDefinition],
    preferred_paths_by_entity: dict[str, str],
) -> tuple[EntityDefinition | None, str | None]:
    if not candidates:
        return None, None

    ordered_candidates = sorted(candidates, key=_definition_sort_key)
    if len(ordered_candidates) == 1:
        return ordered_candidates[0], "unique remaining phase-1 definition"

    preferred_path = preferred_paths_by_entity.get(target_name)
    if preferred_path:
        preferred_matches = [candidate for candidate in ordered_candidates if candidate.path == preferred_path]
        if len(preferred_matches) == 1:
            return preferred_matches[0], "preferred_paths_by_entity override"

    source_parts = tuple(Path(source_definition.path).parts)
    scored_candidates = sorted(
        (
            (_common_prefix_length(source_parts, tuple(Path(candidate.path).parts)), candidate)
            for candidate in ordered_candidates
        ),
        key=lambda item: (-item[0], _definition_sort_key(item[1])),
    )
    best_score = scored_candidates[0][0]
    if best_score > 0:
        best_matches = [candidate for score, candidate in scored_candidates if score == best_score]
        if len(best_matches) == 1:
            return best_matches[0], "longest common path prefix"

    same_subsystem = [candidate for candidate in ordered_candidates if candidate.subsystem == source_definition.subsystem]
    if len(same_subsystem) == 1:
        return same_subsystem[0], "same subsystem tie-break"

    non_dummy = [candidate for candidate in ordered_candidates if "/dummy/" not in candidate.path]
    if len(non_dummy) == 1:
        return non_dummy[0], "single non-dummy remaining definition"

    return None, "ambiguous duplicate entity name"


def _phase1_graph(
    repo_root: Path,
    files: list[Path],
    entity_defs: dict[str, list[EntityDefinition]],
    phase1_defs: dict[str, EntityDefinition],
    overrides: dict[str, object],
) -> tuple[dict[str, set[str]], list[dict[str, object]]]:
    phase1_defs_by_name: dict[str, list[EntityDefinition]] = defaultdict(list)
    defs_by_path_and_name: dict[tuple[str, str], EntityDefinition] = {}
    for definition in phase1_defs.values():
        phase1_defs_by_name[definition.name].append(definition)
        defs_by_path_and_name[(definition.path, definition.name)] = definition

    graph: dict[str, set[str]] = {node_id: set() for node_id in phase1_defs}
    unresolved: dict[tuple[str, str, str], dict[str, object]] = {}
    preferred_paths_by_entity = dict(overrides.get("preferred_paths_by_entity", {}))

    for path in files:
        text = _strip_comments(path.read_text(encoding="utf-8"))
        lines = text.splitlines()
        source_relative_path = path.relative_to(repo_root).as_posix()
        current_definition: EntityDefinition | None = None
        in_architecture_body = False

        for line in lines:
            arch_match = RE_ARCH_DECL.search(line)
            if arch_match:
                current_definition = defs_by_path_and_name.get((source_relative_path, arch_match.group("entity")))
                in_architecture_body = False
                continue

            if current_definition is None:
                continue

            if not in_architecture_body:
                if line.strip().lower() == "begin":
                    in_architecture_body = True
                continue

            target_name: str | None = None
            direct_match = RE_DIRECT_ENTITY_INST.search(line)
            if direct_match:
                target_name = direct_match.group("target")
            else:
                component_match = RE_COMPONENT_INST.search(line)
                if component_match:
                    component_target = component_match.group("target")
                    if component_target.lower() not in ARCH_BODY_SKIP_TOKENS:
                        target_name = component_target

            if target_name is None:
                continue

            resolved_definition, resolution_reason = _resolve_phase1_target(
                source_definition=current_definition,
                target_name=target_name,
                candidates=phase1_defs_by_name.get(target_name, []),
                preferred_paths_by_entity=preferred_paths_by_entity,
            )

            if resolved_definition is None:
                if resolution_reason is not None:
                    key = (current_definition.path, current_definition.name, target_name)
                    unresolved[key] = {
                        "source_entity": current_definition.name,
                        "source_path": current_definition.path,
                        "target_entity": target_name,
                        "candidate_paths": sorted(
                            candidate.path for candidate in phase1_defs_by_name.get(target_name, [])
                        ),
                        "reason": resolution_reason,
                    }
                continue

            if resolved_definition.node_id != current_definition.node_id:
                graph[current_definition.node_id].add(resolved_definition.node_id)

    for node_id in graph:
        graph[node_id] = set(sorted(graph[node_id]))

    unresolved_edges = sorted(
        unresolved.values(),
        key=lambda item: (item["source_path"], item["source_entity"], item["target_entity"]),
    )
    return dict(sorted(graph.items())), unresolved_edges


def _bottom_up_layers(graph: dict[str, set[str]], definitions: dict[str, EntityDefinition]) -> list[list[str]]:
    reverse_graph = _reverse_graph(graph)
    remaining_children = {node_id: len(children) for node_id, children in graph.items()}

    def sort_key(node_id: str) -> tuple[str, str]:
        return _definition_sort_key(definitions[node_id])

    queue = deque(sorted((node_id for node_id, count in remaining_children.items() if count == 0), key=sort_key))
    layers: list[list[str]] = []

    while queue:
        layer = list(queue)
        layers.append(layer)
        queue.clear()
        next_layer: list[str] = []
        for node_id in layer:
            for parent_id in sorted(reverse_graph.get(node_id, set()), key=sort_key):
                remaining_children[parent_id] -= 1
                if remaining_children[parent_id] == 0:
                    next_layer.append(parent_id)
        queue.extend(sorted(next_layer, key=sort_key))

    if sum(len(layer) for layer in layers) != len(graph):
        remaining = sorted((node_id for node_id, count in remaining_children.items() if count > 0), key=sort_key)
        if remaining:
            layers.append(remaining)

    return layers


def _resolve_override_node_id(
    definitions: dict[str, EntityDefinition],
    *,
    path: str,
    entity: str | None,
) -> str:
    matches = [
        node_id
        for node_id, definition in definitions.items()
        if definition.path == path and (entity is None or definition.name == entity)
    ]
    if len(matches) != 1:
        raise ValueError(f"Override reference path={path!r} entity={entity!r} matched {len(matches)} phase-1 nodes.")
    return matches[0]


def _validate_bottom_up_order(queue: list[str], graph: dict[str, set[str]]) -> None:
    positions = {node_id: index for index, node_id in enumerate(queue)}
    violations: list[tuple[str, str]] = []
    for parent_id, child_ids in graph.items():
        for child_id in child_ids:
            if positions[child_id] >= positions[parent_id]:
                violations.append((parent_id, child_id))

    if violations:
        first_parent, first_child = violations[0]
        raise ValueError(
            "Manual queue overrides broke bottom-up ordering: "
            f"parent {first_parent!r} now appears before child {first_child!r}."
        )


def _apply_order_overrides(
    queue: list[str],
    graph: dict[str, set[str]],
    definitions: dict[str, EntityDefinition],
    overrides: dict[str, object],
) -> tuple[list[str], list[dict[str, str]]]:
    queue_with_overrides = list(queue)
    applied: list[dict[str, str]] = []

    for override in overrides.get("order_overrides", []):
        source_id = _resolve_override_node_id(
            definitions,
            path=override["path"],
            entity=override.get("entity"),
        )
        before_path = override.get("before_path")
        after_path = override.get("after_path")
        if bool(before_path) == bool(after_path):
            raise ValueError(
                f"Order override for {override['path']!r} must specify exactly one of before_path or after_path."
            )

        anchor_id = _resolve_override_node_id(
            definitions,
            path=before_path or after_path,
            entity=override.get("before_entity") or override.get("after_entity"),
        )

        current_index = queue_with_overrides.index(source_id)
        queue_with_overrides.pop(current_index)
        anchor_index = queue_with_overrides.index(anchor_id)
        insert_index = anchor_index if before_path else anchor_index + 1
        queue_with_overrides.insert(insert_index, source_id)

        applied.append(
            {
                "entity": definitions[source_id].name,
                "path": definitions[source_id].path,
                "placement": f"{'before' if before_path else 'after'} {definitions[anchor_id].path}",
                "reason": override["reason"],
            }
        )

    _validate_bottom_up_order(queue_with_overrides, graph)
    return queue_with_overrides, applied


def _write_phase1_queue_json(
    output_path: Path,
    *,
    scan_dirs: tuple[str, ...],
    override_path: Path,
    overrides: dict[str, object],
    definitions: dict[str, EntityDefinition],
    graph: dict[str, set[str]],
    deferred: list[dict[str, str]],
    unresolved_edges: list[dict[str, object]],
    queue: list[str],
    layer_by_node: dict[str, int],
    applied_overrides: list[dict[str, str]],
) -> None:
    reverse_graph = _reverse_graph(graph)
    output = {
        "generated_from": {
            "scan_dirs": list(scan_dirs),
            "source_graph_script": "scripts/build_rtl_instantiation_graph.py",
            "override_file": override_path.as_posix(),
            "queue_policy": "Path-qualified, phase-1 filtered, bottom-up instantiation order",
        },
        "summary": {
            "phase1_module_count": len(definitions),
            "phase1_edge_count": sum(len(targets) for targets in graph.values()),
            "phase1_bottom_up_layers": max(layer_by_node.values(), default=-1) + 1,
            "deferred_module_count": len(deferred),
            "unresolved_phase1_edges": len(unresolved_edges),
            "applied_order_overrides": len(applied_overrides),
        },
        "phase1_rules": overrides,
        "applied_order_overrides": applied_overrides,
        "queue": [
            {
                "order": order_index,
                "bottom_up_layer": layer_by_node[node_id],
                "entity": definitions[node_id].name,
                "path": definitions[node_id].path,
                "subsystem": definitions[node_id].subsystem,
                "instantiates_in_phase1_count": len(graph[node_id]),
                "instantiated_by_in_phase1_count": len(reverse_graph.get(node_id, set())),
            }
            for order_index, node_id in enumerate(queue, start=1)
        ],
        "deferred": deferred,
        "unresolved_phase1_edges": unresolved_edges,
    }

    output_path.write_text(json.dumps(output, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def _write_phase1_queue_markdown(
    output_path: Path,
    *,
    scan_dirs: tuple[str, ...],
    override_path: Path,
    overrides: dict[str, object],
    definitions: dict[str, EntityDefinition],
    graph: dict[str, set[str]],
    deferred: list[dict[str, str]],
    unresolved_edges: list[dict[str, object]],
    queue: list[str],
    layer_by_node: dict[str, int],
    applied_overrides: list[dict[str, str]],
) -> None:
    reverse_graph = _reverse_graph(graph)

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

    deferred_subsystems = overrides.get("deferred_subsystems", [])
    deferred_entities = overrides.get("deferred_entities", [])
    deferred_paths = overrides.get("deferred_paths", [])
    deferred_path_substrings = overrides.get("deferred_path_substrings", [])

    queue_rows = [
        {
            "order": order_index,
            "layer": layer_by_node[node_id],
            "entity": definitions[node_id].name,
            "subsystem": definitions[node_id].subsystem,
            "path": definitions[node_id].path,
            "instantiated_by_count": len(reverse_graph.get(node_id, set())),
        }
        for order_index, node_id in enumerate(queue, start=1)
    ]

    lines = [
        "# SURF RTL Phase-1 Queue",
        "",
        "## Scope",
        f"- Scan dirs: `{', '.join(scan_dirs)}`",
        "- Queue nodes are path-qualified RTL entity definitions, not bare entity names.",
        "- Queue order is bottom-up: leaves first, higher-level assemblies later.",
        f"- Manual phase-1 deferrals and order overrides live in `{override_path.as_posix()}`.",
        "",
        "## Summary",
        f"- Phase-1 modules: `{len(definitions)}`",
        f"- Phase-1 dependency edges: `{sum(len(targets) for targets in graph.values())}`",
        f"- Bottom-up layers: `{max(layer_by_node.values(), default=-1) + 1}`",
        f"- Deferred modules: `{len(deferred)}`",
        f"- Unresolved duplicate-name phase-1 edges: `{len(unresolved_edges)}`",
        f"- Applied order overrides: `{len(applied_overrides)}`",
        "",
        "## Phase-1 Filters",
        "- Force-included entities:",
    ]

    force_include_entities = overrides.get("force_include_entities", [])
    force_include_paths = overrides.get("force_include_paths", [])
    if force_include_entities:
        lines.extend(f"  - `{entity}`" for entity in force_include_entities)
    else:
        lines.append("  - None")

    lines.append("- Force-included paths:")
    if force_include_paths:
        lines.extend(f"  - `{path}`" for path in force_include_paths)
    else:
        lines.append("  - None")

    lines.append("- Deferred subsystems:")
    if deferred_subsystems:
        lines.extend(f"  - `{item['name']}`: {item['reason']}" for item in deferred_subsystems)
    else:
        lines.append("  - None")

    lines.append("- Deferred entities:")
    if deferred_entities:
        lines.extend(f"  - `{item['entity']}`: {item['reason']}" for item in deferred_entities)
    else:
        lines.append("  - None")

    lines.append("- Deferred exact paths:")
    if deferred_paths:
        lines.extend(f"  - `{item['path']}`: {item['reason']}" for item in deferred_paths)
    else:
        lines.append("  - None")

    lines.append("- Deferred path substrings:")
    if deferred_path_substrings:
        lines.extend(f"  - `{item['pattern']}`: {item['reason']}" for item in deferred_path_substrings)
    else:
        lines.append("  - None")

    lines.extend(["", "## Manual Order Overrides"])
    if applied_overrides:
        lines.extend(
            f"- `{item['path']}` ({item['entity']}) placed {item['placement']}: {item['reason']}"
            for item in applied_overrides
        )
    else:
        lines.append("- None")

    lines.extend(["", "## Unresolved Duplicate-Name Phase-1 Edges"])
    if unresolved_edges:
        for item in unresolved_edges:
            lines.append(
                f"- `{item['source_path']}` (`{item['source_entity']}`) -> `{item['target_entity']}`: {item['reason']}"
            )
            for candidate_path in item["candidate_paths"]:
                lines.append(f"  - `{candidate_path}`")
    else:
        lines.append("- None")

    lines.extend(["", "## Flat Bottom-Up Order"])
    lines.extend(format_table(queue_rows, ("order", "layer", "entity", "subsystem", "path", "instantiated_by_count")))

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_phase1_queue_artifacts(
    repo_root: Path,
    output_dir: Path,
    *,
    scan_dirs: tuple[str, ...],
    files: list[Path],
    entity_defs: dict[str, list[EntityDefinition]],
) -> None:
    override_path, overrides = _load_phase1_queue_overrides(output_dir)
    phase1_defs, deferred = _phase1_definitions(entity_defs, overrides)
    phase1_graph, unresolved_edges = _phase1_graph(
        repo_root=repo_root,
        files=files,
        entity_defs=entity_defs,
        phase1_defs=phase1_defs,
        overrides=overrides,
    )
    layers = _bottom_up_layers(phase1_graph, phase1_defs)
    queue = [node_id for layer in layers for node_id in layer]
    queue, applied_overrides = _apply_order_overrides(queue, phase1_graph, phase1_defs, overrides)
    try:
        displayed_override_path = override_path.relative_to(repo_root)
    except ValueError:
        displayed_override_path = override_path

    layer_by_node = {
        node_id: layer_index
        for layer_index, layer in enumerate(_bottom_up_layers(phase1_graph, phase1_defs))
        for node_id in layer
    }

    _write_phase1_queue_json(
        output_dir / "rtl_phase1_queue.json",
        scan_dirs=scan_dirs,
        override_path=displayed_override_path,
        overrides=overrides,
        definitions=phase1_defs,
        graph=phase1_graph,
        deferred=deferred,
        unresolved_edges=unresolved_edges,
        queue=queue,
        layer_by_node=layer_by_node,
        applied_overrides=applied_overrides,
    )
    _write_phase1_queue_markdown(
        output_dir / "rtl_phase1_queue.md",
        scan_dirs=scan_dirs,
        override_path=displayed_override_path,
        overrides=overrides,
        definitions=phase1_defs,
        graph=phase1_graph,
        deferred=deferred,
        unresolved_edges=unresolved_edges,
        queue=queue,
        layer_by_node=layer_by_node,
        applied_overrides=applied_overrides,
    )


def build_graph(repo_root: Path, output_dir: Path, scan_dirs: tuple[str, ...]) -> None:
    files = _discover_vhdl_files(repo_root, scan_dirs)
    entity_defs = _entity_definitions(repo_root, files)
    graph = _entity_instantiations(files, set(entity_defs))
    reverse_graph = _reverse_graph(graph)

    output_dir.mkdir(parents=True, exist_ok=True)
    _write_json(output_dir / "rtl_instantiation_graph.json", scan_dirs=scan_dirs, entity_defs=entity_defs, graph=graph, reverse_graph=reverse_graph)
    _write_markdown(output_dir / "rtl_instantiation_graph.md", scan_dirs=scan_dirs, entity_defs=entity_defs, graph=graph, reverse_graph=reverse_graph)
    _write_phase1_queue_artifacts(
        repo_root=repo_root,
        output_dir=output_dir,
        scan_dirs=scan_dirs,
        files=files,
        entity_defs=entity_defs,
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate SURF RTL instantiation graph artifacts and a path-qualified phase-1 queue."
    )
    parser.add_argument(
        "--output-dir",
        default=str(_default_output_dir()),
        help=(
            "Directory for generated graph and queue artifacts. Defaults to a temporary "
            "directory so generated analysis does not become normal docs context."
        ),
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

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

from functools import lru_cache
import hashlib
import os
from pathlib import Path
import re
import shlex
import subprocess

import pytest
from cocotb_test.simulator import run


# Keep all repo-relative path resolution in one place so tests can move into
# subsystem packages without having to duplicate build tree logic.
REPO_ROOT = Path(__file__).resolve().parents[2]
TESTS_ROOT = REPO_ROOT / "tests"
BUILD_SRC_ROOT = REPO_ROOT / "build" / "SRC_VHDL"

BASE_GHDL_COMPILE_ARGS = [
    "--std=08",
    "-fsynopsys",
    "-frelaxed-rules",
    "-fexplicit",
]

OPTIONAL_GHDL_WARNINGS = ("elaboration", "hide", "specs")

PRIMARY_VHDL_UNIT_RE = re.compile(
    r"(?im)^(?:"
    r"entity\s+(?P<entity>[a-z][a-z0-9_]*)\s+is\b|"
    r"package\s+(?!body\b)(?P<package>[a-z][a-z0-9_]*)\s+is\b|"
    r"configuration\s+(?P<configuration>[a-z][a-z0-9_]*)\s+of\b"
    r")"
)


@lru_cache(maxsize=1)
def _supported_ghdl_warning_names() -> frozenset[str]:
    try:
        result = subprocess.run(
            [*shlex.split(os.environ.get("GHDL_CMD", "ghdl")), "--help-warnings"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return frozenset()

    names = set()
    for line in result.stdout.splitlines():
        token = line.strip().split(maxsplit=1)[0]
        if not token.startswith("-W") or token == "-Wall":
            continue
        names.add(token.removeprefix("-W").removesuffix("*"))
    return frozenset(names)


def _optional_ghdl_warning_flags() -> list[str]:
    supported_names = _supported_ghdl_warning_names()
    return [f"-Wno-{name}" for name in OPTIONAL_GHDL_WARNINGS if name in supported_names]


COMMON_VHDL_COMPILE_ARGS = [
    *BASE_GHDL_COMPILE_ARGS,
    *_optional_ghdl_warning_flags(),
    "-O2",
]


async def sample_after_delta_cycles(clock) -> None:
    """Wait for a rising edge and sample after combinational delta settling."""
    from cocotb.triggers import ReadOnly, RisingEdge

    await RisingEdge(clock)
    await ReadOnly()


async def sample_after_tpd(
    clock,
    *,
    propagation_time: float = 1.0,
    unit: str = "ns",
) -> None:
    """Propagation sampling: wait past a real VHDL ``after TPD_G`` delay."""
    from cocotb.triggers import RisingEdge, Timer

    await RisingEdge(clock)
    await Timer(propagation_time, unit=unit)


async def wait_after_edge_offset(
    clock,
    *,
    offset_time: float,
    unit: str = "ns",
) -> None:
    """Real-time timing: move stimulus by a deliberate offset after an edge."""
    from cocotb.triggers import RisingEdge, Timer

    await RisingEdge(clock)
    await Timer(offset_time, unit=unit)


def start_lockstep_clocks(*signals, period_ns: float):
    import cocotb
    from cocotb.triggers import Timer

    async def drive() -> None:
        """Lifetime agent: drive all requested clocks until the test ends."""
        half_period_ns = period_ns / 2
        for signal in signals:
            signal.value = 0

        while True:
            await Timer(half_period_ns, unit="ns")
            for signal in signals:
                signal.value = 1
            await Timer(half_period_ns, unit="ns")
            for signal in signals:
                signal.value = 0

    # Drive logically-common clocks from one coroutine so COMMON_CLK_G tests
    # really exercise a shared clock, not two same-period oscillators that can
    # drift in phase relative to each other.
    return cocotb.start_soon(drive())


def env_flag(name: str, *, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default

    normalized = raw.strip().strip("'").lower()
    if normalized in {"1", "true"}:
        return True
    if normalized in {"0", "false"}:
        return False
    raise ValueError(f"Unsupported boolean environment value for {name}: {raw}")


def env_sl(name: str, *, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None:
        return default

    normalized = raw.strip().strip("'")
    if normalized in {"0", "1"}:
        return int(normalized)
    raise ValueError(f"Unsupported std_logic environment value for {name}: {raw}")


def env_hex(name: str, *, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None:
        return default

    normalized = raw.strip().strip('"').strip()
    if normalized.lower().startswith("x\"") and normalized.endswith('"'):
        normalized = normalized[2:-1]
    if normalized.lower().startswith("0x"):
        normalized = normalized[2:]
    if normalized.lower().startswith("16#") and normalized.endswith("#"):
        normalized = normalized[3:-1]
    return int(normalized, 16)


def env_float(name: str, *, default: float) -> float:
    raw = os.environ.get(name)
    if raw is None:
        return default

    normalized = raw.strip().strip("'").strip('"')
    return float(normalized)


def env_int(name: str, *, default: int) -> int:
    raw = os.environ.get(name)
    return default if raw is None else int(raw.strip().strip("'").strip('"'))


def parameter_case(case_id: str, **parameters: str):
    return pytest.param(parameters, id=case_id)


def hdl_parameters_from(parameters: dict[str, object]) -> dict[str, object]:
    return {
        key: value
        for key, value in parameters.items()
        if key.endswith("_G")
    }


def cocotb_test_filter(*test_names: str) -> str:
    if not test_names:
        raise ValueError("At least one cocotb test name is required")
    alternatives = "|".join(re.escape(name) for name in test_names)
    return rf"(?:{alternatives})$"


def cocotb_test_filter_excluding(*test_names: str) -> str:
    if not test_names:
        raise ValueError("At least one cocotb test name is required")
    alternatives = "|".join(re.escape(name) for name in test_names)
    return rf"^(?!.*(?:{alternatives})$).*"


def cocotb_filtered_env(
    extra_env: dict[str, object],
    test_filter: str,
) -> dict[str, object]:
    result = dict(extra_env)
    external_selectors = {
        name: os.environ[name]
        for name in ("COCOTB_TESTCASE", "COCOTB_TEST_FILTER")
        if name in os.environ
    }
    if len(external_selectors) > 1:
        raise ValueError("Specify only one of COCOTB_TESTCASE or COCOTB_TEST_FILTER")
    if external_selectors:
        result.update(external_selectors)
    else:
        result["COCOTB_TEST_FILTER"] = test_filter
    return result


def build_vhdl_sources() -> dict[str, list[str]]:
    surf_dir = BUILD_SRC_ROOT / "surf"
    ruckus_dir = BUILD_SRC_ROOT / "ruckus"

    if not surf_dir.exists() or not ruckus_dir.exists():
        raise FileNotFoundError(
            "Missing imported HDL sources. Run `make MODULES=\"$PWD\" import` first."
        )

    return {
        "surf": [str(path) for path in sorted(surf_dir.iterdir()) if path.is_file()],
        "ruckus": [str(path) for path in sorted(ruckus_dir.iterdir()) if path.is_file()],
    }


def _resolved_source_path(path: str | Path) -> Path:
    source = Path(path)
    if not source.is_absolute():
        source = REPO_ROOT / source
    return source.resolve()


@lru_cache(maxsize=None)
def _primary_vhdl_units(path: Path) -> frozenset[str]:
    if path.suffix.lower() not in {".vhd", ".vhdl"}:
        return frozenset()

    try:
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return frozenset()

    source_without_comments = "\n".join(
        line.split("--", 1)[0]
        for line in source.splitlines()
    )
    return frozenset(
        name.lower()
        for match in PRIMARY_VHDL_UNIT_RE.finditer(source_without_comments)
        for name in match.groupdict().values()
        if name is not None
    )


def merge_vhdl_sources(
    base_sources: dict[str, list[str]],
    extra_sources: dict[str, list[str]] | None,
) -> dict[str, list[str]]:
    if not extra_sources:
        return base_sources

    merged = {library: list(paths) for library, paths in base_sources.items()}
    resolved_by_library = {
        library: {_resolved_source_path(path) for path in paths}
        for library, paths in base_sources.items()
    }
    units_by_library = {
        library: {
            unit: _resolved_source_path(path)
            for path in paths
            for unit in _primary_vhdl_units(_resolved_source_path(path))
        }
        for library, paths in base_sources.items()
    }

    for library, paths in extra_sources.items():
        merged.setdefault(library, [])
        resolved_by_library.setdefault(library, set())
        units_by_library.setdefault(library, {})
        # Append test-local sources after the imported SURF library so wrappers
        # can instantiate the real RTL that was already compiled above.
        for path in paths:
            resolved = _resolved_source_path(path)
            if resolved in resolved_by_library[library]:
                raise ValueError(
                    f"Extra VHDL source {path} duplicates {resolved} "
                    f"already present in library {library}"
                )

            units = _primary_vhdl_units(resolved)
            duplicate_units = sorted(units & units_by_library[library].keys())
            if duplicate_units:
                unit = duplicate_units[0]
                previous = units_by_library[library][unit]
                raise ValueError(
                    f"Extra VHDL source {path} declares {unit}, already declared "
                    f"by {previous} in library {library}"
                )

            merged[library].append(str(Path(path)))
            resolved_by_library[library].add(resolved)
            units_by_library[library].update({unit: resolved for unit in units})
    return merged


def _module_name_from_test_file(test_file: Path) -> str:
    # cocotb expects a Python import path for the module that contains the
    # @cocotb.test() entrypoints, not a filesystem path.
    return ".".join(test_file.resolve().relative_to(REPO_ROOT).with_suffix("").parts)


def cocotb_module_name_from_test_file(test_file: str | Path) -> str:
    return _module_name_from_test_file(Path(test_file))


def _sim_build_suffix(parameters: dict[str, object]) -> str:
    suffix = ",".join(f"{key}={value}" for key, value in sorted(parameters.items()))
    if len(suffix) > 120 or "/" in suffix or "\\" in suffix:
        suffix = f"params-{hashlib.sha256(suffix.encode()).hexdigest()}"
    return suffix


def _sim_build_path(test_file: Path, parameters: dict[str, object] | None) -> str:
    rel_parent = test_file.resolve().relative_to(TESTS_ROOT).parent
    build_dir = TESTS_ROOT / "sim_build" / rel_parent / test_file.stem
    if not parameters:
        return str(build_dir)

    # Parameter-specific build directories keep parallel pytest runs from
    # trampling each other's compile/elaboration artifacts.
    suffix = _sim_build_suffix(parameters)
    return str(build_dir.with_name(f"{test_file.stem}.{suffix}"))


def run_surf_vhdl_test(
    *,
    test_file: str | Path,
    toplevel: str,
    parameters: dict[str, object] | None = None,
    extra_env: dict[str, object] | None = None,
    extra_vhdl_sources: dict[str, list[str]] | None = None,
    sim_build_key: str | None = None,
    force_compile: bool = False,
) -> None:
    test_file = Path(test_file)
    simulator_env = None
    sim_build_parameters = parameters
    if extra_env is not None:
        simulator_env = {key: str(value) for key, value in extra_env.items()}
        sim_build_parameters = {
            **({key: str(value) for key, value in parameters.items()} if parameters is not None else {}),
            **simulator_env,
        }
    elif parameters is not None:
        simulator_env = {key: str(value) for key, value in parameters.items()}

    run(
        toplevel=toplevel,
        module=_module_name_from_test_file(test_file),
        toplevel_lang="vhdl",
        vhdl_sources=merge_vhdl_sources(build_vhdl_sources(), extra_vhdl_sources),
        parameters=parameters,
        sim_build=sim_build_key if sim_build_key is not None else _sim_build_path(test_file, sim_build_parameters),
        extra_env=simulator_env,
        simulator="ghdl",
        vhdl_compile_args=COMMON_VHDL_COMPILE_ARGS,
        force_compile=force_compile,
    )

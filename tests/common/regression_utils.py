from __future__ import annotations

import os
from pathlib import Path
from textwrap import dedent

import pytest
from cocotb_test.simulator import run


# Keep all repo-relative path resolution in one place so tests can move into
# subsystem packages without having to duplicate build tree logic.
REPO_ROOT = Path(__file__).resolve().parents[2]
TESTS_ROOT = REPO_ROOT / "tests"
BUILD_SRC_ROOT = REPO_ROOT / "build" / "SRC_VHDL"

COMMON_VHDL_COMPILE_ARGS = [
    "--std=08",
    "-fsynopsys",
    "-frelaxed-rules",
    "-fexplicit",
    "-Wno-elaboration",
    "-Wno-hide",
    "-Wno-specs",
    "-O2",
]


def start_lockstep_clocks(*signals, period_ns: float) -> None:
    import cocotb
    from cocotb.triggers import Timer

    async def drive() -> None:
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
    cocotb.start_soon(drive())


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


def parameter_case(case_id: str, **parameters: str):
    return pytest.param(parameters, id=case_id)


def hdl_parameters_from(parameters: dict[str, object]) -> dict[str, object]:
    return {
        key: value
        for key, value in parameters.items()
        if key.endswith("_G")
    }


def _build_vhdl_sources() -> dict[str, list[str]]:
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


def _merge_vhdl_sources(
    base_sources: dict[str, list[str]],
    extra_sources: dict[str, list[str]] | None,
) -> dict[str, list[str]]:
    if not extra_sources:
        return base_sources

    merged = {library: list(paths) for library, paths in base_sources.items()}
    for library, paths in extra_sources.items():
        merged.setdefault(library, [])
        # Append test-local sources after the imported SURF library so wrappers
        # can instantiate the real RTL that was already compiled above.
        merged[library].extend(str(Path(path)) for path in paths)
    return merged


def _module_name_from_test_file(test_file: Path) -> str:
    # cocotb expects a Python import path for the module that contains the
    # @cocotb.test() entrypoints, not a filesystem path.
    return ".".join(test_file.resolve().relative_to(REPO_ROOT).with_suffix("").parts)


def _sim_build_path(test_file: Path, parameters: dict[str, object] | None) -> str:
    rel_parent = test_file.resolve().relative_to(TESTS_ROOT).parent
    build_dir = TESTS_ROOT / "sim_build" / rel_parent / test_file.stem
    if not parameters:
        return str(build_dir)

    # Parameter-specific build directories keep parallel pytest runs from
    # trampling each other's compile/elaboration artifacts.
    suffix = ",".join(f"{key}={value}" for key, value in parameters.items())
    return str(build_dir.with_name(f"{test_file.stem}.{suffix}"))


def build_vhdl_wrapper_source(
    *,
    wrapper_name: str,
    wrapped_entity: str,
    generic_declarations: list[str],
    port_declarations: list[str],
    generic_map: list[str],
    port_map: list[str],
) -> str:
    generic_block = ""
    if generic_declarations:
        generic_lines = ";\n".join(f"      {line}" for line in generic_declarations)
        generic_block = f"   generic (\n{generic_lines});\n"

    port_lines = ";\n".join(f"      {line}" for line in port_declarations)
    generic_map_lines = ",\n".join(f"         {line}" for line in generic_map)
    port_map_lines = ",\n".join(f"         {line}" for line in port_map)

    # Keep generated wrappers tiny and predictable so tests can use them as
    # disposable shims instead of checking in one HDL file per generic issue.
    return dedent(
        f"""\
        library ieee;
        use ieee.std_logic_1164.all;

        library surf;
        use surf.StdRtlPkg.all;

        entity {wrapper_name} is
        {generic_block}   port (
        {port_lines});
        end entity {wrapper_name};

        architecture rtl of {wrapper_name} is
        begin
           U_DUT : entity surf.{wrapped_entity}
              generic map (
        {generic_map_lines})
              port map (
        {port_map_lines});
        end architecture rtl;
        """
    )


def generate_vhdl_wrapper(
    *,
    test_file: str | Path,
    wrapper_name: str,
    source: str,
    parameters: dict[str, object] | None = None,
) -> str:
    test_file = Path(test_file)
    sim_build_dir = Path(_sim_build_path(test_file, parameters))
    wrapper_dir = sim_build_dir / "generated_hdl"
    wrapper_dir.mkdir(parents=True, exist_ok=True)
    wrapper_path = wrapper_dir / f"{wrapper_name}.vhd"
    wrapper_path.write_text(source)
    return str(wrapper_path)


def run_surf_vhdl_test(
    *,
    test_file: str | Path,
    toplevel: str,
    parameters: dict[str, object] | None = None,
    extra_env: dict[str, object] | None = None,
    extra_vhdl_sources: dict[str, list[str]] | None = None,
) -> None:
    test_file = Path(test_file)
    simulator_env = None
    if extra_env is not None:
        simulator_env = {key: str(value) for key, value in extra_env.items()}
    elif parameters is not None:
        simulator_env = {key: str(value) for key, value in parameters.items()}

    run(
        toplevel=toplevel,
        module=_module_name_from_test_file(test_file),
        toplevel_lang="vhdl",
        vhdl_sources=_merge_vhdl_sources(_build_vhdl_sources(), extra_vhdl_sources),
        parameters=parameters,
        sim_build=_sim_build_path(test_file, parameters),
        extra_env=simulator_env,
        simulator="ghdl",
        vhdl_compile_args=COMMON_VHDL_COMPILE_ARGS,
    )

from __future__ import annotations

from pathlib import Path

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


def run_surf_vhdl_test(
    *,
    test_file: str | Path,
    toplevel: str,
    parameters: dict[str, object] | None = None,
    extra_env: dict[str, object] | None = None,
) -> None:
    test_file = Path(test_file)

    run(
        toplevel=toplevel,
        module=_module_name_from_test_file(test_file),
        toplevel_lang="vhdl",
        vhdl_sources=_build_vhdl_sources(),
        parameters=parameters,
        sim_build=_sim_build_path(test_file, parameters),
        extra_env=extra_env if extra_env is not None else parameters,
        simulator="ghdl",
        vhdl_compile_args=COMMON_VHDL_COMPILE_ARGS,
    )

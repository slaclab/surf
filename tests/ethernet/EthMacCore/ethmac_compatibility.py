#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

"""Materialize the pre-timing MAC under distinct names for differential tests.

The baseline is read from Git, never from a copied import cache. Its MAC
package and every MAC entity are renamed together, along with the two changed
SSI entities. Common AXI/base dependencies are unchanged by the timing patch.
The generated adapters only flatten records and instantiate the two designs;
all stimulus and comparisons live in cocotb.
"""

from pathlib import Path
import re
import subprocess

from tests.common.regression_utils import REPO_ROOT


BASELINE_REVISION = "ecbf833a2ebae68433f5b29ce02cec86f8f11bf6"
MAC_RTL = "ethernet/EthMacCore/rtl"
BASELINE_PATHS = (
    MAC_RTL,
    "protocols/ssi/rtl/SsiFifo.vhd",
    "protocols/ssi/rtl/SsiObFrameFilter.vhd",
)
TOP_WIDTH = "2*(2*AXI_STREAM_MAX_TDATA_WIDTH_C+2*AXI_STREAM_MAX_TKEEP_WIDTH_C+18)+237"


def _git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=REPO_ROOT, text=True)


def _write(path: Path, content: str) -> str:
    # Preserve mtimes when the inputs are unchanged so GHDL can reuse builds.
    if not path.exists() or path.read_text() != content:
        path.write_text(content)
    return str(path)


def _record(master: str) -> str:
    return " & ".join(f"{master}.{field}" for field in
                      ("tValid", "tData", "tStrb", "tKeep", "tLast", "tDest", "tId", "tUser"))


def _interface(source: str) -> tuple[str, str, list[str], list[tuple[str, str]]]:
    generics = source.split("   generic (", 1)[1].split("   port (", 1)[0].rsplit(");", 1)[0]
    ports = source.split("   port (", 1)[1].split("end entity ", 1)[0].rsplit(");", 1)[0]
    names = re.findall(r"^\s*(\w+)\s*:", generics, re.MULTILINE)
    directions = re.findall(r"^\s*(\w+)\s*:\s*(in|out)\b", ports, re.MULTILINE)
    return generics, ports, names, directions


def _dual_wrapper(source: str, name: str, width: str) -> str:
    generics, ports, names, directions = _interface(source)
    ports += f";\n      actualObservation : out slv({width}-1 downto 0);\n"
    ports += f"      baselineObservation : out slv({width}-1 downto 0)"
    prefix = source.split("entity ", 1)[0]
    result = f"{prefix}entity {name} is\n   generic ({generics});\n   port ({ports});\nend entity {name};\n\n"
    result += f"architecture mapping of {name} is\nbegin\n"
    for variant, observation in (("Current", "actualObservation"), ("Baseline", "baselineObservation")):
        mapping = [f"         {port} => {'open' if variant == 'Baseline' and direction == 'out' else port}"
                   for port, direction in directions]
        mapping.append(f"         observation => {observation}")
        result += f"\n   U_{variant} : entity surf.{name}{variant}\n      generic map (\n"
        result += ",\n".join(f"         {generic} => {generic}" for generic in names)
        result += ")\n      port map (\n" + ",\n".join(mapping) + ");\n"
    return result + "\nend architecture mapping;\n"


def compatibility_sources(directory: Path, *, leaf: bool = False) -> list[str]:
    directory.mkdir(parents=True, exist_ok=True)
    paths = _git("ls-tree", "-r", "--name-only", BASELINE_REVISION, "--", *BASELINE_PATHS).splitlines()
    originals = {path: _git("show", f"{BASELINE_REVISION}:{path}") for path in paths if path.endswith(".vhd")}
    names = {name for source in originals.values()
             for name in re.findall(r"(?im)^\s*(?:entity|package(?:\s+body)?)\s+(\w+)\s+is\b", source)}
    pattern = re.compile(r"\b(?:" + "|".join(sorted(names, key=len, reverse=True)) + r")\b", re.IGNORECASE)
    replacements = {name.lower(): "Baseline" + name for name in names}

    def rename(source: str) -> str:
        return pattern.sub(lambda match: replacements[match[0].lower()], source)

    outputs = [_write(directory / ("Baseline" + Path(path).name), rename(source))
               for path, source in originals.items()]
    wrapper = "EthMacImportExportWrapper" if leaf else "EthMacTopPhyWrapper"
    name = "EthMacLeafCompatibilityWrapper" if leaf else "EthMacCompatibilityWrapper"
    source = (REPO_ROOT / "ethernet/EthMacCore/wrappers" / f"{wrapper}.vhd").read_text()

    if leaf:
        # The selector binds the real GMII exporter when PHY_TYPE_G="GMII";
        # unlike EthMacTop this path has no TX FIFO to hide source underruns.
        observation = " & ".join((
            "sAxisSlave.tReady", _record("mAxisMaster"), "xgmiiTxd", "xgmiiTxc",
            "gmiiTxEn", "gmiiTxEr", "gmiiTxd", "rxCountEn", "rxCrcError",
            "txCountEn", "txUnderRun", "txLinkNotReady",
        ))
        width = "2*AXI_STREAM_MAX_TDATA_WIDTH_C+2*AXI_STREAM_MAX_TKEEP_WIDTH_C+106"
    else:
        width = TOP_WIDTH
        # Include XLGMII and every bit of both public AXI output records,
        # including invalid cycles. Do not mask sidebands with TVALID.
        source = source.replace("      -- XGMII PHY", "      -- XLGMII PHY\n"
                                "      xlgmiiRxd : in slv(127 downto 0) := (others => '0');\n"
                                "      xlgmiiRxc : in slv(15 downto 0) := (others => '0');\n"
                                "      xlgmiiTxd : out slv(127 downto 0);\n"
                                "      xlgmiiTxc : out slv(15 downto 0);\n"
                                "      -- XGMII PHY")
        source = re.sub(r"xlgmiiRxd\s*=> \(others => '0'\)", "xlgmiiRxd => xlgmiiRxd", source)
        source = re.sub(r"xlgmiiRxc\s*=> \(others => '0'\)", "xlgmiiRxc => xlgmiiRxc", source)
        source = re.sub(r"xlgmiiTxd\s*=> open", "xlgmiiTxd => xlgmiiTxd", source)
        source = re.sub(r"xlgmiiTxc\s*=> open", "xlgmiiTxc => xlgmiiTxc", source)
        observation = " & ".join((
            "sAxisSlave.tReady", "sBypSlave.tReady", _record("mAxisMaster"), _record("mBypMaster"),
            "xlgmiiTxd", "xlgmiiTxc", "xgmiiTxd", "xgmiiTxc", "gmiiTxEn", "gmiiTxEr", "gmiiTxd",
            *("ethStatus." + field for field in ("rxFifoDropCnt", "rxPauseCnt", "txPauseCnt", "rxCountEn",
                                               "rxOverFlow", "rxCrcErrorCnt", "txCountEn", "txUnderRunCnt", "txNotReadyCnt")),
        ))

    dual = _dual_wrapper(source, name, width)
    end_ports = source.index(");\nend entity")
    source = source[:end_ports] + f";\n      observation : out slv({width}-1 downto 0)" + source[end_ports:]
    # One concurrent flattening assignment, without sequencing or assertions.
    source = source.replace("\nbegin\n", f"\nbegin\n\n   observation <= {observation};\n", 1)
    for variant in ("Current", "Baseline"):
        adapted = source if variant == "Current" else rename(source)
        adapted = adapted.replace(wrapper, name + variant)
        outputs.append(_write(directory / f"{name}{variant}.vhd", adapted))
    outputs.append(_write(directory / f"{name}.vhd", dual))
    _write(directory / "baseline-revision.txt", _git("rev-parse", BASELINE_REVISION))
    return outputs

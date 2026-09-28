#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

ROOT_DIR := $(abspath $(CURDIR)/../../..)
SPEC_MD := $(CURDIR)/packetizer2.md
STYLE_CSS := $(ROOT_DIR)/docs/protocol-specs/protocol-spec.css
RENDER_SCRIPT := $(ROOT_DIR)/scripts/render_protocol_spec.sh
PDF_RENDER_SCRIPT := $(ROOT_DIR)/scripts/render_protocol_pdf.sh
OUT_DIR ?= $(ROOT_DIR)/build/specs/protocols/packetizer
OUT_HTML := $(OUT_DIR)/packetizer2.html
OUT_PDF := $(OUT_DIR)/packetizer2.pdf
ASSETS := $(wildcard $(CURDIR)/assets/*.svg)

.PHONY: html pdf clean

html: $(OUT_HTML)

pdf: $(OUT_PDF)

$(OUT_HTML): $(SPEC_MD) $(STYLE_CSS) $(RENDER_SCRIPT) $(ASSETS)
	mkdir -p "$(OUT_DIR)"
	"$(RENDER_SCRIPT)" "$(SPEC_MD)" "$@" "$(STYLE_CSS)"

$(OUT_PDF): $(SPEC_MD) $(STYLE_CSS) $(PDF_RENDER_SCRIPT) $(RENDER_SCRIPT) $(ASSETS)
	mkdir -p "$(OUT_DIR)"
	"$(PDF_RENDER_SCRIPT)" "$(SPEC_MD)" "$@" "$(STYLE_CSS)"

clean:
	rm -f "$(OUT_HTML)" "$(OUT_PDF)"

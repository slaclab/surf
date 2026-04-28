ROOT_DIR := $(abspath $(CURDIR)/../../../..)
SPEC_MD := $(CURDIR)/pgp4.md
STYLE_CSS := $(ROOT_DIR)/docs/protocol-specs/protocol-spec.css
RENDER_SCRIPT := $(ROOT_DIR)/scripts/render_protocol_spec.sh
OUT_DIR := $(ROOT_DIR)/build/specs/protocols/pgp/pgp4
OUT_HTML := $(OUT_DIR)/pgp4.html

.PHONY: html clean

html: $(OUT_HTML)

$(OUT_HTML): $(SPEC_MD) $(STYLE_CSS) $(RENDER_SCRIPT) $(wildcard $(CURDIR)/assets/*.svg)
	mkdir -p $(OUT_DIR)
	$(RENDER_SCRIPT) $(SPEC_MD) $(OUT_HTML) $(STYLE_CSS)

clean:
	rm -f $(OUT_HTML)

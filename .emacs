;; VHDL Mode settings for emacs
(setq comment-style (quote plain)) ;; Makes VHDL mode region (un)commenting work right
(setq vhdl-end-comment-column '200)
(setq vhdl-clock-edge-condition (quote function))
(setq vhdl-reset-kind "None")
(setq vhdl-company-name "SLAC National Accelerator Laboratory")
(setq vhdl-conditions-in-parenthesis t)
(setq vhdl-highlight-forbidden-words t)
(setq vhdl-highlight-special-words t)
(setq vhdl-highlight-translate-off t)
(setq vhdl-highlight-verilog-keywords nil)
(setq vhdl-index-menu t)
(setq vhdl-reset-active-high t)
(setq vhdl-standard (quote (93 nil)))
(setq vhdl-use-direct-instantiation (quote always))
(setq vhdl-argument-list-indent nil)
(setq vhdl-clock-edge-condition (quote function))
(setq vhdl-conditions-in-parenthesis t)
(setq vhdl-prompt-for-comments nil)
(setq vhdl-self-insert-comments nil)
(setq vhdl-use-direct-instantiation (quote always))
(setq vhdl-array-index-record-field-in-sensitivity-list nil)
(setq vhdl-special-syntax-alist
      '(("generic/constant" "\\<\\w+_[cgs]\\>\\|\\<c_\\w+\\>" "Gold3" "BurlyWood1" nil)
	("type" "\\<\\w+\\(_t\\|_type\\|_array\\|Array\\|Type\\)\\>\\|\\<slv?\\>" "ForestGreen" "#8cd0d3" nil) ;; zenburn-blue
	("variable" "\\<\\w+\\(Var\\|_v\\)\\>" "Grey50" "#dfaf8f" nil))) ;; zenburn-orange

(setq vhdl-file-header 
"-------------------------------------------------------------------------------
-- Title      : <title string>
-------------------------------------------------------------------------------
-- Company    : <company>
-- Platform   : <platform>
-- Standard   : <standard>
<projectdesc>-------------------------------------------------------------------------------
-- Description: <cursor>
-------------------------------------------------------------------------------
-- This file is part of <Project string>. It is subject to
-- the license terms in the LICENSE.txt file found in the top-level directory
-- of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of <Project string>, including this file, may be
-- copied, modified, propagated, or distributed except according to the terms
-- contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
")
(custom-set-faces
 '(trailing-whitespace ((t (:background "misty rose"))))
 '(vhdl-font-lock-function-face ((((class color) (background dark)) (:foreground "#dc8cc3")))))
(setq vhdl-basic-offset 3) ;; Sigh
(setq auto-mode-alist (cons  '("\\.vho\\'" . vhdl-mode) auto-mode-alist)) ;; .vho instantiation templates use vhdl mode
(setq auto-mode-alist (cons  '("\\.vhf\\'" . vhdl-mode) auto-mode-alist)) ;; .vhf sch2hdl files use vhdl mode
(setq vhdl-package-file-name '(".*" . "\\&Pkg"))
(setq vhdl-instance-name '(".*" . "U_\\&_%d"))
(setq vhdl-include-direction-comments t)
(setq vhdl-testbench-declarations "")
(setq vhdl-testbench-dut-name (quote (".*" . "U_\\&")))
(setq vhdl-testbench-entity-name (quote (".*" . "\\&Tb")))
(setq vhdl-testbench-include-configuration nil)
(setq vhdl-testbench-statements "  
U_ClkRst_1 : entity work.ClkRst
   generic map (
      CLK_PERIOD_G      => 10 ns,
      CLK_DELAY_G       => 1 ns,
      RST_START_DELAY_G => 0 ns,
      RST_HOLD_TIME_G   => 5 us,
      SYNC_RESET_G      => true)
   port map (
      clkP => ,
      clkN => ,
      rst  => ,
      rstL => );")



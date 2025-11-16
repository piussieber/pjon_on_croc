ROOT_DIR    := $(shell pwd)
VIVADO_DIR  := $(ROOT_DIR)/vivado
SCRIPTS_DIR := $(ROOT_DIR)/vivado/scripts

PROJ_NAME := croc

VIVADO ?= vitis-2023.2 vivado

.PHONY: create_vivado
create_vivado:
	cd $(VIVADO_DIR) && $(VIVADO) -mode tcl -source $(SCRIPTS_DIR)/flow.tcl

.PHONY: open_vivado
open_vivado: $(VIVADO_DIR)/$(PROJ_NAME).xpr
	cd $(VIVADO_DIR) && $(VIVADO) $(VIVADO_DIR)/$(PROJ_NAME).xpr

.PHONY: clean
clean:
	cd $(VIVADO_DIR) && rm -rf $(PROJ_NAME).* .Xil vivado.* vivado_* ips

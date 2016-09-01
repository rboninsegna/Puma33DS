rwildcard = $(foreach d, $(wildcard $1*), $(filter $(subst *, %, $2), $d) $(call rwildcard, $d/, $2))

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

include $(DEVKITARM)/3ds_rules

CC := arm-none-eabi-gcc
AS := arm-none-eabi-as
LD := arm-none-eabi-ld
OC := arm-none-eabi-objcopy

name := Puma33DS
revision := $(shell git describe --tags --match v[0-9]* --abbrev=8 | sed 's/-[0-9]*-g/-/i')
commit := $(shell git rev-parse --short=8 HEAD)

dir_source := source
dir_patches := patches
dir_loader := loader
dir_injector := injector
dir_build := build
dir_out := out

ASFLAGS := -mcpu=arm946e-s
CFLAGS := -Wall -Wextra -MMD -MP -marm $(ASFLAGS) -fno-builtin -fshort-wchar -std=c11 -Wno-main -O2 -flto -ffast-math
LDFLAGS := -nostartfiles

objects = $(patsubst $(dir_source)/%.s, $(dir_build)/%.o, \
          $(patsubst $(dir_source)/%.c, $(dir_build)/%.o, \
          $(call rwildcard, $(dir_source), *.s *.c)))

bundled = $(dir_build)/rebootpatch.h $(dir_build)/emunandpatch.h $(dir_build)/svcGetCFWInfopatch.h $(dir_build)/twl_k11modulespatch.h \
          $(dir_build)/injector.h $(dir_build)/loader.h

.PHONY: all
all: a9lh

.PHONY: a9lh
a9lh: $(dir_out)/arm9loaderhax.bin

.PHONY: release
release: $(dir_out)/$(name)$(revision).7z

.PHONY: clean
clean:
	@$(MAKE) -C $(dir_loader) clean
	@$(MAKE) -C $(dir_injector) clean
	@rm -rf $(dir_out) $(dir_build)

$(dir_out):
	@mkdir -p "$(dir_out)"

$(dir_out)/arm9loaderhax.bin: $(dir_build)/main.bin $(dir_out)
	@cp -a $(dir_build)/main.bin $@

$(dir_out)/$(name)$(revision).7z: a9lh
	@7z a -mx $@ ./$(@D)/*

$(dir_build)/main.bin: $(dir_build)/main.elf
	$(OC) -S -O binary $< $@

$(dir_build)/main.elf: $(objects)
	$(LINK.o) -T linker.ld $(OUTPUT_OPTION) $^

$(dir_build)/emunandpatch.h: $(dir_patches)/emunand.s $(dir_injector)/Makefile
	@mkdir -p "$(@D)"
	@armips $<
	@bin2c -o $@ -n emunand $(@D)/emunand.bin

$(dir_build)/rebootpatch.h: $(dir_patches)/reboot.s
	@mkdir -p "$(@D)"
	@armips $<
	@bin2c -o $@ -n reboot $(@D)/reboot.bin

$(dir_build)/svcGetCFWInfopatch.h: $(dir_patches)/svcGetCFWInfo.s
	@mkdir -p "$(@D)"
	@armips $<
	@bin2c -o $@ -n svcGetCFWInfo $(@D)/svcGetCFWInfo.bin

$(dir_build)/twl_k11modulespatch.h: $(dir_patches)/twl_k11modules.s
	@mkdir -p "$(@D)"
	@armips $<
	@bin2c -o $@ -n twl_k11modules $(@D)/twl_k11modules.bin

$(dir_build)/injector.h: $(dir_injector)/Makefile
	@mkdir -p "$(@D)"
	@$(MAKE) -C $(dir_injector)
	@bin2c -o $@ -n injector $(@D)/injector.cxi

$(dir_build)/loader.h: $(dir_loader)/Makefile
	@$(MAKE) -C $(dir_loader)
	@bin2c -o $@ -n loader $(@D)/loader.bin

$(dir_build)/memory.o $(dir_build)/strings.o: CFLAGS += -O3
$(dir_build)/config.o: CFLAGS += -DCONFIG_TITLE="\"$(name) $(revision) configuration\""
$(dir_build)/patches.o: CFLAGS += -DREVISION=\"$(revision)\" -DCOMMIT_HASH="0x$(commit)"

$(dir_build)/%.o: $(dir_source)/%.c $(bundled)
	@mkdir -p "$(@D)"
	$(COMPILE.c) $(OUTPUT_OPTION) $<

$(dir_build)/%.o: $(dir_source)/%.s
	@mkdir -p "$(@D)"
	$(COMPILE.s) $(OUTPUT_OPTION) $<
include $(call rwildcard, $(dir_build), *.d)

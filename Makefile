name=rmodepdf
TEXMFHOME = $(shell kpsewhich -var-value=TEXMFHOME)
INSTALL_DIR = $(TEXMFHOME)/scripts/lua/$(name)
BIN_DIR = $(HOME)/.local/bin
SYSTEM_DIR = $(realpath $(BIN_DIR))
EXECUTABLE = $(SYSTEM_DIR)/$(name)

# use sudo for install to destination directory outise home
ifeq ($(findstring home,$(SYSTEM_DIR)),home)
	SUDO:=
else
	SUDO:=sudo
endif

# install the executable only if the symlink doesn't exist yet
ifeq ("$(wildcard $(EXECUTABLE))","")
	INSTALL_COMMAND:=$(SUDO) ln -s $(INSTALL_DIR)/$(name) $(EXECUTABLE)
else
	INSTALL_COMMAND:=
endif

install:
	@mkdir -p $(INSTALL_DIR)
	@cp src/*.lua  src/rmodepdf $(INSTALL_DIR)
	echo $(wildcard $(EXECUTABLE))
	$(INSTALL_COMMAND)



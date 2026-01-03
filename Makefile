BUILD_DIR = ./build
TARGET = unending.exe

COMP_FLAGS = -vet-style -vet-semicolon -o:speed
FLAGS = --fullscreen=true

.PHONY: all build
all: build run

build:
	odin build source $(COMP_FLAGS) -out:$(BUILD_DIR)/$(TARGET)

run:
	$(BUILD_DIR)/$(TARGET) $(FLAGS)

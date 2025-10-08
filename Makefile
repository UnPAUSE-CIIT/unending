BUILD_DIR = ./build
TARGET = unending

COMP_FLAGS = -vet-style -vet-semicolon -o:speed
FLAGS = --fullscreen false

.PHONY: all build
all: build run

build:
	odin build source $(COMP_FLAGS) -out:$(BUILD_DIR)/$(TARGET)

run: 
	$(BUILD_DIR)/$(TARGET) $(FLAGS)

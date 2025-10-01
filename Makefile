BUILD_DIR = ./build
TARGET = unending

FLAGS = -vet-style -vet-semicolon -o:speed

.PHONY: all build
all: build run

build:
	odin build source $(FLAGS) -out:$(BUILD_DIR)/$(TARGET)

run: 
	$(BUILD_DIR)/$(TARGET)

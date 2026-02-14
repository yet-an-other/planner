APP_NAME := planner-back
BIN_DIR := bin

.PHONY: build clean

build:
	mkdir -p $(BIN_DIR)
	go build -o $(BIN_DIR)/$(APP_NAME) .

clean:
	rm -rf $(BIN_DIR)

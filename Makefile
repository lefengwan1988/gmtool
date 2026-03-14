.PHONY: all build build-windows build-linux clean test run

# 项目名称
BINARY_NAME=gmtool
MAIN_FILE=main_new.go

# 版本信息
VERSION=2.0.0
BUILD_TIME=$(shell date +%Y%m%d_%H%M%S)

# Go 参数
GOBASE=$(shell pwd)
GOBIN=$(GOBASE)/bin
GOFILES=$(wildcard *.go)

# 编译标志
LDFLAGS=-ldflags "-s -w"

all: clean build

# 编译所有平台
build: build-windows build-linux

# 编译 Windows 版本
build-windows:
	@echo "编译 Windows 版本..."
	@GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY_NAME).exe $(MAIN_FILE)
	@echo "Windows 版本编译完成: bin/$(BINARY_NAME).exe"

# 编译 Linux 版本
build-linux:
	@echo "编译 Linux 版本..."
	@GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o bin/$(BINARY_NAME)_linux $(MAIN_FILE)
	@echo "Linux 版本编译完成: bin/$(BINARY_NAME)_linux"

# 运行程序
run:
	@go run $(MAIN_FILE)

# 测试
test:
	@echo "运行测试..."
	@go test -v ./...

# 清理编译文件
clean:
	@echo "清理编译文件..."
	@rm -rf bin/
	@mkdir -p bin/
	@echo "清理完成"

# 格式化代码
fmt:
	@echo "格式化代码..."
	@go fmt ./...

# 代码检查
lint:
	@echo "代码检查..."
	@golangci-lint run ./...

# 安装依赖
deps:
	@echo "安装依赖..."
	@go mod download
	@go mod tidy

# 显示帮助
help:
	@echo "可用命令："
	@echo "  make build          - 编译所有平台版本"
	@echo "  make build-windows  - 编译 Windows 版本"
	@echo "  make build-linux    - 编译 Linux 版本"
	@echo "  make run            - 运行程序"
	@echo "  make test           - 运行测试"
	@echo "  make clean          - 清理编译文件"
	@echo "  make fmt            - 格式化代码"
	@echo "  make deps           - 安装依赖"


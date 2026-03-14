package main

import (
	"fmt"
	"os"

	"gohequ/cmd"
)

func main() {
	// 使用 Lua 版本
	if err := cmd.RunLua(); err != nil {
		fmt.Fprintf(os.Stderr, "错误: %v\n", err)
		os.Exit(1)
	}
}

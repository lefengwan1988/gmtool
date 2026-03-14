# 🎮 游戏服务器合区工具 / Game Server Merge Tool

<div align="center">

[![Version](https://img.shields.io/badge/version-v2.1.0--Lua-blue.svg)](https://github.com/lefengwan1988/gmtool)
[![Go Version](https://img.shields.io/badge/go-%3E%3D1.19-00ADD8.svg)](https://golang.org/)
[![Lua](https://img.shields.io/badge/lua-5.1-000080.svg)](https://www.lua.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**专业的游戏服务器合区解决方案 | Professional Game Server Merging Solution**

[简体中文](#简体中文) | [English](#english)

</div>

---

## 简体中文

### 📖 项目简介

游戏服务器合区工具是一个基于 **Go + Lua** 混合架构的专业合区解决方案，支持热更新、进度可视化、多游戏适配。通过 Lua 脚本驱动，无需重新编译即可快速适配新游戏。

### ✨ 核心特性

- 🔥 **热更新支持** - 修改 Lua 脚本无需重新编译 Go 代码
- 🎯 **多游戏支持** - 已适配 11 款游戏，5 分钟添加新游戏
- 📊 **进度可视化** - 实时显示合区进度条和状态
- 🎨 **美化界面** - ASCII 艺术字 + ANSI 颜色 + Emoji 图标
- 🔒 **独立配置** - 每个游戏独立的数据库和合区配置
- ⚡ **高性能** - Go 语言核心 + Lua 脚本灵活性
- 🛡️ **安全可靠** - 完整的错误处理和日志记录

### 🎮 支持的游戏

| 序号 | 游戏名称 | 脚本文件 | 状态 |
|-----|---------|---------|------|
| 1 | 奥拉的冒险 | `ald.lua` | ✅ |
| 2 | 不见长安 | `bjcx.lua` | ✅ |
| 3 | 大秦无双 | `dqws.lua` | ✅ |
| 4 | 灰烬远梦 | `hhym.lua` | ✅ |
| 5 | 横扫三军 | `hssj.lua` | ✅ |
| 6 | 乱斗 | `lz.lua` | ✅ |
| 7 | 魔幻西游 | `mhxy.lua` | ✅ |
| 8 | 摸金迷城 | `mjmc.lua` | ✅ |
| 9 | 魔灵修真 | `mlxz.lua` | ✅ |
| 10 | 主公别闹 | `zmtx.lua` | ✅ |
| 11 | 示例游戏 | `example.lua` | ✅ |
| 🆕 | **通用合区工具** | `universal_merge.lua` | ✅ **新增** |

> 💡 **通用合区工具**：支持读取易语言旧版 JSON 配置，兼容 20+ 款游戏，无需编写新脚本！详见 [通用合区工具说明](#-通用合区工具新增)

### 🚀 快速开始

#### 环境要求

- Go 1.19 或更高版本
- MySQL 5.7 或更高版本
- Windows / Linux / macOS

#### 安装步骤

```bash
# 1. 克隆项目
git clone https://github.com/lefengwan1988/gmtool.git
cd gmtool

# 2. 编译项目
go build -o bin/gmtool.exe main_new.go

# 3. 运行工具
./bin/gmtool.exe
```

#### 配置说明

每个游戏的 Lua 脚本包含三层配置：

**1. 数据库配置（必填）**

```lua
db_config = {
    user = "root",           -- 数据库用户名
    password = "root",       -- 数据库密码
    host = "127.0.0.1",     -- 数据库地址
}
```

**2. 合区配置（必填）**

```lua
merge_config = {
    main_server = "game1",   -- 主区数据库名
    sub_servers = {          -- 副区数据库名列表
        "game2",
        "game3",
    },
}
```

**3. 游戏配置（可选）**

```lua
game_config = {
    use_prefix = false,      -- 是否使用数据库前缀
    -- 其他游戏特定配置
}
```

### 📝 使用示例

#### 1. 修改游戏配置

编辑 `lua_skills/mhxy.lua`：

```lua
-- 修改数据库配置
db_config = {
    user = "your_username",
    password = "your_password",
    host = "192.168.1.100",
}

-- 修改合区配置
merge_config = {
    main_server = "main_game_db",
    sub_servers = {
        "sub_game_db1",
        "sub_game_db2",
    },
}
```

#### 2. 运行程序

```bash
./bin/gmtool.exe
```

#### 3. 选择游戏

```
可用的 Lua 技能:
1. 奥拉的冒险
2. 不见长安
3. 大秦无双
...
请输入数字选择游戏: 3
```

#### 4. 查看进度

```
[████████████████████░░░░░░░░] 80.0% 正在合并: user_data
```

### 🛠️ 开发新游戏

创建新的 Lua 脚本 `lua_skills/newgame.lua`：

```lua
-- @name: 新游戏
-- @description: 新游戏合区工具

-- 数据库配置
db_config = {
    user = "root",
    password = "root",
    host = "127.0.0.1",
}

-- 合区配置
merge_config = {
    main_server = "game1",
    sub_servers = {"game2"},
}

-- 游戏配置
game_config = {
    use_prefix = false,
}

-- 排除表列表
exclude_tables = {
    "log_table",
}

-- 执行函数
function execute(config)
    local main_server = merge_config.main_server
    local sub_servers = merge_config.sub_servers

    log.info("开始执行新游戏合区操作")

    for i, sub_server in ipairs(sub_servers) do
        local tables, err = db.get_tables(sub_server)
        if err then
            log.error("获取表列表失败: " .. err)
            return false, err
        end

        local total_tables = #tables
        for j, table_name in ipairs(tables) do
            if not util.contains(exclude_tables, table_name) then
                ui.progress(j, total_tables, "正在合并: " .. table_name)
                local success, err = db.merge_table(main_server, sub_server, table_name)
                if not success then
                    log.error("合并表失败: " .. err)
                end
            else
                ui.progress(j, total_tables, "跳过表: " .. table_name)
            end
        end
    end

    log.info("新游戏合区完成")
    return true
end

-- 验证函数
function validate(config)
    if not merge_config.main_server or merge_config.main_server == "" then
        return false, "主区不能为空"
    end

    if not merge_config.sub_servers or #merge_config.sub_servers == 0 then
        return false, "副区列表不能为空"
    end

    return true
end
```

### 📚 Lua API 参考

#### 日志 API

```lua
log.info("信息日志")
log.warn("警告日志")
log.error("错误日志")
log.debug("调试日志")
```

#### 数据库 API

```lua
-- 执行 SQL
local success, err = db.exec("UPDATE ...")

-- 查询数据
local result = db.query("SELECT ...")

-- 获取表列表
local tables, err = db.get_tables("database_name")

-- 合并表
local success, err = db.merge_table(main_db, sub_db, table_name)
```

#### 工具 API

```lua
-- 检查数组是否包含元素
local found = util.contains(array, value)

-- 从字符串提取数字
local number = util.extract_number("game123")

-- 读取文件内容（新增）
local content, err = util.read_file(filepath)
```

#### JSON API（新增）

```lua
-- 解析 JSON 字符串
local data, err = json.decode(json_string)

-- 编码为 JSON 字符串
local json_str, err = json.encode(lua_table)
```

#### UI API

```lua
-- 显示进度条
ui.progress(current, total, "正在处理...")
```

### 🆕 通用合区工具（新增）

#### 特性说明

通用合区工具是一个**革命性的功能**，它能够：

- ✅ **完全兼容**易语言旧版 JSON 配置格式
- ✅ **零迁移成本**：直接使用现有的 20+ 个 JSON 配置文件
- ✅ **三种合区类型**：支持 Type 1/2/3 所有合区模式
- ✅ **智能处理**：自动 ID 偏移、前缀后缀、服务器 ID 更新
- ✅ **高度可配置**：支持所有易语言版本的配置项

#### 支持的游戏（通过 JSON 配置）

在 `legacy_configs/script/` 目录下的所有游戏：

| 游戏 | JSON 文件 | 类型 | 游戏 | JSON 文件 | 类型 |
|-----|----------|------|-----|----------|------|
| 攻城掠地 | gcld.json | Type 2 | 蛮荒记 | mhj.json | Type 3 |
| 大侠无双 | djws.json | - | 龙OL | longol.json | - |
| 梦幻江湖 | mhj.json | - | 神域之战 | syz.json | - |
| 天下雄图 | txxt.json | - | 天域大陆 | tydl.json | - |
| 武神之王 | wszw.json | - | 新火烧赤壁 | xhtsgs.json | - |

...以及更多 20+ 款游戏！

#### 快速使用

**1. 配置数据库和合区参数**

编辑 `lua_skills/universal_merge.lua`：

```lua
-- 数据库配置
db_config = {
    user = "root",
    password = "root",
    host = "127.0.0.1:3306",
}

-- 合区配置
merge_config = {
    main_server = "s1",           -- 主区数据库名
    sub_servers = {"s2"},         -- 副区数据库名列表
    json_script = "gcld.json",    -- 选择对应游戏的 JSON 配置
}
```

**2. 运行工具**

```bash
./bin/gmtool.exe
# 选择"通用合区工具"
```

**3. 查看详细文档**

- 📖 [使用说明](legacy_configs/通用合区工具使用说明.md)
- 🏗️ [架构说明](legacy_configs/通用合区工具架构说明.md)
- 🚀 [快速配置向导](legacy_configs/快速配置向导.md)
- 📊 [项目总结](legacy_configs/项目总结.md)

#### 合区类型说明

**Type 1: 简单合并**
- 只处理 `other_identity` 字段
- 适用于简单的数据合并场景

**Type 2: 复杂合并**
- 处理 `same` 组（相同字段组）
- 处理 `other_identity` 字段
- 支持 ID 重构和特殊字段处理
- 适用于复杂的关联数据合并

**Type 3: 简单处理**
- 使用 `simple_process` 配置
- 自动处理主键和关联字段
- 适用于标准化的数据库结构

#### 技术优势

| 特性 | 易语言版本 | Go+Lua 通用工具 |
|-----|----------|----------------|
| 性能 | 一般 | ⚡ 高性能 |
| 跨平台 | ❌ 仅 Windows | ✅ 全平台 |
| 配置复用 | - | ✅ 完全兼容 |
| 可维护性 | 低 | ✅ 高 |
| 扩展性 | 低 | ✅ 高 |
| 调试 | 困难 | ✅ 简单 |

### 🏗️ 项目结构

```
gmtool/
├── bin/                    # 编译输出目录
│   └── gmtool.exe
├── cmd/                    # 命令行入口
│   └── root_lua.go
├── internal/               # 内部包
│   ├── logger/            # 日志模块
│   └── luaengine/         # Lua 引擎（已扩展 JSON API）
├── lua_skills/            # Lua 脚本目录
│   ├── ald.lua
│   ├── bjcx.lua
│   ├── dqws.lua
│   ├── universal_merge.lua  # 🆕 通用合区工具
│   └── ...
├── legacy_configs/         # 🆕 易语言配置和文档
│   ├── script/            # JSON 配置文件目录（20+ 个游戏）
│   │   ├── gcld.json     # 攻城掠地配置
│   │   ├── mhj.json      # 蛮荒记配置
│   │   └── ...
│   ├── 通用合区工具使用说明.md      # 🆕 使用指南
│   ├── 通用合区工具架构说明.md      # 🆕 架构文档
│   ├── 快速配置向导.md              # 🆕 配置向导
│   └── 项目总结.md                  # 🆕 项目总结
├── main_new.go            # 主程序入口
├── go.mod
├── go.sum
└── README.md
```

### ⚠️ 注意事项

1. **备份数据库** - 合区前务必备份所有数据库
2. **关闭服务器** - 合区时必须关闭游戏服务器

## English

### 📖 Introduction

The Game Server Merge Tool is a professional merging solution based on a **Go + Lua** hybrid architecture. It supports hot-reloading, visual progress bars, and multi-game adaptation. Driven by Lua scripts, it can quickly adapt to new games without recompiling.

### ✨ Key Features

- 🔥 **Hot Reload Support** - Modify Lua scripts without recompiling Go code
- 🎯 **Multi-Game Support** - 11 games adapted, add a new game in 5 minutes
- 📊 **Visual Progress** - Real-time merging progress bar and status display
- 🎨 **Beautified UI** - ASCII Art + ANSI Colors + Emoji Icons
- 🔒 **Independent Configs** - Independent database and merge configs for each game
- ⚡ **High Performance** - Go language core + Lua script flexibility
- 🛡️ **Safe & Reliable** - Complete error handling and logging

### 🎮 Supported Games

| No. | Game Name | Script File | Status |
|-----|-----------|-------------|--------|
| 1 | Aura's Adventure | `ald.lua` | ✅ |
| 2 | Unseen Chang'an | `bjcx.lua` | ✅ |
| 3 | Great Qin Warriors | `dqws.lua` | ✅ |
| 4 | Ash Dreams | `hhym.lua` | ✅ |
| 5 | Sweep Three Kingdoms | `hssj.lua` | ✅ |
| 6 | Brawl | `lz.lua` | ✅ |
| 7 | Magic West | `mhxy.lua` | ✅ |
| 8 | Tomb Raider | `mjmc.lua` | ✅ |
| 9 | Demon Cultivation | `mlxz.lua` | ✅ |
| 10 | Lord Trouble | `zmtx.lua` | ✅ |
| 11 | Example Game | `example.lua` | ✅ |

### 🚀 Quick Start

#### Requirements

- Go 1.19 or higher
- MySQL 5.7 or higher
- Windows / Linux / macOS

#### Installation

```bash
# 1. Clone the project
git clone https://github.com/lefengwan1988/gmtool.git
cd gmtool

# 2. Compile the project
go build -o bin/gmtool.exe main_new.go

# 3. Run the tool
./bin/gmtool.exe
```

#### Configuration Guide

Each game's Lua script contains three layers of configuration:

**1. Database Configuration (Required)**

```lua
db_config = {
    user = "root",           -- Database username
    password = "root",       -- Database password
    host = "127.0.0.1",     -- Database host
}
```

**2. Merge Configuration (Required)**

```lua
merge_config = {
    main_server = "game1",   -- Main server database name
    sub_servers = {          -- Sub server database name list
        "game2",
        "game3",
    },
}
```

**3. Game Configuration (Optional)**

```lua
game_config = {
    use_prefix = false,      -- Whether to use database prefix
    -- Other game-specific configs
}
```

### 📝 Usage Example

#### 1. Modify Game Configuration

Edit `lua_skills/mhxy.lua`:

```lua
-- Modify database config
db_config = {
    user = "your_username",
    password = "your_password",
    host = "192.168.1.100",
}

-- Modify merge config
merge_config = {
    main_server = "main_game_db",
    sub_servers = {
        "sub_game_db1",
        "sub_game_db2",
    },
}
```

#### 2. Run the Program

```bash
./bin/gmtool.exe
```

#### 3. Select a Game

```
Available Lua Skills:
1. Aura's Adventure
2. Unseen Chang'an
3. Great Qin Warriors
...
Please enter a number to select a game: 3
```

#### 4. Check Progress

```
[████████████████████░░░░░░░░] 80.0% Merging: user_data
```

### 🛠️ Developing a New Game

Create a new Lua script `lua_skills/newgame.lua`:

```lua
-- @name: New Game
-- @description: New Game Merge Tool

-- Database Config
db_config = {
    user = "root",
    password = "root",
    host = "127.0.0.1",
}

-- Merge Config
merge_config = {
    main_server = "game1",
    sub_servers = {"game2"},
}

-- Game Config
game_config = {
    use_prefix = false,
}

-- Exclude Tables
exclude_tables = {
    "log_table",
}

-- Execute Function
function execute(config)
    local main_server = merge_config.main_server
    local sub_servers = merge_config.sub_servers

    log.info("Starting New Game merge operation")

    for i, sub_server in ipairs(sub_servers) do
        local tables, err = db.get_tables(sub_server)
        if err then
            log.error("Failed to get table list: " .. err)
            return false, err
        end

        local total_tables = #tables
        for j, table_name in ipairs(tables) do
            if not util.contains(exclude_tables, table_name) then
                ui.progress(j, total_tables, "Merging: " .. table_name)
                local success, err = db.merge_table(main_server, sub_server, table_name)
                if not success then
                    log.error("Failed to merge table: " .. err)
                end
            else
                ui.progress(j, total_tables, "Skipping: " .. table_name)
            end
        end
    end

    log.info("New Game merge completed")
    return true
end

-- Validate Function
function validate(config)
    if not merge_config.main_server or merge_config.main_server == "" then
        return false, "Main server cannot be empty"
    end

    if not merge_config.sub_servers or #merge_config.sub_servers == 0 then
        return false, "Sub server list cannot be empty"
    end

    return true
end
```

### 📚 Lua API Reference

#### Log API

```lua
log.info("Info message")
log.warn("Warning message")
log.error("Error message")
log.debug("Debug message")
```

#### Database API

```lua
-- Execute SQL
local success, err = db.exec("UPDATE ...")

-- Query data
local result = db.query("SELECT ...")

-- Get table list
local tables, err = db.get_tables("database_name")

-- Merge table
local success, err = db.merge_table(main_db, sub_db, table_name)
```

#### Util API

```lua
-- Check if array contains element
local found = util.contains(array, value)

-- Extract number from string
local number = util.extract_number("game123")
```

#### UI API

```lua
-- Show progress bar
ui.progress(current, total, "Processing...")
```

### ⚠️ Important Notes

1. **Backup Database** - Always backup all databases before merging
2. **Close Servers** - Game servers must be closed during merging
3. **Test Environment** - Verify in a test environment first
4. **Stable Network** - Ensure stable database connection
5. **Permissions** - Ensure database user has sufficient privileges

### 📞 Contact

- **Author**: LeFengWan
- **WeChat**: clzpb2002
- **Purpose**: GM Mobile Game Box Proxy, Game Cooperation

---

### 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

### 📞 联系方式

- **作者**: 乐疯玩
- **微信**: clzpb2002
- **用途**: GM手游盒子招代理，游戏合作

---



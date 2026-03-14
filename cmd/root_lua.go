package cmd

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"strings"

	"gohequ/internal/logger"
	"gohequ/internal/luaengine"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
	"github.com/sirupsen/logrus"
	lua "github.com/yuin/gopher-lua"
)

const VersionLua = "V2.1.0-Lua"

// RunLua 运行 Lua 版本的主程序
func RunLua() error {
	// 初始化日志
	logger.Init()

	// 显示欢迎信息
	showWelcomeLua()

	// 加载 Lua 技能
	loader := luaengine.NewSkillLoader("./lua_skills")
	if err := loader.LoadAll(); err != nil {
		return fmt.Errorf("加载技能失败: %v", err)
	}

	// 显示技能列表
	fmt.Println("\033[1;36m [ 可用合区游戏列表 ] \033[0m")
	skills := loader.ListSkills()
	for i, skill := range skills {
		fmt.Printf("\033[32m%2d:\033[0m \033[1;37m%s\033[0m", i+1, skill.Name)
		if skill.Description != "" {
			fmt.Printf(" \033[90m- %s\033[0m", skill.Description)
		}
		fmt.Println()
	}

	fmt.Println("\n\033[1;33m" + strings.Repeat("=", 60) + "\033[0m")
	fmt.Println("\033[1;35m PS: 正规GM手游盒子招代理微信：clzpb2002，有好游戏也可以联系我们合作。\033[0m")
	fmt.Printf("\033[36m 当前版本：%s (Lua 脚本驱动)\033[0m\n", VersionLua)
	fmt.Println("\033[1;33m" + strings.Repeat("=", 60) + "\033[0m\n")

	// 读取用户选择游戏
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("\033[1;32m请输入数字选择游戏: \033[0m")
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)

	var choice int
	if _, err := fmt.Sscanf(input, "%d", &choice); err != nil || choice < 1 || choice > len(skills) {
		return fmt.Errorf("无效输入")
	}
	selectedSkill := skills[choice-1]

	logrus.Infof("已选择: %s", selectedSkill.Name)
	fmt.Println()

	// 创建临时 Lua 引擎来读取数据库配置
	tempEngine := luaengine.NewLuaEngine(nil)
	defer tempEngine.Close()

	// 加载脚本获取数据库配置
	if err := tempEngine.LoadScript(selectedSkill.FilePath); err != nil {
		return fmt.Errorf("加载脚本失败: %v", err)
	}

	// 读取数据库配置
	dbConfigTable := tempEngine.L.GetGlobal("db_config")
	if dbConfigTable.Type() != lua.LTTable {
		return fmt.Errorf("脚本缺少 db_config 配置")
	}

	dbUser := tempEngine.L.GetField(dbConfigTable, "user").String()
	dbPassword := tempEngine.L.GetField(dbConfigTable, "password").String()
	dbHost := tempEngine.L.GetField(dbConfigTable, "host").String()

	if dbUser == "" || dbHost == "" {
		return fmt.Errorf("数据库配置不完整，请检查 db_config")
	}

	logrus.Infof("数据库配置: %s@%s", dbUser, dbHost)
	fmt.Println()

	// 读取合区配置
	mergeConfigTable := tempEngine.L.GetGlobal("merge_config")
	if mergeConfigTable.Type() != lua.LTTable {
		return fmt.Errorf("脚本缺少 merge_config 配置")
	}
	// 兼容两种配置形式：
	// 1) 简单版：main_server = "game1", sub_servers = {"game2","game3"}
	// 2) 通用版：main_server = { db_name="game1", server_id="1", ... }
	//             sub_servers = { { db_name="game2", server_id="2", ... }, ... }

	mainServerValue := tempEngine.L.GetField(mergeConfigTable, "main_server")
	var mainServerDisplay string

	if tbl, ok := mainServerValue.(*lua.LTable); ok {
		// 通用合区工具风格
		dbName := tempEngine.L.GetField(tbl, "db_name").String()
		if dbName == "" {
			return fmt.Errorf("主区数据库名不能为空")
		}
		serverID := tempEngine.L.GetField(tbl, "server_id").String()
		if serverID != "" {
			mainServerDisplay = fmt.Sprintf("%s (ID: %s)", dbName, serverID)
		} else {
			mainServerDisplay = dbName
		}
	} else {
		// 其他脚本的简单字符串形式
		mainServerDisplay = mainServerValue.String()
		if mainServerDisplay == "" {
			return fmt.Errorf("主区数据库名不能为空")
		}
	}

	subServersTable := tempEngine.L.GetField(mergeConfigTable, "sub_servers")
	if subServersTable.Type() != lua.LTTable {
		return fmt.Errorf("副区配置格式错误")
	}

	var subServersDisplay []string
	subServersTable.(*lua.LTable).ForEach(func(_, value lua.LValue) {
		if tbl, ok := value.(*lua.LTable); ok {
			// 通用合区工具风格
			dbName := tempEngine.L.GetField(tbl, "db_name").String()
			if dbName == "" {
				return
			}
			serverID := tempEngine.L.GetField(tbl, "server_id").String()
			if serverID != "" {
				subServersDisplay = append(subServersDisplay, fmt.Sprintf("%s (ID: %s)", dbName, serverID))
			} else {
				subServersDisplay = append(subServersDisplay, dbName)
			}
		} else if str := value.String(); str != "" {
			// 其他脚本的简单字符串形式
			subServersDisplay = append(subServersDisplay, str)
		}
	})

	if len(subServersDisplay) == 0 {
		return fmt.Errorf("副区列表不能为空")
	}

	logrus.Infof("主区: %s", mainServerDisplay)
	logrus.Infof("副区: %s", strings.Join(subServersDisplay, ", "))
	fmt.Println()

	// 显示确认信息
	showConfirmationLua(mainServerDisplay, subServersDisplay)

	fmt.Println("按回车键继续...")
	fmt.Scanln()

	// 连接数据库
	connStr := fmt.Sprintf("%s:%s@tcp(%s)/?charset=utf8&parseTime=True&loc=Local",
		dbUser, dbPassword, dbHost)
	db, err := sqlx.Connect("mysql", connStr)
	if err != nil {
		return fmt.Errorf("数据库连接失败: %v", err)
	}
	defer db.Close()

	// 创建 Lua 引擎
	engine := luaengine.NewLuaEngine(db)
	defer engine.Close()

	// 加载选中的技能脚本
	if err := engine.LoadScript(selectedSkill.FilePath); err != nil {
		return err
	}

	// 准备空配置参数（配置已在 Lua 脚本中）
	luaConfig := engine.L.NewTable()

	// 调用验证函数
	validateFn := engine.L.GetGlobal("validate")
	if validateFn.Type() == lua.LTFunction {
		if err := engine.L.CallByParam(lua.P{
			Fn:      validateFn,
			NRet:    2,
			Protect: true,
		}, luaConfig); err != nil {
			return fmt.Errorf("验证配置失败: %v", err)
		}

		valid := engine.L.Get(-2)
		errMsg := engine.L.Get(-1)
		engine.L.Pop(2)

		if valid == lua.LFalse || valid == lua.LNil {
			return fmt.Errorf("配置验证失败: %s", errMsg.String())
		}
	}

	// 执行合区
	ctx := context.Background()
	_ = ctx // 暂时未使用

	executeFn := engine.L.GetGlobal("execute")
	if executeFn.Type() != lua.LTFunction {
		return fmt.Errorf("技能脚本缺少 execute 函数")
	}

	if err := engine.L.CallByParam(lua.P{
		Fn:      executeFn,
		NRet:    2,
		Protect: true,
	}, luaConfig); err != nil {
		return fmt.Errorf("执行合区失败: %v", err)
	}

	success := engine.L.Get(-2)
	errMsg := engine.L.Get(-1)
	engine.L.Pop(2)

	if success == lua.LFalse || success == lua.LNil {
		return fmt.Errorf("合区失败: %s", errMsg.String())
	}

	logrus.Info("所有操作完成！")
	return nil
}

func showWelcomeLua() {
	fmt.Println("\033[36m")
	fmt.Println("  ██████╗ ███╗   ███╗████████╗ ██████╗  ██████╗ ██╗     ")
	fmt.Println(" ██╔════╝ ████╗ ████║╚══██╔══╝██╔═══██╗██╔═══██╗██║     ")
	fmt.Println(" ██║  ███╗██╔████╔██║   ██║   ██║   ██║██║   ██║██║     ")
	fmt.Println(" ██║   ██║██║╚██╔╝██║   ██║   ██║   ██║██║   ██║██║     ")
	fmt.Println(" ╚██████╔╝██║ ╚═╝ ██║   ██║   ╚██████╔╝╚██████╔╝███████╗")
	fmt.Println("  ╚═════╝ ╚═╝     ╚═╝   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝")
	fmt.Println("\033[0m")
	fmt.Println("\033[1;33m" + strings.Repeat("=", 60) + "\033[0m")
	fmt.Println("\033[1;32m 欢迎使用游戏服务器合区工具 (Lua Pro Edition) \033[0m")
	fmt.Println("\033[1;33m" + strings.Repeat("=", 60) + "\033[0m")
	fmt.Println("\033[37m 请确认你的游戏版本是否为最新版，否则可能合区失败。\033[0m")
	fmt.Println()
	fmt.Println("\033[1;36m [ 可用合区游戏列表 ] \033[0m")
}

func showConfirmationLua(mainServer string, subServers []string) {
	fmt.Println("\n\033[1;33m" + strings.Repeat("=", 60) + "\033[0m")
	fmt.Printf("\033[1;32m 🚢 [主区]: \033[0m \033[1;37m%s\033[0m\n", mainServer)
	fmt.Printf("\033[1;34m 🛥️ [副区]: \033[0m \033[37m%s\033[0m\n", strings.Join(subServers, ", "))
	fmt.Println("\033[1;33m" + strings.Repeat("=", 60) + "\033[0m")
	fmt.Println("\033[1;31m ⚠️  [警告] 确认以上服务器将被合并！\033[0m")
	fmt.Println("\033[33m 💡 [提示] CTRL + C 可退出或中断程序\033[0m")
	fmt.Println("\033[33m 💡 [提示] 合服前请务必备份数据库，先关闭服务器再执行！\033[0m")
	fmt.Println("\033[1;35m 🛠️  合区工具 By 乐疯玩 \033[0m")
}

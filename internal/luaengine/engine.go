package luaengine

import (
	"fmt"

	"github.com/jmoiron/sqlx"
	"github.com/sirupsen/logrus"
	lua "github.com/yuin/gopher-lua"
	luar "layeh.com/gopher-luar"
)

// LuaEngine Lua 脚本引擎
type LuaEngine struct {
	L  *lua.LState
	db *sqlx.DB
}

// NewLuaEngine 创建新的 Lua 引擎
func NewLuaEngine(db *sqlx.DB) *LuaEngine {
	L := lua.NewState()
	engine := &LuaEngine{
		L:  L,
		db: db,
	}

	// 注册 API
	engine.registerAPI()

	return engine
}

// Close 关闭 Lua 引擎
func (e *LuaEngine) Close() {
	e.L.Close()
}

// LoadScript 加载 Lua 脚本文件
func (e *LuaEngine) LoadScript(filepath string) error {
	if err := e.L.DoFile(filepath); err != nil {
		return fmt.Errorf("加载 Lua 脚本失败: %v", err)
	}
	return nil
}

// CallFunction 调用 Lua 函数
func (e *LuaEngine) CallFunction(funcName string, args ...interface{}) error {
	fn := e.L.GetGlobal(funcName)
	if fn.Type() != lua.LTFunction {
		return fmt.Errorf("函数 %s 不存在", funcName)
	}

	// 准备参数
	luaArgs := make([]lua.LValue, len(args))
	for i, arg := range args {
		luaArgs[i] = luar.New(e.L, arg)
	}

	// 调用函数
	if err := e.L.CallByParam(lua.P{
		Fn:      fn,
		NRet:    0,
		Protect: true,
	}, luaArgs...); err != nil {
		return fmt.Errorf("调用 Lua 函数失败: %v", err)
	}

	return nil
}

// registerAPI 注册提供给 Lua 的 API
func (e *LuaEngine) registerAPI() {
	// 注册日志 API
	e.registerLogAPI()

	// 注册数据库 API
	e.registerDBAPI()

	// 注册工具 API
	e.registerUtilAPI()

	// 注册 UI API
	e.registerUIAPI()
}

// registerUIAPI 注册 UI 相关 API
func (e *LuaEngine) registerUIAPI() {
	uiTable := e.L.NewTable()

	// ui.progress(current, total, message)
	e.L.SetField(uiTable, "progress", e.L.NewFunction(func(L *lua.LState) int {
		current := L.CheckInt(1)
		total := L.CheckInt(2)
		message := L.OptString(3, "")

		percent := float64(current) / float64(total) * 100
		barLen := 40
		filledLen := int(float64(barLen) * float64(current) / float64(total))

		bar := ""
		for i := 0; i < barLen; i++ {
			if i < filledLen {
				bar += "█"
			} else {
				bar += "░"
			}
		}

		// 使用 \r 回到行首实现原地更新
		// \033[K 是清空光标到行尾
		fmt.Printf("\r\033[K\033[36m[%s] %.1f%% \033[0m %s", bar, percent, message)
		if current >= total {
			fmt.Println()
		}
		return 0
	}))

	e.L.SetGlobal("ui", uiTable)
}

// registerLogAPI 注册日志 API
func (e *LuaEngine) registerLogAPI() {
	logTable := e.L.NewTable()

	// log.info(message)
	e.L.SetField(logTable, "info", e.L.NewFunction(func(L *lua.LState) int {
		msg := L.CheckString(1)
		logrus.Info(msg)
		return 0
	}))

	// log.warn(message)
	e.L.SetField(logTable, "warn", e.L.NewFunction(func(L *lua.LState) int {
		msg := L.CheckString(1)
		logrus.Warn(msg)
		return 0
	}))

	// log.error(message)
	e.L.SetField(logTable, "error", e.L.NewFunction(func(L *lua.LState) int {
		msg := L.CheckString(1)
		logrus.Error(msg)
		return 0
	}))

	// log.debug(message)
	e.L.SetField(logTable, "debug", e.L.NewFunction(func(L *lua.LState) int {
		msg := L.CheckString(1)
		logrus.Debug(msg)
		return 0
	}))

	e.L.SetGlobal("log", logTable)
}

// registerDBAPI 注册数据库 API
func (e *LuaEngine) registerDBAPI() {
	dbTable := e.L.NewTable()

	// db.exec(sql)
	e.L.SetField(dbTable, "exec", e.L.NewFunction(func(L *lua.LState) int {
		sql := L.CheckString(1)
		_, err := e.db.Exec(sql)
		if err != nil {
			L.Push(lua.LNil)
			L.Push(lua.LString(err.Error()))
			return 2
		}
		L.Push(lua.LTrue)
		return 1
	}))

	// db.query(sql) - 返回表列表
	e.L.SetField(dbTable, "query", e.L.NewFunction(func(L *lua.LState) int {
		sql := L.CheckString(1)
		rows, err := e.db.Query(sql)
		if err != nil {
			L.Push(lua.LNil)
			L.Push(lua.LString(err.Error()))
			return 2
		}
		defer rows.Close()

		result := L.NewTable()
		idx := 1
		for rows.Next() {
			var value string
			if err := rows.Scan(&value); err != nil {
				continue
			}
			L.RawSetInt(result, idx, lua.LString(value))
			idx++
		}

		L.Push(result)
		return 1
	}))

	// db.get_tables(database) - 获取数据库所有表
	e.L.SetField(dbTable, "get_tables", e.L.NewFunction(func(L *lua.LState) int {
		database := L.CheckString(1)
		sql := fmt.Sprintf("SHOW TABLES FROM `%s`", database)
		rows, err := e.db.Query(sql)
		if err != nil {
			L.Push(lua.LNil)
			L.Push(lua.LString(err.Error()))
			return 2
		}
		defer rows.Close()

		tables := L.NewTable()
		idx := 1
		for rows.Next() {
			var table string
			if err := rows.Scan(&table); err != nil {
				continue
			}
			L.RawSetInt(tables, idx, lua.LString(table))
			idx++
		}

		L.Push(tables)
		return 1
	}))

	// db.merge_table(main_db, sub_db, table) - 合并表
	e.L.SetField(dbTable, "merge_table", e.L.NewFunction(func(L *lua.LState) int {
		mainDB := L.CheckString(1)
		subDB := L.CheckString(2)
		table := L.CheckString(3)

		sql := fmt.Sprintf("REPLACE INTO `%s`.`%s` SELECT * FROM `%s`.`%s`",
			mainDB, table, subDB, table)

		_, err := e.db.Exec(sql)
		if err != nil {
			L.Push(lua.LFalse)
			L.Push(lua.LString(err.Error()))
			return 2
		}

		L.Push(lua.LTrue)
		return 1
	}))

	e.L.SetGlobal("db", dbTable)
}

// registerUtilAPI 注册工具 API
func (e *LuaEngine) registerUtilAPI() {
	utilTable := e.L.NewTable()

	// util.contains(table, value) - 检查表中是否包含值
	e.L.SetField(utilTable, "contains", e.L.NewFunction(func(L *lua.LState) int {
		tbl := L.CheckTable(1)
		value := L.CheckString(2)

		found := false
		tbl.ForEach(func(k, v lua.LValue) {
			if v.String() == value {
				found = true
			}
		})

		L.Push(lua.LBool(found))
		return 1
	}))

	// util.extract_number(str) - 从字符串提取数字
	e.L.SetField(utilTable, "extract_number", e.L.NewFunction(func(L *lua.LState) int {
		str := L.CheckString(1)
		numStr := ""
		for _, ch := range str {
			if ch >= '0' && ch <= '9' {
				numStr += string(ch)
			}
		}
		if numStr == "" {
			L.Push(lua.LNumber(-1))
		} else {
			L.Push(lua.LString(numStr))
		}
		return 1
	}))

	e.L.SetGlobal("util", utilTable)
}

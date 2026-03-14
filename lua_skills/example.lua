-- @name: 示例游戏
-- @description: 这是一个示例 Lua 技能脚本，展示如何编写新游戏的合区逻辑

-- ============================================
-- 数据库配置（必填）
-- ============================================
db_config = {
    -- 数据库用户名
    user = "root",

    -- 数据库密码
    password = "root",

    -- 数据库地址（支持 IP:端口格式，如 127.0.0.1:3307）
    host = "127.0.0.1",
}

-- ============================================
-- 合区配置（必填）
-- ============================================
merge_config = {
    -- 主区数据库名
    main_server = "game1",

    -- 副区数据库名列表
    sub_servers = {
        "game2",
        -- 可以添加更多副区，例如：
        -- "game3",
        -- "game4",
    },
}

-- ============================================
-- 游戏配置（可根据实际情况修改）
-- ============================================
game_config = {
    -- 数据库前缀（如果游戏使用前缀）
    prefix = "",

    -- 是否使用数据库前缀
    use_prefix = false,

    -- 是否显示详细日志
    verbose = true,

    -- 其他游戏特定配置
    -- 例如：
    -- update_player_server_id = true,
    -- merge_guild_data = true,
    -- backup_before_merge = false,
}

-- 排除表列表（不需要合并的表）
exclude_tables = {
    "system_config",
    "system_log",
    -- 在这里添加更多不需要合并的表
}

-- 主函数：执行合区
-- @param config 配置对象，包含以下字段：
--   - main_server: 主区数据库名
--   - sub_servers: 副区数据库名列表（数组）
--   - prefix: 数据库前缀（可选，从 config.ini 读取）
--   - server_port: 服务器端口（可选）
--   - server_remote_port: 远程端口（可选）
function execute(config)
    log.info("开始执行示例游戏合区操作")
    log.info("主区: " .. config.main_server)
    log.info("副区: " .. table.concat(config.sub_servers, ", "))

    -- 显示游戏配置
    if game_config.verbose then
        log.info("游戏配置:")
        log.info("  使用前缀: " .. tostring(game_config.use_prefix))
        if game_config.use_prefix then
            log.info("  前缀: " .. game_config.prefix)
        end
    end
    
    -- 遍历所有副区
    for i, sub_server in ipairs(config.sub_servers) do
        log.info(string.format("正在合并副区 [%d/%d]: %s -> %s", 
            i, #config.sub_servers, sub_server, config.main_server))
        
        -- 获取副区所有表
        local tables, err = db.get_tables(sub_server)
        if err then
            log.error("获取表列表失败: " .. err)
            return false, err
        end
        
        -- 合并每个表
        local merged_count = 0
        for _, table_name in ipairs(tables) do
            -- 检查是否在排除列表中
            if not util.contains(exclude_tables, table_name) then
                log.debug("合并表: " .. table_name)
                
                local success, err = db.merge_table(config.main_server, sub_server, table_name)
                if success then
                    merged_count = merged_count + 1
                else
                    log.error("合并表失败 " .. table_name .. ": " .. err)
                    -- 可以选择继续或返回错误
                    -- return false, err
                end
            else
                log.debug("跳过表: " .. table_name)
            end
        end
        
        log.info(string.format("副区 %s 完成，共合并 %d 个表", sub_server, merged_count))
    end
    
    log.info("示例游戏合区完成")
    return true
end

-- 验证配置
-- @param config 配置对象
-- @return success, error_message
function validate(config)
    if not config.main_server or config.main_server == "" then
        return false, "主区ID不能为空"
    end
    
    if not config.sub_servers or #config.sub_servers == 0 then
        return false, "副区列表不能为空"
    end
    
    -- 可以添加更多验证逻辑
    
    return true
end

-- ============================================
-- 可用的 API 说明
-- ============================================

-- 日志 API (log)
-- log.info(message)    - 输出信息日志
-- log.warn(message)    - 输出警告日志
-- log.error(message)   - 输出错误日志
-- log.debug(message)   - 输出调试日志

-- 数据库 API (db)
-- db.exec(sql)                              - 执行 SQL 语句
-- db.query(sql)                             - 查询并返回结果
-- db.get_tables(database)                   - 获取数据库所有表
-- db.merge_table(main_db, sub_db, table)    - 合并表数据

-- 工具 API (util)
-- util.contains(table, value)               - 检查表中是否包含值
-- util.extract_number(str)                  - 从字符串提取数字

-- ============================================
-- 高级用法示例
-- ============================================

-- 示例1：条件合并
--[[
function merge_with_condition(main_db, sub_db, table_name, condition)
    local sql = string.format(
        "REPLACE INTO `%s`.`%s` SELECT * FROM `%s`.`%s` WHERE %s",
        main_db, table_name, sub_db, table_name, condition)
    return db.exec(sql)
end
]]

-- 示例2：更新数据
--[[
function update_server_id(database, old_id, new_id)
    local sql = string.format(
        "UPDATE `%s`.`players` SET server_id = %s WHERE server_id = %s",
        database, new_id, old_id)
    return db.exec(sql)
end
]]

-- 示例3：批量操作
--[[
local tables_to_merge = {"players", "items", "guilds"}
for _, table_name in ipairs(tables_to_merge) do
    db.merge_table(main_db, sub_db, table_name)
end
]]


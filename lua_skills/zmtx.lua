-- @name: 主公别闹
-- @description: 主公别闹(智谋天下)游戏合区工具

-- ============================================
-- 数据库配置（必填）
-- ============================================
db_config = {
    user = "root",
    password = "root",
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
    prefix = "",
    use_prefix = false,
}

-- 需要条件合并的表配置
conditional_tables = {
    {name = "t_account", condition = ""},
    {name = "t_player", condition = "accountUid <> 0"},
    {name = "t_recharge_activity", condition = "playerId >= 500000000"},
    {name = "t_friend", condition = "playerId >= 536884737"},
    {name = "t_competition_reward", condition = "playerId >= 500000000"},
    {name = "t_fund", condition = "playerId >= 500000000"},
    {name = "t_guild", condition = ""}
}

-- 主函数：执行合区
function execute(config)
    -- 使用脚本中的 merge_config
    local main_server = merge_config.main_server
    local sub_servers = merge_config.sub_servers

    log.info("开始执行主公别闹合区操作")
    log.info("主区: " .. main_server)

    local sub_list = {}
    for _, s in ipairs(sub_servers) do
        table.insert(sub_list, s)
    end
    log.info("副区: " .. table.concat(sub_list, ", "))

    -- 构建数据库名称
    local function build_db_name(server_id)
        if game_config.use_prefix and game_config.prefix ~= "" then
            return game_config.prefix .. "_" .. server_id
        end
        return server_id
    end

    local main_db = build_db_name(main_server)

    -- 遍历所有副区
    for i, sub_server in ipairs(sub_servers) do
        local sub_db = build_db_name(sub_server)
        log.info(string.format("正在合并副区 [%d/%d]: %s -> %s",
            i, #sub_servers, sub_db, main_db))
        
        -- 合并特定表
        local total_tables = #conditional_tables
        for j, tbl in ipairs(conditional_tables) do
            ui.progress(j, total_tables, "正在合并: " .. tbl.name)
            local sql
            if tbl.condition ~= "" then
                sql = string.format("REPLACE INTO `%s`.`%s` SELECT * FROM `%s`.`%s` WHERE %s",
                    main_db, tbl.name, sub_db, tbl.name, tbl.condition)
            else
                sql = string.format("REPLACE INTO `%s`.`%s` SELECT * FROM `%s`.`%s`",
                    main_db, tbl.name, sub_db, tbl.name)
            end
            
            local success, err = db.exec(sql)
            if success then
                log.debug("合并表成功: " .. tbl.name)
            else
                log.error("合并表失败 " .. tbl.name .. ": " .. err)
            end
        end
        
        log.info(string.format("副区 %s 完成", sub_db))
    end
    
    log.info("主公别闹合区完成")
    return true
end

-- 验证配置
function validate(config)
    if not merge_config.main_server or merge_config.main_server == "" then
        return false, "主区不能为空"
    end

    if not merge_config.sub_servers or #merge_config.sub_servers == 0 then
        return false, "副区列表不能为空"
    end

    return true
end


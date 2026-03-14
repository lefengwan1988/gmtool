-- @name: 灰烬远梦
-- @description: 灰烬远梦(洪荒遗梦)游戏合区工具

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
    use_prefix = false,
}

-- 排除表列表
exclude_tables = {
    "arenarerank",
    "openserverrankinglist",
    "openserverranking",
    "activityinfo",
    "ranking_sys",
    "worldservercommon",
    "qiecuorank",
    "openserverrankingactivity",
    "inthewildboss_scene",
    "hydramountaininfo",
    "godsoultreasurerecord",
    "glorytask_activity",
    "globaltreasury",
    "dbversion",
    "crosscontendinfo",
}

-- 主函数：执行合区
function execute(config)
    -- 使用脚本中的 merge_config
    local main_server = merge_config.main_server
    local sub_servers = merge_config.sub_servers
    
    log.info("开始执行灰烬远梦合区操作")
    log.info("主区: " .. main_server)
    
    local sub_list = {}
    for _, s in ipairs(sub_servers) do
        table.insert(sub_list, s)
    end
    log.info("副区: " .. table.concat(sub_list, ", "))
    
    -- 遍历所有副区
    for i, sub_server in ipairs(sub_servers) do
        local sub_db = sub_server
        
        log.info(string.format("正在合并副区 [%d/%d]: %s -> %s", 
            i, #sub_servers, sub_db, main_server))
        
        -- 获取所有表
        local tables, err = db.get_tables(sub_db)
        if err then
            log.error("获取表列表失败: " .. err)
            return false, err
        end
        
        -- 合并每个表
        local merged_count = 0
        local total_tables = #tables
        for j, table_name in ipairs(tables) do
            if not util.contains(exclude_tables, table_name) then
                ui.progress(j, total_tables, "正在合并: " .. table_name)
                local success, err = db.merge_table(main_server, sub_db, table_name)
                if success then
                    merged_count = merged_count + 1
                else
                    log.error("合并表失败 " .. table_name .. ": " .. err)
                end
            else
                ui.progress(j, total_tables, "跳过表: " .. table_name)
            end
        end
        
        log.info(string.format("副区 %s 完成，共合并 %d 个表", sub_db, merged_count))
    end
    
    log.info("灰烬远梦合区完成")
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


-- @name: 摸金迷城
-- @description: 摸金迷城游戏合区工具

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
    -- 是否使用数据库前缀（false 表示直接使用数据库名）
    use_prefix = false,

    -- 其他游戏特定配置
    -- 可以在这里添加更多配置项
}

-- 排除表列表
local exclude_tables = {
    "sys_rumor", "sys_mails", "squad_role", "role_vientiane_star",
    "role_task_event", "role_talisman_pos", "role_ta_constellation",
    "role_oa_lta", "role_kf_world_dungeon_rank", "role_goods_use_num",
    "role_goods_cd", "role_cache", "merge_count", "local_auction_sys",
    "local_auction_goods", "kw_ta_dragon_point_score", "kw_invade_server_rank_info",
    "kf_group", "kf_final_war_info", "guild_war_rank", "guild_war_guild_info",
    "guild", "filter_word", "ban_info", "node_kf", "kf_info", "node",
    "kf_game_server", "local_achievement_info", "node_kf_connect",
    "game_info", "global_data", "operation_activity_schedule",
    "charge", "object_rank", "role_dungeon_rank", "local_arena_rank_info"
}

-- 主函数：执行合区
function execute(config)
    -- 使用脚本中的 merge_config
    local main_server = merge_config.main_server
    local sub_servers = merge_config.sub_servers

    log.info("开始执行摸金迷城合区操作")
    log.info("主区: " .. main_server)

    local sub_list = {}
    for _, s in ipairs(sub_servers) do
        table.insert(sub_list, s)
    end
    log.info("副区: " .. table.concat(sub_list, ", "))

    local main_db = main_server

    -- 遍历所有副区
    for i, sub_server in ipairs(sub_servers) do
        local sub_db = sub_server
        log.info(string.format("正在合并副区 [%d/%d]: %s -> %s",
            i, #sub_servers, sub_db, main_db))
        
        -- 获取副区所有表
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
                local success, err = db.merge_table(main_db, sub_db, table_name)
                if success then
                    merged_count = merged_count + 1
                else
                    log.error("合并表失败 " .. table_name .. ": " .. err)
                end
            else
                ui.progress(j, total_tables, "跳过表: " .. table_name)
                log.debug("跳过表: " .. table_name)
            end
        end
        
        log.info(string.format("副区 %s 完成，共合并 %d 个表", sub_db, merged_count))
    end
    
    log.info("摸金迷城合区完成")
    return true
end

-- 验证配置
function validate(config)
    if not config.main_server or config.main_server == "" then
        return false, "主区ID不能为空"
    end
    
    if not config.sub_servers or #config.sub_servers == 0 then
        return false, "副区列表不能为空"
    end
    
    return true
end


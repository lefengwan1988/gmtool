-- @name: 奥拉的冒险
-- @description: 奥拉的冒险(阿拉德)游戏合区工具

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

    -- 是否更新角色名称
    update_player_name = true,

    -- 是否更新工会名称
    update_guild_name = true,

    -- 是否更新区服ID
    update_zone_id = true,
}

-- 排除表列表
exclude_tables = {
    "log_cli_error",
}

-- 主函数：执行合区
function execute(config)
    -- 使用脚本中的 merge_config
    local main_server = merge_config.main_server
    local sub_servers = merge_config.sub_servers
    
    log.info("开始执行奥拉的冒险合区操作")
    log.info("主区: " .. main_server)
    
    local sub_list = {}
    for _, s in ipairs(sub_servers) do
        table.insert(sub_list, s)
    end
    log.info("副区: " .. table.concat(sub_list, ", "))
    
    local main_server_id = util.extract_number(main_server)
    
    -- 遍历所有副区
    for i, sub_server in ipairs(sub_servers) do
        local sub_db = sub_server
        local sub_server_id = util.extract_number(sub_server)
        
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

                -- 特殊处理：更新角色名称和区服ID
                if table_name == "t_player_info" and game_config.update_player_name then
                    local update_name_sql = string.format(
                        "UPDATE `%s`.`t_player_info` SET `name` = CONCAT('s%d.', `name`)",
                        sub_db, sub_server_id)
                    db.exec(update_name_sql)
                    log.debug("更新角色名称完成")
                    
                    if game_config.update_zone_id then
                        local update_zone_sql = string.format(
                            "UPDATE `%s`.`t_player_info` SET zoneid = %d WHERE zoneid = %d",
                            sub_db, main_server_id, sub_server_id)
                        db.exec(update_zone_sql)
                        log.debug("更新区服ID完成")
                    end
                end
                
                -- 特殊处理：更新工会名称
                if table_name == "t_guild" and game_config.update_guild_name then
                    local update_guild_sql = string.format(
                        "UPDATE `%s`.`t_guild` SET `name` = CONCAT('s%d.', `name`)",
                        sub_db, sub_server_id)
                    db.exec(update_guild_sql)
                    log.debug("更新工会名称完成")
                end
                
                -- 特殊处理：更新工会成员名称
                if table_name == "t_guild_member" and game_config.update_guild_name then
                    local update_member_sql = string.format(
                        "UPDATE `%s`.`t_guild_member` SET `name` = CONCAT('s%d.', `name`)",
                        sub_db, sub_server_id)
                    db.exec(update_member_sql)
                    log.debug("更新工会成员名称完成")
                end
                
                -- 特殊处理：更新关系名称
                if table_name == "t_relation" then
                    local update_relation_sql = string.format(
                        "UPDATE `%s`.`t_relation` SET `name` = CONCAT('s%d.', `name`)",
                        sub_db, sub_server_id)
                    db.exec(update_relation_sql)
                    log.debug("更新关系名称完成")
                end
                
                -- 特殊处理：更新排序名称
                if table_name == "t_sortlist" then
                    local update_sortlist_sql = string.format(
                        "UPDATE `%s`.`t_sortlist` SET `name` = CONCAT('s%d.', `name`)",
                        sub_db, sub_server_id)
                    db.exec(update_sortlist_sql)
                    
                    local update_owner_sql = string.format(
                        "UPDATE `%s`.`t_sortlist` SET `ownername` = CONCAT('s%d.', `ownername`) WHERE `ownername` != ''",
                        sub_db, sub_server_id)
                    db.exec(update_owner_sql)
                    log.debug("更新排序名称完成")
                end

                -- 合并表数据
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

    log.info("奥拉的冒险合区完成")
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



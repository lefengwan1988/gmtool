-- @name: 大秦无双
-- @description: 大秦无双游戏合区工具

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
    -- 数据库前缀（必填）
    prefix = "xkm_server",

    -- 是否使用前缀（true/false）
    use_prefix = true,

    -- 其他游戏特定配置
    -- 可以在这里添加更多配置项
}

-- 排除表列表（不需要合并的表）
local exclude_tables = {
    "base_acc_stage_add_attr", "base_acc_star_add_attr", "base_achievement",
    "base_achievement_subtype", "base_achievement_type", "base_act_boss_reset",
    "base_act_cumu_pay", "base_act_daily_consume", "base_act_discount_shop",
    "base_act_discount_shop_new", "base_act_dragon_cave", "base_act_dragon_cave_shop",
    "node", "node_kf", "node_kf_connect", "uid", "lucky_wheel_log"
}

-- 主函数：执行合区
function execute(config)
    -- 使用脚本中的 merge_config
    local main_server = merge_config.main_server
    local sub_servers = merge_config.sub_servers

    log.info("开始执行大秦无双合区操作")
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
            -- 检查是否在排除列表中
            if not util.contains(exclude_tables, table_name) then
                ui.progress(j, total_tables, "正在合并: " .. table_name)
                local success, err = db.merge_table(main_db, sub_db, table_name)
                if success then
                    merged_count = merged_count + 1
                    log.debug("合并表成功: " .. table_name)
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
    
    log.info("大秦无双合区完成")
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


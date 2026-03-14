-- @name: 易语言迁移合区工具
-- @description: 基于易语言JSON脚本的通用合区工具，旧版已经不维护了   

-- ============================================
-- 数据库配置（必填）
-- ============================================
db_config = {
    user = "root",
    password = "123456",
    host = "127.0.0.1",
    port = "3306",
}

-- ============================================
-- 合区配置（必填）
-- ============================================
merge_config = {
    -- JSON脚本文件路径（相对于legacy_configs/script目录）
    json_script = "ymz.json",  -- 默认使用大秦无双的配置

    -- 主区配置
    main_server = {
        db_name = "s1",              -- 主区游戏数据库名
        server_id = "1",                -- 主区服务器ID
        account_db_name = "login_game1", -- 主区账号数据库名（如果账号库独立） 一般这里忽略即可
    },

    -- 副区配置列表（每个副区独立配置）
    sub_servers = {
        -- 副区1配置
        {
            db_name = "s2",              -- 副区游戏数据库名
            server_id = "2",                -- 副区服务器ID
            prefix = "2s",                  -- 角色名/公会名前缀或后缀
            account_suffix = "s2",          -- 账号名后缀
            account_db_name = "login_game2", -- 副区账号数据库名（如果账号库独立） 一般这里忽略即可
        },

        -- 副区2配置（示例，可以添加更多副区）
        -- {
        --     db_name = "game3",
        --     server_id = "3",
        --     prefix = "3s",
        --     account_suffix = "s3",
        --     account_db_name = "login_game3",
        -- },
    },
}

-- ============================================
-- 游戏配置
-- ============================================
game_config = {
    verbose = true,
    -- JSON脚本目录
    script_dir = "./legacy_configs/script/",
}

-- 全局变量
local script_config = nil
local max_id_cache = {}
local user_overrides = {}  -- 用户通过命令行覆盖的配置

-- ============================================
-- 命令行交互函数
-- ============================================

-- 显示欢迎信息和当前配置
local function show_welcome_and_config()
    log.info("=" .. string.rep("=", 58))
    log.info("通用合区工具 - 交互式配置")
    log.info("=" .. string.rep("=", 58))
    log.info("")
    log.info("当前配置:")
    log.info("  数据库地址: " .. db_config.host .. ":" .. db_config.port)
    log.info("  数据库用户: " .. db_config.user)
    log.info("  JSON脚本: " .. merge_config.json_script)
    log.info("")
    log.info("主区配置:")
    log.info("  游戏数据库: " .. merge_config.main_server.db_name)
    log.info("  账号数据库: " .. (merge_config.main_server.account_db_name or "无"))
    log.info("  服务器ID: " .. merge_config.main_server.server_id)
    log.info("")
    log.info("副区配置:")
    for i, sub in ipairs(merge_config.sub_servers) do
        log.info(string.format("  副区%d:", i))
        log.info(string.format("    游戏数据库: %s", sub.db_name))
        log.info(string.format("    账号数据库: %s", sub.account_db_name or "无"))
        log.info(string.format("    服务器ID: %s", sub.server_id))
        log.info(string.format("    前缀/后缀: %s", sub.prefix))
        log.info(string.format("    账号后缀: %s", sub.account_suffix))
    end
    log.info("")
end



-- 应用用户覆盖的配置到 JSON 配置（针对特定副区）
local function apply_user_overrides(script, sub_server_config)
    if not script or not script.script then
        return script
    end

    local s = script.script

    -- 应用主区/副区ID覆盖
    if merge_config.main_server.server_id then
        s.master_server = merge_config.main_server.server_id
    end

    if sub_server_config and sub_server_config.server_id then
        s.slave_server = sub_server_config.server_id
    end

    -- 应用前缀/后缀覆盖（针对当前副区）
    if s.prefix_setting and sub_server_config then
        if sub_server_config.prefix then
            s.prefix_setting.prefix = sub_server_config.prefix
        end
        if sub_server_config.account_suffix then
            s.prefix_setting.account_suffix = sub_server_config.account_suffix
        end
    end

    return script
end

-- 显示合区前的确认信息（针对特定副区）
local function show_merge_confirmation(script, sub_server_config, sub_index, total_subs)
    log.info("")
    log.info("=" .. string.rep("=", 58))
    log.info(string.format("合区确认信息 [副区 %d/%d]", sub_index, total_subs))
    log.info("=" .. string.rep("=", 58))
    log.info("")
    log.info("游戏: " .. (script.title or "未知"))
    log.info("合区类型: Type " .. (script.script.type or "未知"))
    log.info("")
    log.info("数据库配置:")
    log.info("  地址: " .. db_config.host .. ":" .. db_config.port)
    log.info("  用户: " .. db_config.user)
    log.info("")
    log.info("合区配置:")
    log.info("  主区游戏库: " .. merge_config.main_server.db_name .. " (ID: " .. merge_config.main_server.server_id .. ")")
    if merge_config.main_server.account_db_name then
        log.info("  主区账号库: " .. merge_config.main_server.account_db_name)
    end
    log.info("  副区游戏库: " .. sub_server_config.db_name .. " (ID: " .. sub_server_config.server_id .. ")")
    if sub_server_config.account_db_name then
        log.info("  副区账号库: " .. sub_server_config.account_db_name)
    end
    log.info("")

    -- 显示前缀后缀设置
    if script.script.prefix_setting then
        local ps = script.script.prefix_setting
        log.info("前缀/后缀设置:")

        if ps.role_is == "1" then
            local prefix_type = ps.additional_string == "1" and "前缀" or "后缀"
            log.info("  角色名: 添加" .. prefix_type .. " '" .. (ps.prefix or "") .. "'")
        else
            log.info("  角色名: 不处理")
        end

        if ps.guild_is == "1" then
            local prefix_type = ps.additional_string == "1" and "前缀" or "后缀"
            log.info("  公会名: 添加" .. prefix_type .. " '" .. (ps.prefix or "") .. "'")
        else
            log.info("  公会名: 不处理")
        end

        if ps.account_change == "1" then
            log.info("  账号名: 添加后缀 '" .. (ps.account_suffix or "") .. "'")
        else
            log.info("  账号名: 不处理")
        end
    end

    log.info("")

    -- 显示不合并的表
    if script.script.un_merge and #script.script.un_merge > 0 then
        log.info("不合并的表数量: " .. #script.script.un_merge)
    end

    log.info("")
    log.info("⚠️  警告: 合区操作不可逆，请确保已备份数据库！")
    log.info("")
    log.info("=" .. string.rep("=", 58))
    log.info("")
end

-- ============================================
-- 工具函数
-- ============================================

-- 读取JSON文件
local function load_json_script(filename)
    local filepath = game_config.script_dir .. filename

    -- 使用 util.read_file 读取文件内容
    local content, err = util.read_file(filepath)
    if err then
        return nil, "无法打开文件: " .. err
    end

    -- 使用 json.decode 解析 JSON
    local result, err = json.decode(content)
    if err then
        return nil, "JSON解析失败: " .. err
    end

    return result, nil
end

-- 获取表的最大ID
local function get_max_id(db_name, table_name, field_name)
    local cache_key = db_name .. "." .. table_name .. "." .. field_name
    if max_id_cache[cache_key] then
        return max_id_cache[cache_key]
    end

    local sql = string.format("SELECT IFNULL(MAX(`%s`), 0) as max_id FROM `%s`.`%s`",
        field_name, db_name, table_name)

    local result, err = db.query(sql)
    if err then
        log.error("获取最大ID失败: " .. err)
        return 0
    end

    local max_id = 0
    if result and #result > 0 then
        max_id = tonumber(result[1]) or 0
    end

    max_id_cache[cache_key] = max_id
    return max_id
end

-- 获取两个数据库的最大ID
local function get_max_id_from_two_db(main_db, sub_db, table_name, field_name)
    local max_id1 = get_max_id(main_db, table_name, field_name)
    local max_id2 = get_max_id(sub_db, table_name, field_name)
    return math.max(max_id1, max_id2)
end

-- 根据 JSON 的 restructure_tool 配置，对主区/副区的某些字段进行 ID 重构
-- 对应易语言源码中的 “restructure_state / restructure_tool” 段落
local function restructure_ids(main_db, sub_db, script)
    if not script.restructure_tool or script.restructure_state ~= "1" then
        return
    end

    log.info("开始执行 ID 重构...")

    for i, tool in ipairs(script.restructure_tool) do
        local group = tool.group
        if group and #group > 0 then
            -- 只按易语言源码对 group[1] 所在的表/字段做重构
            local first = group[1]
            local table_name = first.db_table
            local field_name = first.db_field
            local conditions = first.conditions or ""  -- 约定：JSON 中不带 WHERE，直接以 AND ... 形式追加

            if not table_name or not field_name or table_name == "" or field_name == "" then
                goto continue_tool
            end

            -- 读取主区/副区当前该字段的所有值，并按字段排序
            local select_main = string.format(
                "SELECT %s FROM `%s`.`%s` %s ORDER BY %s",
                field_name, main_db, table_name, conditions, field_name
            )
            local select_sub = string.format(
                "SELECT %s FROM `%s`.`%s` %s ORDER BY %s",
                field_name, sub_db, table_name, conditions, field_name
            )

            local main_ids, err_main = db.query(select_main)
            if err_main then
                log.error(string.format("ID重构读取主区数据失败 %s.%s: %s", table_name, field_name, err_main))
                goto continue_tool
            end

            local sub_ids, err_sub = db.query(select_sub)
            if err_sub then
                log.error(string.format("ID重构读取副区数据失败 %s.%s: %s", table_name, field_name, err_sub))
                goto continue_tool
            end

            local function as_list(ids)
                local t = {}
                if not ids then return t end
                for idx = 1, #ids do
                    t[#t + 1] = ids[idx]
                end
                return t
            end

            main_ids = as_list(main_ids)
            sub_ids = as_list(sub_ids)

            -- 依次为两边数据重新编号：第一个 ID 编号为 1，第二个为 2，以此类推
            local count_main = #main_ids
            local count_sub = #sub_ids
            local max_count = math.max(count_main, count_sub)

            log.info(string.format("ID重构 %s.%s: 主区记录 %d 条，副区记录 %d 条", table_name, field_name, count_main, count_sub))

            for idx = 1, max_count do
                local new_id = idx

                if idx <= count_main then
                    local old_id = tonumber(main_ids[idx]) or 0
                    local sql_update_main = string.format(
                        "UPDATE `%s`.`%s` SET %s = %d WHERE %s = %d%s",
                        main_db, table_name, field_name, new_id, field_name, old_id, conditions
                    )
                    local ok, err = db.exec(sql_update_main)
                    if not ok then
                        log.warn(string.format("主区 ID 重构失败 %s.%s: %s", table_name, field_name, err or ""))
                    end
                end

                if idx <= count_sub then
                    local old_id = tonumber(sub_ids[idx]) or 0
                    local sql_update_sub = string.format(
                        "UPDATE `%s`.`%s` SET %s = %d WHERE %s = %d%s",
                        sub_db, table_name, field_name, new_id, field_name, old_id, conditions
                    )
                    local ok, err = db.exec(sql_update_sub)
                    if not ok then
                        log.warn(string.format("副区 ID 重构失败 %s.%s: %s", table_name, field_name, err or ""))
                    end
                end
            end

            log.info(string.format("ID重构完成: %s.%s", table_name, field_name))
        end
        ::continue_tool::
    end
end

-- 检查表是否在排除列表中
local function is_table_excluded(table_name, exclude_list)
    if not exclude_list then return false end

    for _, item in ipairs(exclude_list) do
        if item.db_table == table_name then
            return true
        end
    end
    return false
end

-- 修改字段类型为BIGINT
local function modify_field_to_bigint(db_name, table_name, field_name)
    local sql = string.format("ALTER TABLE `%s`.`%s` MODIFY COLUMN `%s` BIGINT(20)",
        db_name, table_name, field_name)

    local success, err = db.exec(sql)
    if not success then
        log.warn(string.format("修改字段类型失败 %s.%s.%s: %s",
            db_name, table_name, field_name, err or ""))
    end
    return success
end

-- 更新字段值（加上偏移量）
local function update_field_with_offset(db_name, table_name, field_name, offset)
    if offset == 0 then return true end

    local sql = string.format("UPDATE `%s`.`%s` SET `%s` = `%s` + %d WHERE `%s` > 0",
        db_name, table_name, field_name, field_name, offset, field_name)

    local success, err = db.exec(sql)
    if not success then
        log.error(string.format("更新字段失败 %s.%s.%s: %s",
            db_name, table_name, field_name, err or ""))
    end
    return success
end

-- 添加前缀/后缀到字符串字段
local function add_prefix_suffix(db_name, table_name, field_name, prefix, is_prefix)
    if not prefix or prefix == "" then return true end

    local sql
    if is_prefix then
        sql = string.format("UPDATE `%s`.`%s` SET `%s` = CONCAT('%s', `%s`)",
            db_name, table_name, field_name, prefix, field_name)
    else
        sql = string.format("UPDATE `%s`.`%s` SET `%s` = CONCAT(`%s`, '%s')",
            db_name, table_name, field_name, field_name, prefix)
    end

    local success, err = db.exec(sql)
    if not success then
        log.error(string.format("添加前缀/后缀失败 %s.%s.%s: %s",
            db_name, table_name, field_name, err or ""))
    end
    return success
end

-- ============================================
-- 合区类型处理函数
-- ============================================

-- 类型1：简单合并（只合并other_identity）
local function merge_type_1(main_db, sub_db, script)
    log.info("执行类型1合区：简单合并")

    if not script.other_identity then
        log.warn("没有配置 other_identity")
        return true
    end

    -- 获取最大ID并更新
    for i, item in ipairs(script.other_identity) do
        local max_id = get_max_id_from_two_db(main_db, sub_db,
            item.db_table, item.db_field)

        log.info(string.format("更新 %s.%s，偏移量: %d",
            item.db_table, item.db_field, max_id))

        update_field_with_offset(sub_db, item.db_table, item.db_field, max_id)
    end

    return true
end

-- 类型2：复杂合并（处理same和other_identity）
local function merge_type_2(main_db, sub_db, script)
    log.info("执行类型2合区：复杂合并")

    local offset_map = {}       -- 对应变量内容1：same 组的最大 ID
    local other_offset_map = {} -- 对应变量内容2：other_identity 的最大 ID

    -- 1. ID重构（如果配置了）
    restructure_ids(main_db, sub_db, script)

    -- 2. 处理same组（相同字段组）
    if script.same then
        for group_idx, group in ipairs(script.same) do
            if group.group and #group.group > 0 then
                local first_item = group.group[1]
                local max_id = get_max_id_from_two_db(main_db, sub_db,
                    first_item.db_table, first_item.db_field)

                offset_map[group_idx] = max_id

                log.info(string.format("组 %d: %s.%s，最大ID: %d",
                    group_idx, first_item.db_table, first_item.db_field, max_id))

                -- 修改字段类型（如果需要）
                if script.simple_process and script.simple_process.character_types == "1" then
                    for _, item in ipairs(group.group) do
                        modify_field_to_bigint(main_db, item.db_table, item.db_field)
                        modify_field_to_bigint(sub_db, item.db_table, item.db_field)
                    end
                end

                -- 更新所有相关字段
                for _, item in ipairs(group.group) do
                    update_field_with_offset(sub_db, item.db_table, item.db_field, max_id)
                end
            end
        end
    end

    -- 3. 处理other_identity
    if script.other_identity then
        for i, item in ipairs(script.other_identity) do
            local max_id = get_max_id_from_two_db(main_db, sub_db,
                item.db_table, item.db_field)

            other_offset_map[i] = max_id

            log.info(string.format("其他ID %d: %s.%s，偏移量: %d",
                i, item.db_table, item.db_field, max_id))

            update_field_with_offset(sub_db, item.db_table, item.db_field, max_id)
        end
    end

    -- 5. 处理特殊字段（special_field）
    if script.special_option and script.special_option.special_field_open == "1" and script.special_option.special_field then
        log.info("处理特殊字段 (special_field)...")

        for _, item in ipairs(script.special_option.special_field) do
            local table_name = item.db_table
            local field_name = item.db_field
            local group_type = item.group   -- "1" 使用 same 偏移量, 其他使用 other_identity 偏移量
            local type_index = tonumber(item.type or "0") or 0
            local conditions = item.conditions or ""

            if table_name and field_name and type_index > 0 then
                local offset
                if group_type == "1" then
                    offset = offset_map[type_index] or 0
                else
                    offset = other_offset_map[type_index] or 0
                end

                if offset and offset ~= 0 then
                    -- 直接在字段上加偏移量，附带条件
                    local sql = string.format(
                        "UPDATE `%s`.`%s` SET %s = %s + %d %s",
                        sub_db, table_name, field_name, field_name, offset, conditions
                    )
                    local ok, err = db.exec(sql)
                    if not ok then
                        log.warn(string.format("更新 special_field 失败 %s.%s: %s",
                            table_name, field_name, err or ""))
                    end
                end
            end
        end
    end

    -- 6. 处理特殊字段（teshudb_field）
    if script.special_option and script.special_option.teshudb_field_open == "1" then
        if script.special_option.teshudb_field then
            log.info("处理特殊字段 (teshudb_field)...")

            for _, item in ipairs(script.special_option.teshudb_field) do
                -- db_field_attribution / db_table_attribution 表示“归属字段”：先查出旧值
                local attr_field = item.db_field_attribution
                local attr_table = item.db_table_attribution
                local target_table = item.db_table
                local target_field = item.db_field
                local group_type = item.group         -- "1" 表示使用 same 的偏移量，否则使用 other_identity 的偏移量
                local type_index = tonumber(item.type or "0") or 0

                if attr_field and attr_table and target_table and target_field and type_index > 0 then
                    -- 从副区归属表中读出所有旧值
                    local select_sql = string.format(
                        "SELECT %s FROM `%s`.`%s`",
                        attr_field, sub_db, attr_table
                    )
                    local values, err = db.query(select_sql)
                    if err then
                        log.warn(string.format("读取特殊字段归属数据失败 %s.%s: %s",
                            attr_table, attr_field, err))
                    elseif values and #values > 0 then
                        for idx = 1, #values do
                            local old_val_str = tostring(values[idx])
                            local old_val = tonumber(old_val_str) or 0
                            if old_val ~= 0 then
                                local offset
                                if group_type == "1" then
                                    offset = offset_map[type_index] or 0
                                else
                                    offset = other_offset_map[type_index] or 0
                                end

                                if offset ~= 0 then
                                    local new_val = old_val + offset
                                    -- 在目标表/字段里做 replace(old,new)
                                    local update_sql = string.format(
                                        "UPDATE `%s`.`%s` SET %s = REPLACE(%s, '%d', '%d')",
                                        sub_db, target_table, target_field, target_field, old_val, new_val
                                    )
                                    local ok, uerr = db.exec(update_sql)
                                    if not ok then
                                        log.warn(string.format("更新特殊字段失败 %s.%s: %s",
                                            target_table, target_field, uerr or ""))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return true
end

-- 类型3：简单处理（simple_process）
local function merge_type_3(main_db, sub_db, script)
    log.info("执行类型3合区：简单处理")

    if not script.simple_process then
        log.warn("没有配置 simple_process")
        return true
    end

    local offset_map = {}

    -- 1. 处理deal_with（需要处理的字段）
    if script.simple_process.deal_with then
        for i, item in ipairs(script.simple_process.deal_with) do
            local max_id = get_max_id_from_two_db(main_db, sub_db,
                item.db_table, item.db_field)

            offset_map[i] = max_id

            log.info(string.format("处理 %s.%s，最大ID: %d",
                item.db_table, item.db_field, max_id))

            -- 修改字段类型
            if script.simple_process.character_types == "1" then
                modify_field_to_bigint(main_db, item.db_table, item.db_field)
                modify_field_to_bigint(sub_db, item.db_table, item.db_field)
            end

            -- 更新字段值
            update_field_with_offset(sub_db, item.db_table, item.db_field, max_id)

            -- 处理关联字段
            if item.associated then
                local tables, err = db.get_tables(sub_db)
                if tables then
                    for _, table_name in ipairs(tables) do
                        -- 检查表是否有关联字段
                        local check_sql = string.format(
                            "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns WHERE table_schema='%s' AND table_name='%s' AND COLUMN_NAME='%s'",
                            sub_db, table_name, item.associated)

                        local result = db.query(check_sql)
                        if result and #result > 0 then
                            if script.simple_process.character_types == "1" then
                                modify_field_to_bigint(main_db, table_name, item.associated)
                                modify_field_to_bigint(sub_db, table_name, item.associated)
                            end
                            update_field_with_offset(sub_db, table_name, item.associated, max_id)
                        end
                    end
                end
            end
        end
    end

    -- 2. 处理primary_key（主键字段）
    if script.simple_process.primary_key then
        log.info("处理主键字段 (primary_key)...")

        -- 遍历所有可能包含主键字段的表
        local tables, err = db.get_tables(sub_db)
        if err then
            log.warn("获取副区表列表失败: " .. err)
        elseif tables and #tables > 0 then
            for _, pk in ipairs(script.simple_process.primary_key) do
                local pk_field = pk.db_field
                if pk_field and pk_field ~= "" then
                    for _, table_name in ipairs(tables) do
                        -- 检查该表是否包含该主键字段
                        local check_sql = string.format(
                            "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.Columns WHERE table_schema='%s' AND table_name='%s' AND COLUMN_NAME='%s'",
                            sub_db, table_name, pk_field
                        )
                        local cols = db.query(check_sql)
                        if cols and #cols > 0 then
                            -- 如有需要，先将字段改为 BIGINT
                            if script.simple_process.character_types == "1" then
                                modify_field_to_bigint(main_db, table_name, pk_field)
                                modify_field_to_bigint(sub_db, table_name, pk_field)
                            end

                            -- 重新计算该字段在两个库中的最大值，并在副区上整体平移
                            local max_id = get_max_id_from_two_db(main_db, sub_db, table_name, pk_field)
                            if max_id > 0 then
                                log.info(string.format("主键字段处理 %s.%s，最大ID: %d",
                                    table_name, pk_field, max_id))
                                update_field_with_offset(sub_db, table_name, pk_field, max_id)
                            end
                        end
                    end
                end
            end
        end
    end

    return true
end


-- ============================================
-- 后处理函数
-- ============================================

-- 处理角色名/公会名前缀后缀
local function process_prefix_suffix(sub_db, script)
    if not script.prefix_setting then return true end

    local prefix_config = script.prefix_setting

    local function should_use_prefix()
        -- additional_string == "1" 表示前缀，否则后缀
        return prefix_config.additional_string == "1"
    end

    -- 处理角色名
    if prefix_config.role_name and (prefix_config.role_is == "1" or prefix_config.role_is == "2") then
        log.info("处理角色名前缀/后缀...")
        for _, item in ipairs(prefix_config.role_name) do
            local is_prefix = should_use_prefix()

            if prefix_config.repeat_modify == "1" then
                -- 仅修改与主服存在重名的记录：使用 IN (子查询) 模式
                local sql
                if is_prefix then
                    sql = string.format(
                        "UPDATE `%s`.`%s` SET %s = CONCAT('%s', %s) WHERE %s IN (SELECT %s FROM `%s`.`%s`) AND %s <> '%s'",
                        sub_db, item.db_table, item.db_field,
                        prefix_config.prefix, item.db_field,
                        item.db_field, item.db_field, merge_config.main_server.db_name, item.db_table,
                        item.db_field, item.not_equal or ""
                    )
                else
                    sql = string.format(
                        "UPDATE `%s`.`%s` SET %s = CONCAT(%s, '%s') WHERE %s IN (SELECT %s FROM `%s`.`%s`) AND %s <> '%s'",
                        sub_db, item.db_table, item.db_field,
                        item.db_field, prefix_config.prefix,
                        item.db_field, item.db_field, merge_config.main_server.db_name, item.db_table,
                        item.db_field, item.not_equal or ""
                    )
                end
                local ok, err = db.exec(sql)
                if not ok then
                    log.warn(string.format("处理角色名前缀/后缀失败 %s.%s: %s",
                        item.db_table, item.db_field, err or ""))
                end
            else
                -- 简单模式：直接按 not_equal 过滤
                local sql
                if is_prefix then
                    sql = string.format(
                        "UPDATE `%s`.`%s` SET %s = CONCAT('%s', %s) WHERE %s <> '%s'",
                        sub_db, item.db_table, item.db_field,
                        prefix_config.prefix, item.db_field,
                        item.db_field, item.not_equal or ""
                    )
                else
                    sql = string.format(
                        "UPDATE `%s`.`%s` SET %s = CONCAT(%s, '%s') WHERE %s <> '%s'",
                        sub_db, item.db_table, item.db_field,
                        item.db_field, prefix_config.prefix,
                        item.db_field, item.not_equal or ""
                    )
                end
                local ok, err = db.exec(sql)
                if not ok then
                    log.warn(string.format("处理角色名前缀/后缀失败 %s.%s: %s",
                        item.db_table, item.db_field, err or ""))
                end
            end
        end
    end

    -- 处理公会名
    if prefix_config.guild_name and (prefix_config.guild_is == "1" or prefix_config.guild_is == "2") then
        log.info("处理公会名前缀/后缀...")
        for _, item in ipairs(prefix_config.guild_name) do
            local is_prefix = should_use_prefix()
            local sql
            if is_prefix then
                sql = string.format(
                    "UPDATE `%s`.`%s` SET %s = CONCAT('%s', %s) WHERE %s <> '%s'",
                    sub_db, item.db_table, item.db_field,
                    prefix_config.prefix, item.db_field,
                    item.db_field, item.not_equal or ""
                )
            else
                sql = string.format(
                    "UPDATE `%s`.`%s` SET %s = CONCAT(%s, '%s') WHERE %s <> '%s'",
                    sub_db, item.db_table, item.db_field,
                    item.db_field, prefix_config.prefix,
                    item.db_field, item.not_equal or ""
                )
            end
            local ok, err = db.exec(sql)
            if not ok then
                log.warn(string.format("处理公会名前缀/后缀失败 %s.%s: %s",
                    item.db_table, item.db_field, err or ""))
            end
        end
    end

    -- 处理账号后缀 (普通模式 account_change == "1" 或 "2")
    if (prefix_config.account_change == "1" or prefix_config.account_change == "2") and prefix_config.account_table then
        log.info("处理账号后缀 (普通模式)...")
        for _, item in ipairs(prefix_config.account_table) do
            local sql = string.format(
                "UPDATE `%s`.`%s` SET %s = CONCAT(%s, '%s')",
                sub_db, item.db_table, item.db_field,
                item.db_field, prefix_config.account_suffix or ""
            )
            local ok, err = db.exec(sql)
            if not ok then
                log.warn(string.format("处理账号后缀失败 %s.%s: %s",
                    item.db_table, item.db_field, err or ""))
            end
        end
    end

    -- 特殊账号合并模式：account_change == "999"
    if prefix_config.account_change == "999" and prefix_config.account_change_new and #prefix_config.account_change_new > 0 then
        log.info("处理账号特殊合并 (account_change = 999)...")

        local total = #prefix_config.account_change_new

        for idx, conf in ipairs(prefix_config.account_change_new) do
            local user_table = conf.db_table_user
            local user_id_field = conf.db_field_user_id
            local user_name_field = conf.db_field_user_name
            local player_table = conf.db_table_player
            local player_uid_field = conf.db_field_player_user_id

            if user_table and user_id_field and user_name_field and player_table and player_uid_field then
                -- 找出主区与被合区中同名账号
                local sql_main = string.format(
                    "SELECT %s, %s FROM `%s`.`%s` WHERE %s IN (SELECT %s FROM `%s`.`%s`)",
                    user_id_field, user_name_field,
                    merge_config.main_server.account_db_name or merge_config.main_server.db_name, user_table,
                    user_name_field,
                    user_name_field, sub_db, user_table
                )
                local rows, err = db.query(sql_main)
                if err then
                    log.warn("查询重复账号失败: " .. err)
                elseif rows and #rows > 0 then
                    for i = 1, #rows, 2 do
                        local main_id = tonumber(rows[i]) or 0
                        local name = tostring(rows[i + 1] or "")
                        if main_id ~= 0 and name ~= "" then
                            -- 在被合区中找到对应账号 ID
                            local sql_sub_id = string.format(
                                "SELECT %s FROM `%s`.`%s` WHERE %s = '%s'",
                                user_id_field, sub_db, user_table, user_name_field, name
                            )
                            local sub_rows, e2 = db.query(sql_sub_id)
                            if not e2 and sub_rows and #sub_rows > 0 then
                                local sub_id = tonumber(sub_rows[1]) or 0
                                if sub_id ~= 0 then
                                    -- 更新被合区玩家表中的外键为主区账号 ID
                                    local sql_update_player = string.format(
                                        "UPDATE `%s`.`%s` SET %s = %d WHERE %s = %d",
                                        sub_db, player_table, player_uid_field, main_id, player_uid_field, sub_id
                                    )
                                    local ok, e3 = db.exec(sql_update_player)
                                    if not ok then
                                        log.warn("更新玩家账号ID失败: " .. (e3 or ""))
                                    end

                                    -- 在最后一个配置中，删除被合区中多余账号记录
                                    if idx == total then
                                        local sql_del = string.format(
                                            "DELETE FROM `%s`.`%s` WHERE %s = %d",
                                            sub_db, user_table, user_id_field, sub_id
                                        )
                                        db.exec(sql_del)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return true
end

-- 更新服务器ID
local function update_server_id(sub_db, script, server_id)
    if not script.server_info or script.server_info.server_is ~= "1" then
        return true
    end

    if not script.server_info.server_sql then
        return true
    end

    log.info(string.format("更新服务器ID为: %s", server_id))

    for _, item in ipairs(script.server_info.server_sql) do
        local sql = string.format("UPDATE `%s`.`%s` SET `%s` = '%s'",
            sub_db, item.db_table, item.db_field, server_id)

        local success, err = db.exec(sql)
        if not success then
            log.error(string.format("更新服务器ID失败 %s.%s: %s",
                item.db_table, item.db_field, err or ""))
        end
    end

    return true
end

-- 处理 empty_table / modify_table / indexing_table 配置
local function process_empty_and_modify_tables(main_db, sub_db, script)
    -- 清空指定表（truncate），主区/副区同时清空
    if script.empty_table and #script.empty_table > 0 then
        for _, item in ipairs(script.empty_table) do
            if item.db_table then
                local tbl = item.db_table
                local sql1 = string.format("TRUNCATE TABLE `%s`.`%s`", sub_db, tbl)
                local sql2 = string.format("TRUNCATE TABLE `%s`.`%s`", main_db, tbl)
                db.exec(sql1)
                db.exec(sql2)
            end
        end
    end

    -- 根据 modify_table 配置修改字段值（主区/副区都执行）
    if script.modify_table and #script.modify_table > 0 then
        for _, item in ipairs(script.modify_table) do
            local tbl = item.db_table
            local field = item.db_field
            local results = item.results
            local conditions = item.conditions
            if tbl and field and results ~= nil and conditions ~= nil then
                local sql_sub = string.format(
                    "UPDATE `%s`.`%s` SET %s = %s WHERE %s = %s",
                    sub_db, tbl, field, results, field, conditions
                )
                local sql_main = string.format(
                    "UPDATE `%s`.`%s` SET %s = %s WHERE %s = %s",
                    main_db, tbl, field, results, field, conditions
                )
                db.exec(sql_sub)
                db.exec(sql_main)
            end
        end
    end

    -- 删除索引（indexing_table）
    if script.indexing_table and #script.indexing_table > 0 then
        for _, item in ipairs(script.indexing_table) do
            local tbl = item.db_table
            local index_name = item.indexing_name
            if tbl and index_name then
                local sql_main = string.format(
                    "DROP INDEX %s ON `%s`.`%s`",
                    index_name, main_db, tbl
                )
                local sql_sub = string.format(
                    "DROP INDEX %s ON `%s`.`%s`",
                    index_name, sub_db, tbl
                )
                db.exec(sql_main)
                db.exec(sql_sub)
            end
        end
    end
end

-- 合并所有表数据
local function merge_all_tables(main_db, sub_db, script)
    log.info(string.format("开始合并表数据: %s -> %s", sub_db, main_db))

    -- 获取副区所有表
    local tables, err = db.get_tables(sub_db)
    if err then
        log.error("获取表列表失败: " .. err)
        return false
    end

    if not tables or #tables == 0 then
        log.warn("副区没有表")
        return true
    end

    local merged_count = 0
    local skipped_count = 0
    local total = #tables

    for i, table_name in ipairs(tables) do
        -- 显示进度
        ui.progress(i, total, string.format("合并表: %s", table_name))

        -- 检查是否在排除列表中
        if is_table_excluded(table_name, script.un_merge) then
            log.debug("跳过表: " .. table_name)
            skipped_count = skipped_count + 1
        else
            local success, err = db.merge_table(main_db, sub_db, table_name)
            if success then
                merged_count = merged_count + 1
            else
                log.error(string.format("合并表失败 %s: %s", table_name, err or ""))
            end
        end
    end

    log.info(string.format("表合并完成: 成功 %d 个，跳过 %d 个，总计 %d 个",
        merged_count, skipped_count, total))

    return true
end

-- 合并账号数据库
local function merge_account_database(main_account_db, sub_account_db, sub_server_config, script)
    -- 检查是否配置了账号数据库
    if not main_account_db or not sub_account_db then
        log.info("未配置账号数据库，跳过账号库合并")
        return true
    end

    log.info(string.format("开始合并账号数据库: %s -> %s", sub_account_db, main_account_db))

    -- 检查账号数据库是否存在
    local tables, err = db.get_tables(sub_account_db)
    if err then
        log.warn("账号数据库不存在或无法访问: " .. sub_account_db)
        return true
    end

    if not tables or #tables == 0 then
        log.warn("账号数据库没有表")
        return true
    end

    -- 处理账号表（通常是 account 或 user 表）
    local account_tables = {"account", "user", "accounts", "users", "login"}
    local merged_count = 0

    for _, table_name in ipairs(account_tables) do
        -- 检查表是否存在
        local found = false
        for _, t in ipairs(tables) do
            if t == table_name then
                found = true
                break
            end
        end

        if found then
            log.info(string.format("处理账号表: %s", table_name))

            -- 如果配置了账号后缀，先添加后缀
            if sub_server_config.account_suffix and sub_server_config.account_suffix ~= "" then
                -- 查找账号名字段（常见字段名）
                local account_fields = {"username", "account", "account_name", "name", "user_name"}

                for _, field in ipairs(account_fields) do
                    -- 尝试添加后缀
                    local sql = string.format(
                        "UPDATE `%s`.`%s` SET `%s` = CONCAT(`%s`, '%s') WHERE `%s` NOT LIKE '%%%s'",
                        sub_account_db, table_name, field, field,
                        sub_server_config.account_suffix, field, sub_server_config.account_suffix
                    )

                    local success, err = db.exec(sql)
                    if success then
                        log.info(string.format("账号表 %s.%s 添加后缀成功", table_name, field))
                        break
                    end
                end
            end

            -- 合并账号表
            local success, err = db.merge_table(main_account_db, sub_account_db, table_name)
            if success then
                merged_count = merged_count + 1
                log.info(string.format("账号表 %s 合并成功", table_name))
            else
                log.error(string.format("账号表 %s 合并失败: %s", table_name, err or ""))
            end
        end
    end

    -- 合并其他账号库的表
    for _, table_name in ipairs(tables) do
        local is_account_table = false
        for _, at in ipairs(account_tables) do
            if table_name == at then
                is_account_table = true
                break
            end
        end

        if not is_account_table then
            local success, err = db.merge_table(main_account_db, sub_account_db, table_name)
            if success then
                merged_count = merged_count + 1
            end
        end
    end

    log.info(string.format("账号数据库合并完成: 成功 %d 个表", merged_count))

    return true
end

-- ============================================
-- 主执行函数
-- ============================================

function execute(config)
    -- 显示欢迎信息和当前配置
    show_welcome_and_config()

    -- 询问是否修改配置（暂时跳过，直接使用默认配置）
    -- local choice = prompt_for_config_changes()
    -- if choice == 0 then
    --     return false, "用户取消操作"
    -- end

    -- 1. 加载JSON配置
    log.info("正在加载JSON配置: " .. merge_config.json_script)
    local script, err = load_json_script(merge_config.json_script)
    if err then
        log.error("加载JSON配置失败: " .. err)
        return false, err
    end

    script_config = script.script

    if not script_config then
        return false, "JSON配置格式错误，缺少script节点"
    end

    log.info("开始执行合区操作...")
    log.info("")

    -- 2. 遍历所有副区
    local main_db = merge_config.main_server.db_name
    local sub_servers = merge_config.sub_servers

    for idx, sub_server_config in ipairs(sub_servers) do
        local sub_db = sub_server_config.db_name

        log.info("")
        log.info(string.rep("-", 60))
        log.info(string.format("处理副区 [%d/%d]: %s", idx, #sub_servers, sub_db))
        log.info(string.rep("-", 60))

        -- 应用当前副区的配置覆盖
        local current_script = apply_user_overrides(script, sub_server_config)
        local current_script_config = current_script.script

        -- 显示当前副区的合区确认信息
        show_merge_confirmation(current_script, sub_server_config, idx, #sub_servers)

        -- 清空缓存
        max_id_cache = {}

        -- 3. 根据类型执行合区
        local merge_type = current_script_config.type
        local success = false

        if merge_type == "1" then
            success = merge_type_1(main_db, sub_db, current_script_config)
        elseif merge_type == "2" then
            success = merge_type_2(main_db, sub_db, current_script_config)
        elseif merge_type == "3" then
            success = merge_type_3(main_db, sub_db, current_script_config)
        else
            log.error("未知的合区类型: " .. merge_type)
            return false, "未知的合区类型"
        end

        if not success then
            log.error("合区处理失败")
            return false, "合区处理失败"
        end

        -- 4. 处理前缀后缀
        process_prefix_suffix(sub_db, current_script_config)

        -- 5. 更新服务器ID
        if current_script_config.server_info then
            local server_id = current_script_config.slave_server or sub_server_config.server_id
            update_server_id(sub_db, current_script_config, server_id)
        end

        -- 6. 合并所有表数据
        if not merge_all_tables(main_db, sub_db, current_script_config) then
            log.error("表数据合并失败")
            return false, "表数据合并失败"
        end

        -- 7. 合并账号数据库（仅在 account_change = "1" 时启用）
        local main_account_db = merge_config.main_server.account_db_name
        local sub_account_db = sub_server_config.account_db_name
        local prefix_cfg = current_script_config.prefix_setting
        if main_account_db and sub_account_db and prefix_cfg and prefix_cfg.account_change == "1" then
            if not merge_account_database(main_account_db, sub_account_db, sub_server_config, current_script_config) then
                log.error("账号数据库合并失败")
                return false, "账号数据库合并失败"
            end
        end

        log.info(string.format("副区 %s 处理完成", sub_db))
    end

    log.info("")
    log.info("=" .. string.rep("=", 58))
    log.info("通用合区工具执行完成！")
    log.info("=" .. string.rep("=", 58))

    return true
end

-- 验证配置
function validate(config)
    -- 检查JSON脚本文件是否存在
    local filepath = game_config.script_dir .. merge_config.json_script
    local file = io.open(filepath, "r")
    if not file then
        return false, "JSON脚本文件不存在: " .. filepath
    end
    file:close()

    -- 检查主区配置
    if not merge_config.main_server or not merge_config.main_server.db_name or merge_config.main_server.db_name == "" then
        return false, "主区数据库名不能为空"
    end

    if not merge_config.main_server.server_id or merge_config.main_server.server_id == "" then
        return false, "主区服务器ID不能为空"
    end

    -- 检查副区配置
    if not merge_config.sub_servers or #merge_config.sub_servers == 0 then
        return false, "副区列表不能为空"
    end

    -- 验证每个副区的配置
    for i, sub in ipairs(merge_config.sub_servers) do
        if not sub.db_name or sub.db_name == "" then
            return false, string.format("副区%d的数据库名不能为空", i)
        end

        if not sub.server_id or sub.server_id == "" then
            return false, string.format("副区%d的服务器ID不能为空", i)
        end

        if not sub.prefix then
            return false, string.format("副区%d的前缀/后缀不能为空", i)
        end

        if not sub.account_suffix then
            return false, string.format("副区%d的账号后缀不能为空", i)
        end
    end

    return true
end



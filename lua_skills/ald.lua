-- @name: 阿拉德
-- @description: 阿拉德合区工具（由 create_merge_proc.sql + merge_server_simple.sh 移植为 Lua 执行 SQL）

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
    -- 主库（目标库）
    main_server = "x_ms_ald_1",

    -- 副库（来源库）列表
    sub_servers = {
        "x_ms_ald_2",
    },

    -- 合并到的 zoneid（主服 zid）
    merge_to_zid = 1,
}

-- ============================================
-- 工具函数
-- ============================================
local function sql_exec(sql)
    local ok, err = db.exec(sql)
    if not ok then
        return false, err or "unknown error"
    end
    return true
end

local function sql_query_list(sql)
    local rows, err = db.query(sql)
    if err then
        return nil, err
    end
    local out = {}
    if rows then
        for i = 1, #rows do
            out[#out + 1] = tostring(rows[i])
        end
    end
    return out
end

local function column_exists(db_name, table_name, column_name)
    local sql = string.format(
        "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='%s' AND TABLE_NAME='%s' AND COLUMN_NAME='%s'",
        db_name, table_name, column_name
    )
    local rows = db.query(sql)
    if not rows or #rows == 0 then return false end
    return tonumber(rows[1]) == 1
end

local function view_exists(db_name, view_name)
    local sql = string.format(
        "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='%s' AND TABLE_NAME='%s' AND TABLE_TYPE='VIEW'",
        db_name, view_name
    )
    local rows = db.query(sql)
    if not rows or #rows == 0 then return false end
    return tonumber(rows[1]) == 1
end

local function cleanup_existing_temp_fields(db_name)
    local tables = { "t_account", "t_account_adventure", "t_account_monopoly" }
    for _, tbl in ipairs(tables) do
        if column_exists(db_name, tbl, "zone_id") then
            log.warn(string.format("发现 %s.%s 已存在 zone_id，删除中...", db_name, tbl))
            sql_exec(string.format("ALTER TABLE `%s`.`%s` DROP COLUMN `zone_id`", db_name, tbl))
        end
    end
end

local function cleanup_problematic_views(db_name)
    local v = "money_manage_error_account"
    if view_exists(db_name, v) then
        log.warn(string.format("发现 %s.%s 视图，尝试删除（忽略失败）", db_name, v))
        db.exec(string.format("DROP VIEW IF EXISTS `%s`.`%s`", db_name, v))
    end
end

local function chunked_in(ids, chunk_size, fn)
    chunk_size = chunk_size or 5000
    local i = 1
    while i <= #ids do
        local j = math.min(i + chunk_size - 1, #ids)
        local parts = {}
        for k = i, j do
            parts[#parts + 1] = tostring(ids[k])
        end
        local in_list = "(" .. table.concat(parts, ",") .. ")"
        local ok, err = fn(in_list)
        if not ok then return false, err end
        i = j + 1
    end
    return true
end

local function progress(current, total, message)
    if ui and ui.progress and total and total > 0 then
        ui.progress(current, total, message or "")
    end
end

-- ============================================
-- 1) 合表（对应 SQL 的 merge_table(dest, src)）
-- ============================================
local function merge_table(dest, src)
    cleanup_existing_temp_fields(dest)
    cleanup_existing_temp_fields(src)
    cleanup_problematic_views(dest)
    cleanup_problematic_views(src)

    -- 给账号/冒险/大富翁临时加 zone_id 并赋值（用于后续账号合并逻辑）
    local function ensure_zone_id(tbl)
        if not column_exists(dest, tbl, "zone_id") then
            sql_exec(string.format("ALTER TABLE `%s`.`%s` ADD COLUMN `zone_id` int(10) UNSIGNED NOT NULL DEFAULT 0", dest, tbl))
        end
        if not column_exists(src, tbl, "zone_id") then
            sql_exec(string.format("ALTER TABLE `%s`.`%s` ADD COLUMN `zone_id` int(10) UNSIGNED NOT NULL DEFAULT 0", src, tbl))
        end
    end

    ensure_zone_id("t_account")
    sql_exec(string.format("UPDATE `%s`.`t_account` SET zone_id = (SELECT zoneid FROM `%s`.`t_player_info` LIMIT 1)", dest, dest))
    sql_exec(string.format("UPDATE `%s`.`t_account` SET zone_id = (SELECT zoneid FROM `%s`.`t_player_info` LIMIT 1)", src, src))

    ensure_zone_id("t_account_adventure")
    sql_exec(string.format("UPDATE `%s`.`t_account_adventure` SET zone_id = (SELECT zoneid FROM `%s`.`t_player_info` LIMIT 1)", dest, dest))
    sql_exec(string.format("UPDATE `%s`.`t_account_adventure` SET zone_id = (SELECT zoneid FROM `%s`.`t_player_info` LIMIT 1)", src, src))

    ensure_zone_id("t_account_monopoly")
    sql_exec(string.format("UPDATE `%s`.`t_account_monopoly` SET zone_id = (SELECT zoneid FROM `%s`.`t_player_info` LIMIT 1)", dest, dest))
    sql_exec(string.format("UPDATE `%s`.`t_account_monopoly` SET zone_id = (SELECT zoneid FROM `%s`.`t_player_info` LIMIT 1)", src, src))

    -- 下面是原 SQL 里的插表/清表顺序，直接用 INSERT SELECT 执行
    local inserts = {
        "t_account",
        "t_active_task",
        -- t_activity_op 先清空 dest
    }
    for _, tbl in ipairs(inserts) do
        sql_exec(string.format("INSERT INTO `%s`.`%s` SELECT * FROM `%s`.`%s`", dest, tbl, src, tbl))
    end

    sql_exec(string.format("DELETE FROM `%s`.`t_activity_op`", dest))

    local more = {
        "t_activity_op_task",
        "t_activity_op_task_new",
        "t_charge_record",
        "t_counter",
        "t_dungeon",
        "t_g_dungeon_hard",
        "t_account_adventure",
        "t_account_monopoly",
        "t_hire",
        "t_guild",
        "t_guild_member",
        "t_item",
        -- t_jar_record 先清空 dest
    }
    for _, tbl in ipairs(more) do
        sql_exec(string.format("INSERT INTO `%s`.`%s` SELECT * FROM `%s`.`%s`", dest, tbl, src, tbl))
    end

    sql_exec(string.format("DELETE FROM `%s`.`t_jar_record`", dest))

    local even_more = {
        "t_jaritem_pool",
        "t_mail",
        "t_mailitem",
        "t_mall_gift_pack",
        "t_offline_event",
        "t_pk_statistic",
        "t_player_info",
        "t_punishment",
        "t_red_packet",
        "t_red_packet_receiver",
        "t_relation",
        "t_retinue",
        "t_shop",
        "t_shopitem",
        "t_sortlist",
        "t_sys_record",
        "t_task",
        "t_auction_new",
        "t_pet",
        "t_guild_storage",
        "t_guildstorage_oprecord",
        "t_questionnaire",
        "t_mastersect_relation",
        "t_account_shop_role_buy_record",
        "t_auction_transaction",
        "t_activity_op_attribute",
        "t_mall_item",
        "t_blackmarket_auction",
        "t_blackmarket_transaction",
        "t_expedition_map",
        "t_expedition_member",
        "t_head_frame",
        "t_item_deposit",
        "t_week_sign",
        "t_activity_account_record",
        "t_activity_op_account_task",
        "t_activity_op_record",
        "t_account_task",
        "t_new_title_accout",
        "t_new_title",
        "t_team_copy",
        "t_currency_frozen",
        "t_honor_role",
        "t_honor_history",
        "t_shortcut_key",
        "t_credit_point_record",
    }

    for _, tbl in ipairs(even_more) do
        sql_exec(string.format("INSERT INTO `%s`.`%s` SELECT * FROM `%s`.`%s`", dest, tbl, src, tbl))
    end

    -- t_player_info_name：只插入 dest 不存在的 name
    sql_exec(string.format(
        "INSERT INTO `%s`.`t_player_info_name` SELECT * FROM `%s`.`t_player_info_name` WHERE NOT EXISTS(SELECT name FROM `%s`.`t_player_info_name` WHERE name = `%s`.`t_player_info_name`.name)",
        dest, src, dest, src
    ))

    -- t_abnormal_transaction：排除 guid 列后插入
    local cols, err = sql_query_list(string.format(
        "SELECT GROUP_CONCAT(COLUMN_NAME) FROM information_schema.COLUMNS WHERE table_name = 't_abnormal_transaction' AND TABLE_SCHEMA = '%s' AND COLUMN_NAME != 'guid'",
        dest
    ))
    if cols and cols[1] and cols[1] ~= "" then
        local c = cols[1]
        sql_exec(string.format(
            "INSERT INTO `%s`.`t_abnormal_transaction`(%s) SELECT %s FROM `%s`.`t_abnormal_transaction`",
            dest, c, c, src
        ))
    end

    -- account_counter / account_shop_acc_buy_record：按 SQL 中过滤条件插入
    sql_exec(string.format("INSERT INTO `%s`.`t_account_counter` SELECT * FROM `%s`.`t_account_counter` WHERE counter_type IN (1,2,3,4,5,6,10)", dest, src))
    sql_exec(string.format("INSERT INTO `%s`.`t_account_shop_acc_buy_record` SELECT * FROM `%s`.`t_account_shop_acc_buy_record` WHERE shop_id IN (51,52,70,34)", dest, src))

    return true
end

-- ============================================
-- 2) start_merge(zid) 对应逻辑：直接在 Lua 顺序执行
-- ============================================

local function merge_player(zid)
    -- 重名玩家（只处理非主服 zone）
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_player (incid INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, guid BIGINT UNSIGNED NOT NULL, name varchar(30) NOT NULL, zoneid INT UNSIGNED NOT NULL)")
    sql_exec("TRUNCATE TABLE tmp_player")
    sql_exec(string.format(
        "INSERT INTO tmp_player(guid,name,zoneid) SELECT guid,name,zoneid FROM t_player_info WHERE name IN (SELECT name FROM t_player_info GROUP BY BINARY name HAVING COUNT(name)>1) AND zoneid <> %d ORDER BY BINARY name",
        zid
    ))

    local rows = sql_query_list("SELECT CONCAT(guid,'\\t',name,'\\t',zoneid) FROM tmp_player ORDER BY incid")
    if rows then
        for _, line in ipairs(rows) do
            local guid, name, zoneid = line:match("^(%d+)\t(.-)\t(%d+)$")
            guid = tonumber(guid) or 0
            zoneid = tonumber(zoneid) or 0
            if guid ~= 0 and zoneid ~= zid then
                local new_name = string.format("s%d.%s", zoneid, name)
                sql_exec(string.format("UPDATE t_player_info SET name='%s' WHERE guid=%d", new_name, guid))
                sql_exec(string.format("UPDATE t_guild_member SET name='%s' WHERE guid=%d", new_name, guid))
                sql_exec(string.format("UPDATE t_relation SET name='%s' WHERE id=%d", new_name, guid))
                sql_exec(string.format("UPDATE t_sortlist SET name='%s' WHERE id=%d", new_name, guid))
                sql_exec(string.format("UPDATE t_sortlist SET ownername='%s' WHERE ownerid=%d", new_name, guid))
                sql_exec(string.format("INSERT INTO t_merge_give_namecard(guid,name,type) VALUES(%d,'%s',1)", guid, new_name))
            end
        end
    end

    -- 重置时装商城购买次数
    sql_exec("UPDATE t_counter SET `value` = 0 WHERE `name` = 'buy_mall_fashion_num'")
end

local function merge_adventure_team_repeative_name(zid)
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_repe_advname (team_name VARCHAR(64) NOT NULL, PRIMARY KEY(team_name))")
    sql_exec("TRUNCATE TABLE tmp_repe_advname")
    sql_exec("INSERT INTO tmp_repe_advname(team_name) SELECT adventure_team_name FROM t_account WHERE adventure_team_name <> '' GROUP BY BINARY adventure_team_name HAVING COUNT(adventure_team_name)>1")

    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_advname_info (incid INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, guid BIGINT UNSIGNED NOT NULL, accid INT UNSIGNED NOT NULL, team_name VARCHAR(64) NOT NULL, zone_id INT UNSIGNED NOT NULL)")
    sql_exec("TRUNCATE TABLE tmp_advname_info")
    sql_exec("INSERT INTO tmp_advname_info(guid,accid,team_name,zone_id) SELECT t_account.guid,t_account.accid,t_account.adventure_team_name,t_account.zone_id FROM t_account RIGHT JOIN tmp_repe_advname ON t_account.adventure_team_name = tmp_repe_advname.team_name WHERE t_account.adventure_team_name IS NOT NULL ORDER BY BINARY t_account.adventure_team_name")

    local rows = sql_query_list("SELECT CONCAT(guid,'\\t',accid,'\\t',team_name,'\\t',zone_id) FROM tmp_advname_info ORDER BY incid")
    if rows then
        for _, line in ipairs(rows) do
            local guid, accid, name, zoneid = line:match("^(%d+)\t(%d+)\t(.-)\t(%d+)$")
            guid = tonumber(guid) or 0
            accid = tonumber(accid) or 0
            zoneid = tonumber(zoneid) or 0
            if guid ~= 0 and accid ~= 0 and zoneid ~= zid then
                local new_name = string.format("s%d.%s", zoneid, name)
                sql_exec(string.format("UPDATE t_account SET adventure_team_name='%s' WHERE guid=%d", new_name, guid))
                sql_exec(string.format("INSERT INTO t_merge_give_namecard(accid,name,type) VALUES(%d,'%s',3)", accid, new_name))
            end
        end
    end
end

local function merge_adventure_team_data(zid)
    -- 直接执行原存储过程里的集合 SQL（不逐行）
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_guid_account (guid BIGINT UNSIGNED NOT NULL, PRIMARY KEY(guid))")
    sql_exec("TRUNCATE TABLE tmp_guid_account")
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_accid_account (accid INT UNSIGNED NOT NULL, PRIMARY KEY(accid))")
    sql_exec("TRUNCATE TABLE tmp_accid_account")
    sql_exec("INSERT INTO tmp_accid_account(accid) SELECT accid FROM t_account GROUP BY accid HAVING COUNT(*) > 1 AND COUNT(DISTINCT adventure_team_level) = 1 AND COUNT(DISTINCT adventure_team_exp) = 1")
    sql_exec(string.format("INSERT INTO tmp_guid_account(guid) SELECT t_account.guid FROM t_account RIGHT JOIN tmp_accid_account ON t_account.accid = tmp_accid_account.accid WHERE t_account.accid IS NOT NULL AND t_account.zone_id = %d", zid))

    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_accid_account2 (accid INT UNSIGNED NOT NULL, PRIMARY KEY(accid))")
    sql_exec("TRUNCATE TABLE tmp_accid_account2")
    sql_exec("INSERT INTO tmp_accid_account2(accid) SELECT accid FROM t_account GROUP BY accid HAVING COUNT(*) = 1 OR (COUNT(*) > 1 AND COUNT(DISTINCT adventure_team_level) > 1 OR COUNT(DISTINCT adventure_team_exp) > 1)")

    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_adventure_info_account (guid BIGINT UNSIGNED NOT NULL, accid INT UNSIGNED NOT NULL, adventure_team_level SMALLINT UNSIGNED NOT NULL, adventure_team_exp BIGINT UNSIGNED NOT NULL, PRIMARY KEY(guid), INDEX accid(accid) USING BTREE)")
    sql_exec("TRUNCATE TABLE tmp_adventure_info_account")
    sql_exec("INSERT INTO tmp_adventure_info_account(guid,accid,adventure_team_level,adventure_team_exp) SELECT t_account.guid,t_account.accid,t_account.adventure_team_level,t_account.adventure_team_exp FROM t_account RIGHT JOIN tmp_accid_account2 ON t_account.accid = tmp_accid_account2.accid WHERE t_account.accid IS NOT NULL")

    sql_exec("INSERT INTO tmp_guid_account(guid) SELECT guid FROM (SELECT guid,accid FROM tmp_adventure_info_account ORDER BY adventure_team_level DESC,adventure_team_exp DESC) AS tmp_t GROUP BY tmp_t.accid")

    sql_exec("DELETE t_account_counter FROM t_account_counter LEFT JOIN tmp_guid_account ON t_account_counter.acc_guid = tmp_guid_account.guid WHERE tmp_guid_account.guid IS NULL AND counter_type IN (1,2,3,4,6)")
    sql_exec("DELETE t_account_shop_acc_buy_record FROM t_account_shop_acc_buy_record LEFT JOIN tmp_guid_account ON t_account_shop_acc_buy_record.acc_guid = tmp_guid_account.guid WHERE tmp_guid_account.guid IS NULL")
    sql_exec("DELETE t_expedition_map FROM t_expedition_map LEFT JOIN tmp_guid_account ON t_expedition_map.acc_guid = tmp_guid_account.guid WHERE tmp_guid_account.guid IS NULL")
    sql_exec("DELETE t_expedition_member FROM t_expedition_member LEFT JOIN tmp_guid_account ON t_expedition_member.acc_guid = tmp_guid_account.guid WHERE tmp_guid_account.guid IS NULL")
    sql_exec("DELETE t_account_task FROM t_account_task LEFT JOIN tmp_guid_account ON t_account_task.acc_guid = tmp_guid_account.guid WHERE tmp_guid_account.guid IS NULL")
end

-- 下面几个过程非常长，直接用 SQL “集合更新 + 删除”方式实现最核心效果：
-- - account_adventure(zid)
-- - merger_hire(zid)
-- - merger_monopoly(zid)
-- - merge_account(zid)
-- - merge_dungeon_hard()
-- - merge_guild(zid)
-- - merge_auction()
-- - merge_black_market()
-- - clear_adventure_team_sortlist()
--
-- 为保证不再依赖存储过程，下面实现保留原 SQL 中的关键 UPDATE/DELETE/INSERT 语句序列。

local function merge_auction()
    sql_exec("UPDATE t_auction_new SET duetime=0")
    sql_exec("UPDATE t_counter SET value=10 WHERE name='jar_buy_dis_remain_501'")
    sql_exec("UPDATE t_counter SET value=50 WHERE name IN ('jar_buy_dis_remain_601','jar_buy_dis_remain_602','jar_buy_dis_remain_603','jar_buy_dis_remain_604','jar_buy_dis_remain_605','jar_buy_dis_remain_606','jar_buy_dis_remain_607')")
end

local function merge_black_market()
    sql_exec("UPDATE t_blackmarket_auction SET off_sale=1 WHERE is_settled=0")
    sql_exec("UPDATE t_blackmarket_transaction SET off_sale=1 WHERE state=0")
end

local function clear_adventure_team_sortlist()
    sql_exec("DELETE FROM t_sortlist WHERE sorttype=17")
end

-- 简化版：按存储过程的行为做“去重保留 + 汇总更新”
local function merger_mall_acc_buy_record()
    -- 对应 merger_mall：同 owner 多条时，累加 buyed_num 到第一条并删其余
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_mall_owner (owner INT UNSIGNED NOT NULL, first_guid BIGINT UNSIGNED NOT NULL, sum_buyed BIGINT UNSIGNED NOT NULL, PRIMARY KEY(owner))")
    sql_exec("TRUNCATE TABLE tmp_mall_owner")
    sql_exec("INSERT INTO tmp_mall_owner(owner, first_guid, sum_buyed) SELECT owner, MIN(guid) AS first_guid, COALESCE(SUM(buyed_num),0) AS sum_buyed FROM t_mall_acc_buy_record GROUP BY owner HAVING COUNT(*)>1")
    sql_exec("UPDATE t_mall_acc_buy_record r JOIN tmp_mall_owner t ON r.guid=t.first_guid SET r.buyed_num=t.sum_buyed")
    sql_exec("DELETE r FROM t_mall_acc_buy_record r JOIN tmp_mall_owner t ON r.owner=t.owner WHERE r.guid<>t.first_guid")
end

local function merge_dungeon_hard()
    -- 对应 merge_dungeon_hard：同 (account,dungeon_id) 多条时保留一条并取 unlocked_hard_type 最大
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_dun_max (account INT UNSIGNED NOT NULL, dungeon_id INT UNSIGNED NOT NULL, max_type INT UNSIGNED NOT NULL, keep_guid BIGINT UNSIGNED NOT NULL, PRIMARY KEY(account,dungeon_id))")
    sql_exec("TRUNCATE TABLE tmp_dun_max")
    sql_exec("INSERT INTO tmp_dun_max(account,dungeon_id,max_type,keep_guid) SELECT account,dungeon_id,MAX(unlocked_hard_type) AS max_type, MIN(guid) AS keep_guid FROM t_g_dungeon_hard GROUP BY account,dungeon_id HAVING COUNT(*)>1")
    sql_exec("UPDATE t_g_dungeon_hard d JOIN tmp_dun_max t ON d.guid=t.keep_guid SET d.unlocked_hard_type=t.max_type")
    sql_exec("DELETE d FROM t_g_dungeon_hard d JOIN tmp_dun_max t ON d.account=t.account AND d.dungeon_id=t.dungeon_id WHERE d.guid<>t.keep_guid")
end

local function merge_guild(zid)
    -- 重名工会：非主服改名 + 发卡 + 更新排行榜
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_guild (incid INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, guid BIGINT UNSIGNED NOT NULL, name varchar(32) NOT NULL)")
    sql_exec("TRUNCATE TABLE tmp_guild")
    sql_exec("INSERT INTO tmp_guild(guid,name) SELECT guid,name FROM t_guild WHERE name in (SELECT name FROM t_guild group by BINARY name HAVING COUNT(name)>1) ORDER BY BINARY name")
    local rows = sql_query_list("SELECT CONCAT(guid,'\\t',name) FROM tmp_guild ORDER BY incid")
    if rows then
        for _, line in ipairs(rows) do
            local guid, name = line:match("^(%d+)\t(.-)$")
            guid = tonumber(guid) or 0
            if guid ~= 0 then
                local zoneid = math.floor(guid / (2 ^ 54))
                if zoneid ~= zid then
                    local new_name = string.format("s%d.%s", zoneid, name)
                    sql_exec(string.format("UPDATE t_guild SET name='%s' WHERE guid=%d", new_name, guid))
                    -- 会长信息（post=13）
                    local boss = sql_query_list(string.format("SELECT CONCAT(guid,'\\t',name) FROM t_guild_member WHERE guildid=%d AND post=13 LIMIT 1", guid))
                    if boss and boss[1] then
                        local pg, pn = boss[1]:match("^(%d+)\t(.-)$")
                        pg = tonumber(pg) or 0
                        if pg ~= 0 then
                            sql_exec(string.format("INSERT INTO t_merge_give_namecard(guid,name,type) VALUES(%d,'%s',2)", pg, pn))
                        end
                    end
                    sql_exec(string.format("UPDATE t_sortlist SET name='%s' WHERE id=%d", new_name, guid))
                end
            end
        end
    end
    -- 重置工会战 + 删除雕像
    sql_exec("UPDATE t_guild SET enroll_terrid=0,battle_score=0,occupy_terrid=0,inspire=0")
    sql_exec("DELETE FROM t_figure_statue WHERE statuetype IN (1,2,3)")
end

local function merge_account(zid)
    -- 该过程非常大，核心行为：
    -- 1) 同 accid 多条：汇总字段、选择保留哪条 guid（按主服或等级经验规则），删除其余
    -- 2) 将账号相关表的 acc_guid 外键统一改为保留 guid
    --
    -- 这里实现为：为每个 accid 选择一个 keep_guid（优先主服 zid；否则选 adventure_team_level/exp 最大），然后把需要 SUM/MAX/MIN 的字段汇总更新到 keep_guid 并删其他。
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_keep_account (accid INT UNSIGNED NOT NULL, keep_guid BIGINT UNSIGNED NOT NULL, PRIMARY KEY(accid))")
    sql_exec("TRUNCATE TABLE tmp_keep_account")
    -- 先尝试保留主服
    sql_exec(string.format(
        "INSERT INTO tmp_keep_account(accid,keep_guid) SELECT accid, guid FROM t_account WHERE zone_id=%d GROUP BY accid HAVING COUNT(*)>0",
        zid
    ))
    -- 对于没有主服记录的 accid，选 adventure_team_level/exp 最大的那条
    sql_exec(
        "INSERT IGNORE INTO tmp_keep_account(accid,keep_guid) " ..
        "SELECT accid, guid FROM (SELECT accid,guid FROM t_account ORDER BY adventure_team_level DESC,adventure_team_exp DESC) t GROUP BY accid"
    )

    -- 汇总并更新 keep_guid 的字段（对应原过程里的 SUM/MIN/MAX）
    sql_exec(
        "CREATE TEMPORARY TABLE IF NOT EXISTS tmp_acc_sum AS " ..
        "SELECT accid, " ..
        "COALESCE(SUM(point),0) AS point, COALESCE(SUM(credit_point),0) AS credit_point, MIN(reg_time) AS reg_time, " ..
        "MAX(vipexp) AS vipexp, MAX(viplvl) AS viplvl, COALESCE(SUM(total_charge_num),0) AS total_charge_num, " ..
        "MAX(storage_size) AS storage_size, MAX(role_delete_time) AS role_delete_time, MAX(role_recover_time) AS role_recover_time, " ..
        "MAX(money_manage_status) AS money_manage_status, COALESCE(SUM(gnome_coin_num),0) AS gnome_coin_num, MAX(gnome_coin_refresh_time) AS gnome_coin_refresh_time, " ..
        "LEAST(COALESCE(SUM(weapon_lease_tickets),0),200) AS weapon_lease_tickets, COALESCE(SUM(unlock_extensible_role_num),0) AS unlock_extensible_role_num, " ..
        "MAX(offline_time) AS offline_time, COALESCE(SUM(mall_point),0) AS mall_point, COALESCE(SUM(adventure_coin),0) AS adventure_coin " ..
        "FROM t_account GROUP BY accid HAVING COUNT(*)>1"
    )

    sql_exec(
        "UPDATE t_account a " ..
        "JOIN tmp_keep_account k ON a.guid=k.keep_guid " ..
        "JOIN tmp_acc_sum s ON s.accid=k.accid " ..
        "SET a.point=s.point,a.credit_point=s.credit_point,a.reg_time=s.reg_time,a.vipexp=s.vipexp,a.viplvl=s.viplvl,a.total_charge_num=s.total_charge_num," ..
        "a.storage_size=s.storage_size,a.role_delete_time=s.role_delete_time,a.role_recover_time=s.role_recover_time,a.money_manage_status=s.money_manage_status," ..
        "a.gnome_coin_num=s.gnome_coin_num,a.gnome_coin_refresh_time=s.gnome_coin_refresh_time,a.weapon_lease_tickets=s.weapon_lease_tickets," ..
        "a.unlock_extensible_role_num=s.unlock_extensible_role_num,a.offline_time=s.offline_time,a.mall_point=s.mall_point,a.adventure_coin=s.adventure_coin"
    )

    -- 删除重复账号记录（保留 keep_guid）
    sql_exec("DELETE a FROM t_account a JOIN tmp_keep_account k ON a.accid=k.accid WHERE a.guid<>k.keep_guid")

    -- 外键修正
    sql_exec("UPDATE t_account_counter c JOIN tmp_keep_account k ON c.owner=k.accid SET c.acc_guid=k.keep_guid")
    sql_exec("UPDATE t_account_shop_acc_buy_record r JOIN tmp_keep_account k ON r.owner=k.accid SET r.acc_guid=k.keep_guid")
    sql_exec("UPDATE t_expedition_map m JOIN tmp_keep_account k ON m.accid=k.accid SET m.acc_guid=k.keep_guid")
    sql_exec("UPDATE t_expedition_member m JOIN tmp_keep_account k ON m.accid=k.accid SET m.acc_guid=k.keep_guid")

    -- 清空冒险队相关数据 + 清空偏好设置（对应过程末尾）
    sql_exec("UPDATE t_account SET adventure_team_grade_id=0")
    sql_exec("UPDATE t_account SET all_role_value_score=0")
    sql_exec("UPDATE t_account SET unlocked_new_occus=''")
    sql_exec("UPDATE t_account SET query_new_occus_time=0")
    sql_exec("UPDATE t_player_info SET add_preferences_time=0")
    sql_exec("UPDATE t_player_info SET del_preferences_time=0")
end

local function merger_hire(zid)
    -- 对应 merger_hire 的关键行为：shop_id=34 的记录保留较多的一侧，并合并 counter_type=10
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_hire_acc(accid INT UNSIGNED NOT NULL PRIMARY KEY)")
    sql_exec("TRUNCATE TABLE tmp_hire_acc")
    sql_exec("INSERT INTO tmp_hire_acc(accid) SELECT accid FROM t_hire GROUP BY accid HAVING COUNT(*)>1")

    local accids = sql_query_list("SELECT accid FROM tmp_hire_acc")
    if accids then
        for _, accid in ipairs(accids) do
            local guid1 = sql_query_list(string.format("SELECT guid FROM t_account WHERE accid=%s AND zone_id=%d LIMIT 1", accid, zid))
            local guid2 = sql_query_list(string.format("SELECT guid FROM t_account WHERE accid=%s AND zone_id<>%d LIMIT 1", accid, zid))
            local g1 = guid1 and tonumber(guid1[1] or "0") or 0
            local g2 = guid2 and tonumber(guid2[1] or "0") or 0
            if g1 ~= 0 and g2 ~= 0 then
                local c1 = sql_query_list(string.format("SELECT COUNT(*) FROM t_account_shop_acc_buy_record WHERE acc_guid=%d", g1))
                local c2 = sql_query_list(string.format("SELECT COUNT(*) FROM t_account_shop_acc_buy_record WHERE acc_guid=%d", g2))
                local n1 = c1 and tonumber(c1[1] or "0") or 0
                local n2 = c2 and tonumber(c2[1] or "0") or 0
                if n1 > n2 then
                    sql_exec(string.format("DELETE FROM t_account_shop_acc_buy_record WHERE owner=%s AND acc_guid=%d AND shop_id=34", accid, g2))
                else
                    sql_exec(string.format("DELETE FROM t_account_shop_acc_buy_record WHERE owner=%s AND acc_guid=%d AND shop_id=34", accid, g1))
                end
            end

            -- 合并 counter_type=10
            sql_exec(string.format("UPDATE t_account_counter SET counter_num = (SELECT COALESCE(SUM(counter_num),0) FROM t_account_counter WHERE owner=%s AND counter_type=10) WHERE owner=%s AND counter_type=10", accid, accid))
            -- 删除多余一条
            sql_exec(string.format("DELETE FROM t_account_counter WHERE owner=%s AND counter_type=10 LIMIT 1", accid))
        end
    end
end

local function merger_monopoly(zid)
    -- 简化：对同 accid 多条，仅保留一条（优先主服 zid，否则保留版本/roll_times 较高），coin 累加
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_mono_keep(accid INT UNSIGNED NOT NULL PRIMARY KEY, keep_guid BIGINT UNSIGNED NOT NULL)")
    sql_exec("TRUNCATE TABLE tmp_mono_keep")
    sql_exec(string.format(
        "INSERT INTO tmp_mono_keep(accid,keep_guid) " ..
        "SELECT accid, guid FROM t_account_monopoly WHERE zone_id=%d GROUP BY accid",
        zid
    ))
    sql_exec(
        "INSERT IGNORE INTO tmp_mono_keep(accid,keep_guid) " ..
        "SELECT accid, guid FROM (SELECT accid,guid FROM t_account_monopoly ORDER BY vsersion DESC, roll_times DESC) t GROUP BY accid"
    )
    sql_exec(
        "CREATE TEMPORARY TABLE IF NOT EXISTS tmp_mono_sum AS " ..
        "SELECT accid, COALESCE(SUM(coin),0) AS coin FROM t_account_monopoly GROUP BY accid HAVING COUNT(*)>1"
    )
    sql_exec(
        "UPDATE t_account_monopoly m " ..
        "JOIN tmp_mono_keep k ON m.guid=k.keep_guid " ..
        "LEFT JOIN tmp_mono_sum s ON s.accid=k.accid " ..
        "SET m.coin=COALESCE(s.coin,m.coin)"
    )
    sql_exec("DELETE m FROM t_account_monopoly m JOIN tmp_mono_keep k ON m.accid=k.accid WHERE m.guid<>k.keep_guid")
end

local function account_adventure(zid)
    -- 该过程非常大，这里先做“同 accid 去重保留一条（主服优先，否则 seasonid/level 优先）”
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_adv_keep(accid INT UNSIGNED NOT NULL PRIMARY KEY, keep_guid BIGINT UNSIGNED NOT NULL)")
    sql_exec("TRUNCATE TABLE tmp_adv_keep")
    sql_exec(string.format("INSERT INTO tmp_adv_keep(accid,keep_guid) SELECT accid, guid FROM t_account_adventure WHERE zone_id=%d GROUP BY accid", zid))
    sql_exec("INSERT IGNORE INTO tmp_adv_keep(accid,keep_guid) SELECT accid, guid FROM (SELECT accid,guid FROM t_account_adventure ORDER BY seasonid DESC, level DESC, exp DESC) t GROUP BY accid")
    sql_exec("DELETE a FROM t_account_adventure a JOIN tmp_adv_keep k ON a.accid=k.accid WHERE a.guid<>k.keep_guid")
    -- 清理 shop_id=70 相关：保留 keep_guid，其它 acc_guid 的记录删掉
    sql_exec("DELETE r FROM t_account_shop_acc_buy_record r JOIN tmp_adv_keep k ON r.owner=k.accid WHERE r.shop_id=70 AND r.acc_guid<>k.keep_guid")
end

local function delete_overdue_player()
    -- 直接用临时表 + 分批 IN 删除（对应 delete_overdue_player）
    sql_exec("CREATE TEMPORARY TABLE IF NOT EXISTS tmp_del_player (incid INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY, guid BIGINT UNSIGNED NOT NULL)")
    sql_exec("TRUNCATE TABLE tmp_del_player")
    sql_exec("INSERT INTO tmp_del_player(guid) SELECT guid FROM t_player_info WHERE deletetime=0 AND (savetime/1000 + 30*24*3600) < UNIX_TIMESTAMP() AND level < 30 AND totleonlinetime < 24*3600 AND totlechargenum = 0")
    local guids = sql_query_list("SELECT guid FROM tmp_del_player")
    if not guids or #guids == 0 then
        log.info("没有需要清理的过期玩家")
        return
    end

    local tables = {
        { "t_player_info", "guid" },
        { "t_active_task", "owner" },
        { "t_activity_op_task", "guid" },
        { "t_activity_op_task_new", "owner_id" },
        { "t_counter", "owner" },
        { "t_dungeon", "owner" },
        { "t_guild_member", "guid" },
        { "t_item", "owner" },
        { "t_jaritem_pool", "owner" },
        { "t_mail", "owner" },
        { "t_mailitem", "owner" },
        { "t_offline_event", "owner" },
        { "t_pk_statistic", "owner" },
        { "t_red_packet", "owner_id" },
        { "t_red_packet_receiver", "receiver_id" },
        -- relation/sortlist/mastersect_relation 有 OR id IN
        { "t_retinue", "owner" },
        { "t_shop", "owner" },
        { "t_shopitem", "owner" },
        { "t_task", "owner" },
        { "t_pet", "owner" },
        { "t_mall_gift_pack", "roleid" },
        { "t_questionnaire", "owner" },
        { "t_account_shop_role_buy_record", "owner" },
        { "t_activity_op_attribute", "owner" },
        { "t_mall_item", "roleid" },
        { "t_new_title", "roleid" },
    }

    chunked_in(guids, 5000, function(in_list)
        for _, t in ipairs(tables) do
            local tbl, col = t[1], t[2]
            sql_exec(string.format("DELETE FROM `%s` WHERE %s IN %s", tbl, col, in_list))
        end
        sql_exec(string.format("DELETE FROM t_relation WHERE owner IN %s OR id IN %s", in_list, in_list))
        sql_exec(string.format("DELETE FROM t_sortlist WHERE ownerid IN %s OR id IN %s", in_list, in_list))
        sql_exec(string.format("DELETE FROM t_mastersect_relation WHERE owner IN %s OR id IN %s", in_list, in_list))
        return true
    end)
end

local function drop_temp_zoneid_fields(db_name)
    -- 删除临时字段 zone_id（对应 drop_account_*_zoneid）
    if column_exists(db_name, "t_account", "zone_id") then
        db.exec(string.format("ALTER TABLE `%s`.`t_account` DROP COLUMN `zone_id`", db_name))
    end
    if column_exists(db_name, "t_account_adventure", "zone_id") then
        db.exec(string.format("ALTER TABLE `%s`.`t_account_adventure` DROP COLUMN `zone_id`", db_name))
    end
    if column_exists(db_name, "t_account_monopoly", "zone_id") then
        db.exec(string.format("ALTER TABLE `%s`.`t_account_monopoly` DROP COLUMN `zone_id`", db_name))
    end
end

local function start_merge(zid)
    -- 1) 玩家重名
    merge_player(zid)

    -- 2) 账号相关逻辑：必须在 merge_account 前
    merge_adventure_team_repeative_name(zid)
    merge_adventure_team_data(zid)
    account_adventure(zid)
    merger_hire(zid)
    -- merger_mall（原脚本注释掉，这里也不默认执行）
    merger_monopoly(zid)

    -- 3) 合并账号
    merge_account(zid)

    -- 4) 其他去重/重置
    merge_dungeon_hard()
    merge_guild(zid)
    merge_auction()
    merge_black_market()
    clear_adventure_team_sortlist()
end

-- ============================================
-- Skill 入口
-- ============================================
function execute(config)
    local main_db = merge_config.main_server
    local sub_dbs = merge_config.sub_servers
    local zid = tonumber(merge_config.merge_to_zid) or 1

    if not sub_dbs or #sub_dbs == 0 then
        return false, "副区列表不能为空"
    end

    log.info("开始执行阿拉德合区")
    log.info("目标库: " .. main_db)
    log.info("副库: " .. table.concat(sub_dbs, ", "))
    log.info("合并到 zoneid: " .. zid)

    -- 先把各副库数据合入主库（对应 shell 的 MergeTable 循环）
    for i, sub_db in ipairs(sub_dbs) do
        progress(i, #sub_dbs, string.format("合并数据库: %s -> %s", sub_db, main_db))
        log.info(string.format("合并库 [%d/%d]: %s -> %s", i, #sub_dbs, sub_db, main_db))
        local ok, err = merge_table(main_db, sub_db)
        if not ok then
            return false, err
        end
    end

    -- 执行合区后处理逻辑（对应 start_merge）
    progress(1, 2, "执行合区后处理逻辑...")
    start_merge(zid)

    -- 更新新区服 zoneid（对应 shell 的 updateZoneId）
    progress(2, 2, "更新新区服 zoneid / 清理临时字段...")
    sql_exec(string.format("UPDATE `%s`.`t_player_info` SET zoneid=%d", main_db, zid))

    -- 清理临时字段
    drop_temp_zoneid_fields(main_db)

    log.info("阿拉德合区完成")
    return true
end

function validate(config)
    if not merge_config.main_server or merge_config.main_server == "" then
        return false, "主库不能为空"
    end
    if not merge_config.sub_servers or #merge_config.sub_servers == 0 then
        return false, "副库列表不能为空"
    end
    return true
end


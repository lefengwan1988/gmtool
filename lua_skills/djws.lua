-- @name: 刀剑无双
-- @description: 刀剑无双通用合区工具（使用通用 JSON 配置 djws.json）

-- 说明：
-- 本脚本仅做“壳”，真正的合区逻辑全部在 `universal_merge.lua` 中，
-- 并通过 JSON 配置 `legacy_configs/script/djws.json` 来驱动。

-- 加载通用合区工具
dofile("lua_skills/universal_merge.lua")

-- 覆盖通用工具中的默认配置，指定刀剑无双专用的 JSON 脚本
merge_config.json_script = "djws.json"

-- 如需为刀剑无双单独设置数据库连接或主/副区信息，可在下面修改：
-- db_config.user = "root"
-- db_config.password = "123456"
-- db_config.host = "127.0.0.1"
-- db_config.port = "3306"
--
-- merge_config.main_server.db_name = "game1"
-- merge_config.main_server.server_id = "1"
-- merge_config.main_server.account_db_name = "login_game1"
--
-- merge_config.sub_servers = {
--     {
--         db_name = "game2",
--         server_id = "2",
--         prefix = "2s",
--         account_suffix = "s2",
--         account_db_name = "login_game2",
--     },
--     -- 可以继续追加更多副区
-- }

-- 因为 `universal_merge.lua` 中已经定义了 `execute` 和 `validate`，
-- 这里无需再实现，gmtool 会直接调用通用脚本中的这两个函数。


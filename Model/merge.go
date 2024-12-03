package Model

import (
	_ "database/sql"
	"fmt"
	_ "log"
	"os"
	"strings"
	_ "time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

func initLogger() {
	logrus.SetFormatter(&logrus.TextFormatter{
		ForceColors: true,
	})
	logrus.SetOutput(os.Stdout)
	logrus.SetLevel(logrus.DebugLevel)
}

/**
 * 合服 大秦无双
 */
func ModelDqws() {
	//GOOS=linux;GOARCH=amd64  编译linux
	initLogger()

	viper.SetConfigFile("./config.ini")
	err := viper.ReadInConfig()
	if err != nil {
		logrus.Fatalf("配置文件 config 不存在")
	}

	dbHost := viper.GetString("MYSQL.mysqlhost")
	dbUser := viper.GetString("MYSQL.mysqluser")
	dbPasswd := viper.GetString("MYSQL.mysqlpasswd")
	qianzhui := viper.GetString("config.qianzhui") + "_"
	zhuquId := viper.GetString("config.zhuqu")
	fuqu := viper.GetString("config.fuqu")

	logrus.Infof("主区ID: %s", zhuquId)
	logrus.Infof("副区ID: %s", fuqu)

	fuquArr := strings.Split(fuqu, ",")

	logrus.Warning("确认以上服务器将被合并,回车键继续")
	logrus.Warning("CTRL + C 可退出或中断程序")
	logrus.Warning("合服注意：先关闭要合并的区服，再执行合服命令")
	logrus.Warning("合区工具 By 乐疯玩")
	fmt.Scanln()

	logrus.Info("===========================================")

	connStr := fmt.Sprintf("%s:%s@tcp(%s)/?charset=utf8&parseTime=True&loc=Local", dbUser, dbPasswd, dbHost)
	db, err := sqlx.Connect("mysql", connStr)
	if err != nil {
		logrus.Fatalf("数据库连接失败: %v", err)
	}
	defer db.Close()

	noMerge := []string{
		"base_acc_stage_add_attr",
		"base_acc_star_add_attr",
		"base_achievement",
		"base_achievement_subtype",
		"base_achievement_type",
		"base_act_boss_reset",
		"base_act_cumu_pay",
		"base_act_daily_consume",
		"base_act_discount_shop",
		"base_act_discount_shop_new",
		"base_act_dragon_cave",
		"base_act_dragon_cave_shop",
		"base_act_eagle_eye_item",
		"base_act_eagle_eye_item_type",
		"base_act_eagle_eye_stage",
		"base_act_eagle_eye_win_award",
		"base_act_golden_eggs",
		"base_act_guild_feast_question",
		"base_act_lucky_flop",
		"base_act_lucky_stick",
		"base_act_lucky_wheel",
		"base_act_single_charge",
		"base_act_super_star_award",
		"base_act_super_star_like",
		"base_act_super_star_point",
		"base_act_supreme_god_attr",
		"base_act_supreme_god_award",
		"base_act_tell_truth_award",
		"base_act_tell_truth_question",
		"base_act_time_limit_buy",
		"base_act_yuanbao_wheel",
		"base_act_yuanbao_wheel_award",
		"base_act_zodiac_befall",
		"base_act_zodiac_dun",
		"base_act_zodiac_question",
		"base_act_zodiac_treasure",
		"base_activity_extra_drop",
		"base_airplane_jump",
		"base_airplane_jump_shop",
		"base_angra_kill",
		"base_angra_stage",
		"base_attr",
		"base_bag",
		"base_bag_unlock",
		"base_beast_power",
		"base_boss_drop_limit",
		"base_boss_essence_drop",
		"base_boss_home",
		"base_boss_spec_drop",
		"base_bot_recommend",
		"base_bride_price",
		"base_bt",
		"base_career",
		"base_carnival_collect_word",
		"base_celebration_exchange_award",
		"base_chaos_bf_mon_group",
		"base_charge_group",
		"base_charge_group_op_act",
		"base_chat_channel",
		"base_chat_emoji",
		"base_child",
		"base_common_tips",
		"base_compound",
		"base_compound_gem_op_act",
		"base_compound_open_cond",
		"base_compound_tree",
		"base_couple_pk_bet",
		"base_couple_pk_normal_reward",
		"base_couple_pk_reward",
		"base_couple_pk_shop",
		"base_crowd_donate",
		"base_crowd_donate2",
		"base_crowd_donate2_world_award",
		"base_crowd_donate_world_award",
		"base_cumulative_login",
		"base_daily_act",
		"base_daily_act_award",
		"base_daily_act_calendar",
		"base_daily_act_open",
		"base_daily_pray_cost",
		"base_daily_pray_exp_add",
		"base_daily_pray_reward",
		"base_daily_pray_times",
		"base_daily_recharge_today",
		"base_daily_sign",
		"base_discount_buy_batch",
		"base_discount_buy_goods",
		"base_dragon_sprite",
		"base_drama",
		"base_drop",
		"base_drop0",
		"base_drop1",
		"base_drop2",
		"base_drop3",
		"base_drop4",
		"base_drop5",
		"base_drop6",
		"base_drop7",
		"base_drop8",
		"base_drop8_copy1",
		"base_drop9",
		"base_drop_lite",
		"base_dungeon",
		"base_dungeon_demon_exp",
		"base_dungeon_demon_inspire",
		"base_dungeon_double",
		"base_dungeon_lv",
		"base_dungeon_type",
		"base_effect",
		"base_effect_hook",
		"base_email",
		"base_emperor_hunt",
		"base_emperor_hunt_cost",
		"base_equip_forge",
		"base_equip_juexing",
		"base_equip_juexing_fuling",
		"base_equip_juexing_suit",
		"base_equip_juexing_upgrade",
		"base_equip_suit",
		"base_equip_suit_type",
		"base_equip_upgrade",
		"base_equip_wash_attr_quality",
		"base_equip_wash_lock_cost",
		"base_equip_wash_pos",
		"base_equip_wash_weight",
		"base_exceloption",
		"base_exp_perc",
		"base_fake_player_robot",
		"base_fashion",
		"base_fashion_attr",
		"base_fashion_cabinet",
		"base_fashion_show",
		"base_fashion_suit",
		"base_fashion_type",
		"base_firework_celebration_award",
		"base_firework_celebration_rule",
		"base_first_charge",
		"base_flower",
		"base_fragment_treasure_hunt",
		"base_fragment_treasure_hunt_rule",
		"base_game",
		"base_gather_soul",
		"base_gather_soul_hole",
		"base_gather_soul_lv",
		"base_gather_soul_recommend",
		"base_gem_equip_pos",
		"base_gem_hole_condition",
		"base_gem_process",
		"base_gem_refine",
		"base_gem_upgrade",
		"base_god_equip",
		"base_god_equip_juling",
		"base_god_equip_juling_skill",
		"base_god_equip_suit",
		"base_goods",
		"base_guild_act_award",
		"base_guild_base",
		"base_guild_base_gonghui",
		"base_guild_charge_red_envelop",
		"base_guild_honor_pos",
		"base_guild_league_buff",
		"base_guild_league_kill_notice",
		"base_guild_league_person_award",
		"base_guild_league_settle_award",
		"base_guild_league_win_award",
		"base_guild_pos_right",
		"base_guild_red_envelop_desc",
		"base_guild_score_award",
		"base_guild_skill",
		"base_guild_skill_upgrade",
		"base_guild_task",
		"base_happy_hunt",
		"base_happy_hunt_cost",
		"base_heart_lock_upgrade",
		"base_honor",
		"base_huancai_decompose",
		"base_hudun_skill_up",
		"base_huling_upgrade",
		"base_hunter_task",
		"base_intimacy",
		"base_item_legendary_attr",
		"base_item_type",
		"base_items",
		"base_items_attr",
		"base_jade_hole_condition",
		"base_jade_upgrade",
		"base_jianghu_arena_gap",
		"base_jianghu_arena_reward",
		"base_jianghu_arena_robot",
		"base_jingmai_add",
		"base_jingmai_levelup",
		"base_jingmai_type",
		"base_kf",
		"base_kf_copy1",
		"base_kf_flower_rank",
		"base_kf_mining_rank_add",
		"base_kf_sys",
		"base_level_reward_act",
		"base_loading_pics",
		"base_loading_word",
		"base_log",
		"base_log_combat_power",
		"base_login_reward",
		"base_lv_supress",
		"base_magic_ring",
		"base_magic_ring_condition",
		"base_market_tree",
		"base_master_pet",
		"base_mihun",
		"base_miyin_decompose",
		"base_miyin_investment",
		"base_miyin_item_suit",
		"base_miyin_strengthen",
		"base_miyin_suit",
		"base_miyin_temple",
		"base_miyin_temple_totem",
		"base_mon",
		"base_mon_ai_option",
		"base_mon_attr_adept",
		"base_mon_play_animation",
		"base_month_card",
		"base_moqi_test",
		"base_mount",
		"base_mount_break_through",
		"base_mount_equip_fuhun",
		"base_mount_equip_fuhun_skill",
		"base_mount_equip_upgrade",
		"base_mount_soul",
		"base_mount_soul_limit",
		"base_mount_upgrade",
		"base_mystery_shopping",
		"base_name",
		"base_nine_layers_tower",
		"base_notice",
		"base_notice_param",
		"base_npc",
		"base_op_act_acc_charge_reward",
		"base_op_act_acc_charge_reward2",
		"base_op_act_black_market",
		"base_op_act_charge_double",
		"base_op_act_charge_rank",
		"base_op_act_charge_reward",
		"base_op_act_collect_word",
		"base_op_act_con_charge",
		"base_op_act_consume_rank",
		"base_op_act_daily_target",
		"base_op_act_equip_target",
		"base_op_act_flower_rank",
		"base_op_act_gift1",
		"base_op_act_gift2",
		"base_op_act_gold_tower_exchange",
		"base_op_act_gold_tower_lottery",
		"base_op_act_hefu_guild_league",
		"base_op_act_hefu_happy",
		"base_op_act_identify_treasure",
		"base_op_act_kf_cloud_buy",
		"base_op_act_lucky_wish",
		"base_op_act_magpie_bridge_rank",
		"base_op_act_marriage",
		"base_op_act_mount_rank",
		"base_op_act_pet_rank",
		"base_op_act_royal_auction",
		"base_op_act_shenbing_befall",
		"base_op_act_transform_rank",
		"base_op_act_upgrade_mat_ret",
		"base_op_activity",
		"base_op_activity_award_index",
		"base_op_activity_merge_serv",
		"base_op_activity_open_serv",
		"base_op_activity_theme",
		"base_op_crowd_funding",
		"base_op_crowd_funding_target",
		"base_op_hunt_boss",
		"base_op_hunt_boss_point",
		"base_op_new_zero_buy",
		"base_op_open_hunt_boss",
		"base_op_type",
		"base_open_act_award",
		"base_open_carnival",
		"base_open_carnival_award",
		"base_paper_crane",
		"base_pet_break_through",
		"base_pet_dovour_equip",
		"base_pet_skill",
		"base_pet_soul_stone",
		"base_pet_upgrade",
		"base_phone_qq_super_vip_renew",
		"base_push_content",
		"base_qq_vhome_privilege_award",
		"base_quanming_happy",
		"base_quanming_happy_rule",
		"base_rare_item",
		"base_recharge",
		"base_recharge_acc",
		"base_recharge_model",
		"base_resource_findback",
		"base_ret_num",
		"base_revive_cost",
		"base_robot_skill",
		"base_role_levelup",
		"base_role_primary_attr_trans",
		"base_rookie_guide",
		"base_royal_auction",
		"base_royal_hunt",
		"base_royal_hunt_cost",
		"base_saint_guard_award",
		"base_saint_guard_spec_mon",
		"base_scene",
		"base_scene_mask",
		"base_seal",
		"base_seal_task_proc",
		"base_seconds_kill_batch",
		"base_seconds_kill_goods",
		"base_sensitive_word",
		"base_set_hunt",
		"base_set_hunt_cost",
		"base_setting_control_effect",
		"base_shape_shift",
		"base_shenbing",
		"base_shenbing_upgrade",
		"base_shenshou",
		"base_shenshou_extend",
		"base_shenshou_upgrade",
		"base_shenshou_upgrade_exp",
		"base_shop",
		"base_skill",
		"base_skill_lv",
		"base_skill_lv_up",
		"base_skill_time_point",
		"base_skill_time_point_lv",
		"base_slave_pet",
		"base_soft_guide",
		"base_soul_grid",
		"base_soul_ware",
		"base_soul_ware_decompose",
		"base_soul_ware_enchants",
		"base_soul_ware_enchants_unlock",
		"base_soul_ware_star_up",
		"base_soul_ware_tree",
		"base_soul_ware_upgrade",
		"base_star_add_attr",
		"base_strengthen_add_attr",
		"base_strengthen_guide",
		"base_string",
		"base_super_investment",
		"base_super_investment_level",
		"base_svr_red_envelop",
		"base_sword_spirit_levelup",
		"base_sword_spirit_show",
		"base_sys_config",
		"base_sys_function",
		"base_sys_function_foretell",
		"base_talent",
		"base_talk_bubble",
		"base_task",
		"base_tattoo_activate",
		"base_tattoo_hole_activate",
		"base_tattoo_hunt",
		"base_tattoo_hunt_cost",
		"base_tattoo_lv",
		"base_tattoo_tower",
		"base_team_target",
		"base_tiger_tally_decompose",
		"base_tiger_tally_strengthen",
		"base_tiger_tally_upgrade",
		"base_tiger_tally_wear_req",
		"base_timing_boss_act",
		"base_timing_boss_map",
		"base_title",
		"base_title_type",
		"base_top_arena_dan",
		"base_top_arena_feats",
		"base_top_arena_season_rank",
		"base_top_arena_win",
		"base_trans_occupation_item",
		"base_trans_occupation_skill",
		"base_trans_occupation_title",
		"base_transfer_career",
		"base_transfer_career_award",
		"base_transformation",
		"base_transformation_dan",
		"base_transformation_lvup",
		"base_tvt_honor",
		"base_tvt_score",
		"base_tvt_score_stage",
		"base_tvt_season_reward",
		"base_tvt_season_score_reward",
		"base_update_announcement",
		"base_update_bag",
		"base_vip_card",
		"base_vip_investment",
		"base_vip_level",
		"base_want_strengthen",
		"base_wedding_reserve",
		"base_wing_common_attr_item",
		"base_wing_common_main",
		"base_wing_common_main_upgrade",
		"base_wing_common_refine",
		"base_wing_common_sub",
		"base_wing_common_sub_upgrade",
		"base_wing_refine",
		"base_word",
		"base_world_boss_base",
		"base_world_boss_param",
		"base_world_level_add",
		"base_wuxue_attr_normal",
		"base_wuxue_attr_spec",
		"base_wuxue_item",
		"base_wx_shop_award",
		"base_wx_shop_award_group",
		"base_wx_shop_buy",
		"base_xianyangcraft_city",
		"base_xianyangcraft_distribute_award",
		"base_xianyangcraft_distribute_award2",
		"base_xianyangcraft_result_award",
		"base_xianyangcraft_result_award2",
		"base_yuanbao_investment",
		"base_yuanshou",
		"base_yuanshou_breakthrough",
		"base_yuanshou_starup",
		"base_yuanshou_tree",
		"base_yuanshou_type",
		"base_yuanshou_upgrade",
		"base_zero_buy",
		"base_zero_buy_op_act",
		"base_zhuling_unlock",
		"base_zhuling_upgrade",
		"boss_drop_limit",
		"boss_spec_drop",
		"node",
		"node_kf",
		"node_kf_connect",
		"uid",
		"lucky_wheel_log",
	}

	for _, fq := range fuquArr {
		fqdb := qianzhui + fq
		showtable := fmt.Sprintf("SHOW TABLES FROM `%s`", fqdb)
		rows, err := db.Query(showtable)
		if err != nil {
			logrus.Fatalf("查询表失败: %v", err)
		}

		for rows.Next() {
			var table string
			err := rows.Scan(&table)
			if err != nil {
				logrus.Fatalf("扫描表失败: %v", err)
			}
			//logrus.Infof("合并表: %s", table)

			if contains(noMerge, table) {
				continue
			}

			zqdb := qianzhui + zhuquId
			sql := fmt.Sprintf("REPLACE INTO `%s`.`%s` SELECT * FROM `%s`.`%s`", zqdb, table, fqdb, table)
			_, err = db.Exec(sql)
			if err != nil {
				logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
			}
		}
		if err := rows.Err(); err != nil {
			logrus.Fatalf("处理结果集失败: %v", err)
		}
	}

	logrus.Info("完成")
}

/**
 * 合服 智谋天下
 */
func ModelZmtx() {
	//GOOS=linux;GOARCH=amd64  编译linux
	initLogger()

	viper.SetConfigFile("./config.ini")
	err := viper.ReadInConfig()
	if err != nil {
		logrus.Fatalf("配置文件 config 不存在")
	}

	dbHost := viper.GetString("MYSQL.mysqlhost")
	dbUser := viper.GetString("MYSQL.mysqluser")
	dbPasswd := viper.GetString("MYSQL.mysqlpasswd")
	qianzhui := viper.GetString("config.qianzhui") + "_"
	zhuquId := viper.GetString("config.zhuqu")
	fuqu := viper.GetString("config.fuqu")

	logrus.Infof("主区ID: %s", zhuquId)
	logrus.Infof("副区ID: %s", fuqu)

	fuquArr := strings.Split(fuqu, ",")

	logrus.Warning("确认以上服务器将被合并,回车键继续")
	logrus.Warning("CTRL + C 可退出或中断程序")
	logrus.Warning("合服注意：先关闭要合并的区服，再执行合服命令")
	logrus.Warning("合区工具 By 乐疯玩")
	fmt.Scanln()

	logrus.Info("===========================================")

	connStr := fmt.Sprintf("%s:%s@tcp(%s)/?charset=utf8&parseTime=True&loc=Local", dbUser, dbPasswd, dbHost)
	db, err := sqlx.Connect("mysql", connStr)
	if err != nil {
		logrus.Fatalf("数据库连接失败: %v", err)
	}
	defer db.Close()
	for _, fq := range fuquArr {
		fqdb := qianzhui + fq
		zqdb := qianzhui + zhuquId
		sql := fmt.Sprintf("REPLACE INTO `%s`.`t_account` SELECT * FROM `%s`.`t_account`", zqdb, fqdb)
		_, err = db.Exec(sql)
		if err != nil {
			logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
		}
		sql = fmt.Sprintf("REPLACE INTO `%s`.`t_player` SELECT * FROM `%s`.`t_player` where accountUid <> 0", zqdb, fqdb)
		_, err = db.Exec(sql)
		if err != nil {
			logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
		}
		//536884737
		sql = fmt.Sprintf("REPLACE INTO `%s`.`t_recharge_activity` SELECT * FROM `%s`.`t_recharge_activity` where playerId >= 500000000", zqdb, fqdb)
		_, err = db.Exec(sql)
		if err != nil {
			logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
		}
		sql = fmt.Sprintf("REPLACE INTO `%s`.`t_friend` SELECT * FROM `%s`.`t_friend` where playerId >= 536884737", zqdb, fqdb)
		_, err = db.Exec(sql)
		if err != nil {
			logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
		}
		sql = fmt.Sprintf("REPLACE INTO `%s`.`t_competition_reward` SELECT * FROM `%s`.`t_competition_reward` where playerId >= 500000000", zqdb, fqdb)
		_, err = db.Exec(sql)
		if err != nil {
			logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
		}
		sql = fmt.Sprintf("REPLACE INTO `%s`.`t_fund` SELECT * FROM `%s`.`t_fund` where playerId >= 500000000", zqdb, fqdb)
		_, err = db.Exec(sql)
		if err != nil {
			logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
		}
		sql = fmt.Sprintf("REPLACE INTO `%s`.`t_guild` SELECT * FROM `%s`.`t_guild`", zqdb, fqdb)
		_, err = db.Exec(sql)
		if err != nil {
			logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
		}

	}

	logrus.Info("完成")
}

func contains(slice []string, item string) bool {
	for _, a := range slice {
		if a == item {
			return true
		}
	}
	return false
}

package Model

import (
	_ "database/sql"
	"fmt"
	_ "log"
	"strings"
	_ "time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

/**
 * 合服 大秦无双
 */
func Modelmjmc() {
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
		"sys_rumor",
		"sys_mails",
		"squad_role",
		"role_vientiane_star",
		"role_task_event",
		"role_talisman_pos",
		"role_ta_constellation",
		"role_oa_lta",
		"role_kf_world_dungeon_rank",
		"role_goods_use_num",
		"role_goods_cd",
		"role_cache",
		"merge_count",
		"local_auction_sys",
		"local_auction_goods",
		"kw_ta_dragon_point_score",
		"kw_invade_server_rank_info",
		"kf_group",
		"kf_final_war_info",
		"guild_war_rank",
		"guild_war_guild_info",
		"guild",
		"filter_word",
		"ban_info",
		"node_kf",
		"kf_info",
		"node",
		"kf_game_server",
		"local_achievement_info",
		"node_kf_connect",
		"game_info",
		"global_data",
		"operation_activity_schedule",
		"charge", //充值数据不合并
		"object_rank",
		"role_dungeon_rank",
		"local_arena_rank_info",
	}

	for _, fq := range fuquArr {
		fqdb := fq
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
			logrus.Infof("合并表: %s", table)
			if contains(noMerge, table) {
				continue
			}
			zqdb := zhuquId
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

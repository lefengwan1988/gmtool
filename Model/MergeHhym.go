package Model

import (
	_ "database/sql"
	"fmt"
	"github.com/cheggaaa/pb/v3"
	"log"
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
 * 合服 洪荒遗梦
 */
func ModelHhym() {
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
	//mSid := strings.Split(zhuquId, "_")[1]
	mSid, err := ExtractNumberFromGameString(zhuquId)
	if err != nil {
		fmt.Println("错误:", err)
	} else {
		fmt.Printf("从 %s 提取的数字: %d\n", zhuquId, mSid)
	}
	logrus.Infof("主区数据库: %s ", zhuquId)
	logrus.Infof("副区数据库: %s", fuqu)

	fuquArr := strings.Split(fuqu, ",")

	logrus.Warning("确认以上服务器将被合并,回车键继续")
	logrus.Warning("CTRL + C 可退出或中断程序")
	logrus.Warning("合服注意：先关闭要合并的区服，再执行合服命令")
	logrus.Warning("合服注意：合服前请先备份数据库，以免数据丢失")
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
		"crosscityinfo",
		"cloudbuy_activity",
		"childshopdynamic",
		"boyibattlerecord",
		"arriveskyecord",
		"crossteamfbcommon",
		"huntunitsfirstkill_all",
	}
	// 创建一个进度条
	total := len(fuquArr)
	bar := pb.New(total).SetTemplate(pb.Full)
	bar.Start()
	for _, fq := range fuquArr {
		fqdb := fq
		showtable := fmt.Sprintf("SHOW TABLES FROM `%s`", fqdb)
		rows, err := db.Query(showtable)
		if err != nil {
			logrus.Fatalf("查询表失败: %v", err)
		}

		// 获取表的数量
		tableCount := 0
		for rows.Next() {
			tableCount++
		}
		if err := rows.Err(); err != nil {
			logrus.Fatalf("处理结果集失败: %v", err)
		}

		// 重新查询表
		rows, err = db.Query(showtable)
		if err != nil {
			logrus.Fatalf("查询表失败: %v", err)
		}
		// 创建一个子进度条
		subBar := pb.New(tableCount).SetTemplate(pb.Full)
		subBar.Start()

		for rows.Next() {
			var table string
			err := rows.Scan(&table)
			if err != nil {
				logrus.Fatalf("扫描表失败: %v", err)
			}
			logrus.Infof("合并表: %s", table)
			if contains(noMerge, table) {
				// 更新子进度条
				subBar.Increment()
				continue
			}
			if table == "character" {
				maxId := getMaxId(db, table, "id", zhuquId, fqdb)
				UpdateIdSql := fmt.Sprintf("UPDATE `%s`.`%s` SET id = id + %d", fqdb, table, maxId)
				_, err = db.Exec(UpdateIdSql)
				if err != nil {
					logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
				} else {
					logrus.Info("更新角色表ID成功")
				}

			}
			if table == "equippartinfo" {
				eqMaxId := getMaxId(db, table, "auto", zhuquId, fqdb)
				UpdateIdSql := fmt.Sprintf("UPDATE `%s`.`%s` SET auto = auto + %d", fqdb, table, eqMaxId)
				_, err = db.Exec(UpdateIdSql)
				if err != nil {
					logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
				} else {
					logrus.Info("更新装备表ID成功")
				}
			}
			zqdb := zhuquId

			sql := fmt.Sprintf("REPLACE INTO `%s`.`%s` SELECT * FROM `%s`.`%s`", zqdb, table, fqdb, table)
			logrus.Infof("执行合并: %s", sql)
			_, err = db.Exec(sql)
			if err != nil {
				logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
			}

			// 更新子进度条
			subBar.Increment()
		}
		if err := rows.Err(); err != nil {
			logrus.Fatalf("处理结果集失败: %v", err)
		}
		// 完成子进度条
		subBar.Finish()
		fmt.Printf("数据库 %s 处理完成\n", fqdb)
		// 更新主进度条
		bar.Increment()
	}
	// 完成进度条
	bar.Finish()
	fmt.Println("所有数据库处理完成")
	logrus.Info("完成")
}
func getMaxId(db *sqlx.DB, table string, field string, db1 string, db2 string) int {
	// 获取两个表的最大id
	var maxID1, maxID2 int
	sql := fmt.Sprintf("SELECT MAX(%s) FROM `%s`.`%s`", field, db1, table)
	logrus.Infof("执行getMaxId: %s", sql)
	err := db.QueryRow(sql).Scan(&maxID1)
	if err != nil {
		log.Fatal(err)
	}
	sql = fmt.Sprintf("SELECT MAX(%s) FROM `%s`.`%s`", field, db2, table)
	logrus.Infof("执行getMaxId: %s", sql)
	err = db.QueryRow(sql).Scan(&maxID2)
	if err != nil {
		log.Fatal(err)
	}

	// 找出最大的id
	maxID := maxID1
	if maxID2 > maxID1 {
		maxID = maxID2
	}
	return maxID
}

package Model

import (
	_ "database/sql"
	"fmt"
	"github.com/cheggaaa/pb/v3"
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
 * 合服 百劫成仙
 */
func ModelBjcx() {
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
	mSid := extractNumber(zhuquId)
	if mSid == -1 {
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
		"serverlist",
		"rankdata",
		"maildata",
		"challengerankdata",
		"worldglobaldata",
		"sworn",
		"generalset",
		"gmcommand",
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
		sSid := extractNumber(fqdb)
		if sSid == -1 {
			fmt.Println("错误:", err)
		} else {
			fmt.Printf("从 %s 提取的数字: %d\n", fqdb, sSid)
		}
		UpdateIdSql := fmt.Sprintf("UPDATE `%s`.`charfulldata` SET worldid = %d where worldid= %d", zhuquId, mSid, sSid)
		_, err = db.Exec(UpdateIdSql)
		if err != nil {
			logrus.Errorf("执行SQL失败: %v", errors.WithStack(err))
		} else {
			logrus.Info("更新区服ID成功")
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

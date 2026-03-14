package config

import (
	"fmt"

	"github.com/spf13/viper"
)

// Config 应用配置
type Config struct {
	MySQL MySQLConfig `mapstructure:"MYSQL"`
	Merge MergeConfig `mapstructure:"config"`
}

// MySQLConfig MySQL配置
type MySQLConfig struct {
	Host     string `mapstructure:"mysqlhost"`
	User     string `mapstructure:"mysqluser"`
	Password string `mapstructure:"mysqlpasswd"`
}

// MergeConfig 合区配置
type MergeConfig struct {
	Prefix           string `mapstructure:"qianzhui"`
	MainServer       string `mapstructure:"zhuqu"`
	SubServers       string `mapstructure:"fuqu"`
	ServerPort       string `mapstructure:"serverPort"`
	ServerRemotePort string `mapstructure:"serverRemotePort"`
}

// Load 加载配置文件
func Load(configPath string) (*Config, error) {
	viper.SetConfigFile(configPath)

	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("读取配置文件失败: %v", err)
	}

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("解析配置文件失败: %v", err)
	}

	return &cfg, nil
}

// LoadDatabase 加载数据库配置
func LoadDatabase(configPath string) (*MySQLConfig, error) {
	viper.SetConfigFile(configPath)

	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("读取数据库配置文件失败: %v", err)
	}

	var mysqlCfg MySQLConfig
	if err := viper.UnmarshalKey("MYSQL", &mysqlCfg); err != nil {
		return nil, fmt.Errorf("解析数据库配置失败: %v", err)
	}

	return &mysqlCfg, nil
}

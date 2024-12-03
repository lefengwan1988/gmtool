package main

import (
	"bufio"
	"fmt"
	"gohequ/Model"
	"os"
	"strings"
)

func main() {

	fmt.Println("欢迎使用合区工具，请先确认你的游戏版本是否为最新版，否则可能合区失败。")
	fmt.Println("请选择合区工具：")
	fmt.Println("1：大秦无双")
	fmt.Println("2：主公别闹")
	fmt.Println("3：摸金迷城")
	fmt.Println("4：横扫三军")
	fmt.Println("PS:正规GM手游盒子招代理微信：clzpb2002,有好游戏也可以联系我们合作。")
	fmt.Println("当前版本：V1.0.1")
	//	logrus.Warning("GM手游盒子招手游代理QQ：463046993")
	// 读取用户输入
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("请输入数字 (1 或 2 ...上面有什么才能输入什么): ")
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)

	switch input {
	case "1":
		Model.ModelDqws()
	case "2":
		Model.ModelZmtx()
	case "3":
		Model.Modelmjmc()
	case "4":
		Model.ModelHssj()
	default:
		fmt.Println("无效输入")
	}
}

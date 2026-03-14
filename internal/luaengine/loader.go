package luaengine

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/sirupsen/logrus"
)

// SkillInfo Lua 技能信息
type SkillInfo struct {
	Name        string // 技能名称
	Description string // 技能描述
	FilePath    string // Lua 文件路径
}

// SkillLoader Lua 技能加载器
type SkillLoader struct {
	skillsDir string
	skills    map[string]*SkillInfo
}

// NewSkillLoader 创建技能加载器
func NewSkillLoader(skillsDir string) *SkillLoader {
	return &SkillLoader{
		skillsDir: skillsDir,
		skills:    make(map[string]*SkillInfo),
	}
}

// LoadAll 加载所有 Lua 技能
func (l *SkillLoader) LoadAll() error {
	// 检查目录是否存在
	if _, err := os.Stat(l.skillsDir); os.IsNotExist(err) {
		return fmt.Errorf("技能目录不存在: %s", l.skillsDir)
	}

	// 遍历目录中的所有 .lua 文件
	files, err := filepath.Glob(filepath.Join(l.skillsDir, "*.lua"))
	if err != nil {
		return fmt.Errorf("读取技能目录失败: %v", err)
	}

	if len(files) == 0 {
		return fmt.Errorf("未找到任何 Lua 技能脚本")
	}

	// 加载每个技能的元信息
	for _, file := range files {
		if err := l.loadSkillInfo(file); err != nil {
			logrus.Warnf("加载技能失败 %s: %v", file, err)
			continue
		}
	}

	logrus.Infof("成功加载 %d 个技能", len(l.skills))
	return nil
}

// loadSkillInfo 加载单个技能的信息
func (l *SkillLoader) loadSkillInfo(filepath string) error {
	// 读取文件内容
	content, err := os.ReadFile(filepath)
	if err != nil {
		return err
	}

	// 解析技能信息（从注释中提取）
	lines := strings.Split(string(content), "\n")
	var name, description string

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "-- @name:") {
			name = strings.TrimSpace(strings.TrimPrefix(line, "-- @name:"))
		} else if strings.HasPrefix(line, "-- @description:") {
			description = strings.TrimSpace(strings.TrimPrefix(line, "-- @description:"))
		}
	}

	if name == "" {
		return fmt.Errorf("技能缺少 @name 标注")
	}

	skill := &SkillInfo{
		Name:        name,
		Description: description,
		FilePath:    filepath,
	}

	l.skills[name] = skill
	logrus.Debugf("加载技能: %s (%s)", name, filepath)
	return nil
}

// GetSkill 获取技能信息
func (l *SkillLoader) GetSkill(name string) (*SkillInfo, error) {
	skill, exists := l.skills[name]
	if !exists {
		return nil, fmt.Errorf("技能不存在: %s", name)
	}
	return skill, nil
}

// ListSkills 列出所有技能
func (l *SkillLoader) ListSkills() []*SkillInfo {
	skills := make([]*SkillInfo, 0, len(l.skills))
	for _, skill := range l.skills {
		skills = append(skills, skill)
	}
	return skills
}


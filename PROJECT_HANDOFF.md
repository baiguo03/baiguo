# 李子 iOS 刷题项目交接说明

更新时间：2026-06-28

## 项目概览

- 项目名：李子
- 类型：原生 iOS UIKit App
- 最低系统：iOS 16.0
- iOS 工程：`ios/QuizTool/QuizTool.xcodeproj`
- Scheme：`QuizTool`
- Bundle ID：`app.calcite4884.lyra3161`
- 云构建：Codemagic，分支 `master`
- App 名称：李子，界面不再显示 V11 / 云题 / 刷题工具等旧名称

## 主要目录

- `ios/QuizTool/QuizTool/ViewController.swift`：App 主界面、题库、练习、导入、编辑、AI 校验、题号导航。
- `ios/QuizTool/QuizTool/QuestionParser.swift`：本地题目解析器。
- `backend/lizi_ai_backend.py`：本地/服务器 AI 解析后端。
- `backend/run_local_backend.ps1`：Windows 本地启动后端脚本。
- `tools/check_native_ios.py`：iOS 关键功能结构检查。
- `tools/check_question_parser.py`：题目解析器回归检查。
- `tools/check_app_files.py`：App 文件完整性检查。
- `tools/check_backend.py`：后端结构检查。
- `codemagic.yaml`：Codemagic iOS IPA 构建配置。

## 当前架构

推荐架构是：

`iPhone App -> 本地或云端后端 -> AI 模型`

App 可以联网。API URL 应填写电脑或服务器的局域网/公网地址，例如：

```text
http://172.20.10.3:8787/api/parse-questions
```

注意不要写成 `http://172.20.10.3ip：8787/...`。手机里的 `127.0.0.1` 是手机自己，不能访问电脑后端。

本地后端启动示例：

```powershell
cd C:\Users\liu\Documents\Codex\2026-06-27\ba-2\backend
$env:LIZI_AI_KEY="你的新密钥"
powershell -ExecutionPolicy Bypass -File .\run_local_backend.ps1
```

手机 Safari 可先访问：

```text
http://电脑局域网IP:8787/health
```

能打开说明 App 也能连。若打不开，优先检查电脑 IP、同一网络、防火墙 8787 端口。

## 后端存题建议

把题库存在后端对 AI 解析、OCR、备份同步会更好，因为可以集中处理大文本、保留 AI 任务日志、避免密钥暴露。但普通刷题页面不建议完全依赖后端实时加载，否则没网或网络慢时体验会差。

推荐下一步：手机本地仍保存题库用于秒开和离线刷题，后端负责 AI 解析、校验、OCR、备份同步；后端处理完再把干净题库回写到手机。

## Codex 接入说明

当前 App 不是直接接 Codex，而是接 `backend/lizi_ai_backend.py`，后端再调用配置的 AI 模型。

如果后续要接 Codex，建议做成：

`App -> 本机/服务器中转后端 -> Codex CLI/服务进程 -> 返回 JSON -> App`

这需要单独做一个稳定的任务队列和超时机制，不建议直接在 App 里硬接 Codex。

## 当前功能

- 题库导入：粘贴、TXT/PDF 文件、图片 OCR 入口。
- 文件/图片导入后先回填到导入文本框，不直接建题库，方便选择普通解析或 AI 辅助解析。
- 题型：单选、多选、判断、填空、简答、配伍、案例分析。
- 练习：顺序练习、随机练习、错题练习，入口由“我的”里的练习模式开关控制。
- 答题：左右滑切题、题号导航、答题记录保存、错题显示正确答案。
- 题库：可全删、左滑删除、长按切换题库。
- 编辑：搜索题目、编辑题干/选项/答案/解析/题型、AI 校验预览、单题修正前后对比。

## 最近关键修复

- AI 辅助导入不再盲信 AI 结果：如果 AI 返回题数少于本地解析 90%，保留本地解析，避免少题。
- AI 校验不再整体替换题库：按原题逐题合并，选择题优先保留原选项，避免选项丢失。
- AI 返回 `mode: validate`、题库名、来源等元信息会被过滤，不再生成假题。
- AI 返回 `[填空题][单选题]` 等标签会从题干清除，并重新归一化题型。
- 多选题归一化规则收紧：明确多选且答案超过一个才按多选；答案只有一个优先单选。
- 案例/病例/问题/依据/并发症/分析类题目在无明确单选/多选标记时优先按案例分析题处理，避免被 A/B/C/D 误伤。
- 简答/填空/案例题不再硬造 A 选项。
- 弱解析过滤：类似“正确选项是 X”“参考答案 X”不再当正式解析展示，会提示暂无有效解析。
- 后端 prompt 已要求解析必须回答题目本身，说明答案为什么成立。
- 题号导航改为分批渲染，首屏 80 题，点“显示更多”继续加载，减少打开卡顿。
- 题号搜索改为手动触发，避免输入时每个字符都重绘。
- 键盘换行会收起键盘，导入和编辑页可正常点 AI 按钮。

## 已知风险

- PDF 排版、扫描质量、题号粘连、答案汇总格式混乱仍会影响解析。
- AI 校验/辅助导入会检查题型、选项、答案和解析，但不能保证医学答案 100% 正确，应用前仍需看预览。
- “案例题长得像选择题”的文档比较难完全自动判断，当前规则优先保证不把案例/简答误判成多选。
- 当前后端是本地 HTTP 服务，适合测试。长期用建议迁到云服务器，并加鉴权和 HTTPS。
- 聊天中暴露过 API Key，建议去服务商后台作废并换新。

## 参考开源方向

- `mindskip/xzs`：开源在线考试系统，可参考题型数据结构和后台管理思路。
- `weiruo/choice-parser`：自由文本选择题解析器，可参考题干/选项切分思路。

这些项目不能直接解决当前医学 PDF 乱序解析，但可以作为后续重构解析器的数据结构参考。

## 常用验证命令

```powershell
cd C:\Users\liu\Documents\Codex\2026-06-27\ba-2
& 'C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/check_native_ios.py
& 'C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/check_question_parser.py
& 'C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/check_app_files.py
& 'C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/check_backend.py
& 'C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -m py_compile backend/lizi_ai_backend.py
& 'C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe' diff --check
```

## 新对话接手提示

可以直接说：

```text
请先阅读 PROJECT_HANDOFF.md，然后继续修复李子 iOS 项目。重点检查 ViewController.swift、QuestionParser.swift、backend/lizi_ai_backend.py 和 tools 下的回归检查。
```

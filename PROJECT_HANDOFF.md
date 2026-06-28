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
- 最新已推送提交：`17163f8 Fix AI validation merge and preview flow`

## 主要目录

- `ios/QuizTool/QuizTool/ViewController.swift`：主要 UI、题库、导入、练习、AI 校验逻辑。
- `ios/QuizTool/QuizTool/QuestionParser.swift`：本地题目解析器。
- `backend/lizi_ai_backend.py`：本地/服务器 AI 解析后端。
- `backend/run_local_backend.ps1`：Windows 本地启动后端脚本。
- `backend/package_backend.ps1`：后端打包脚本。
- `tools/check_native_ios.py`：iOS 代码结构和关键功能检查。
- `tools/check_question_parser.py`：题目解析器回归检查。
- `tools/check_app_files.py`：App 文件完整性检查。
- `tools/check_backend.py`：后端接口结构检查。
- `codemagic.yaml`：Codemagic 云构建配置。

## 当前功能状态

- 题库导入：支持粘贴、TXT/PDF 文件、图片 OCR 入口。
- 文件/图片导入后会先回填到导入文本框，用户检查后再选择普通解析或 AI 辅助解析。
- 题型：单选、多选、判断、填空、简答/案例类文本题。
- 练习：顺序练习、随机练习、错题练习入口由设置开关控制。
- 答题：支持左右滑切题、题号导航、答题记录保存、答错显示正确答案和解析。
- 题库：支持全删、左滑删除、长按题库切换/操作。
- 编辑：支持题目搜索、题干/选项/答案/解析/题型编辑并保存。
- AI：支持 AI 辅助导入、AI 校验题库、校验预览、单题修正前后对比。

## AI 后端说明

App 不直接接 Codex 会话。建议架构：

`iPhone App -> 本地或服务器后端 -> OpenAI/其他 AI 模型`

本地后端启动示例：

```powershell
cd C:\Users\liu\Documents\Codex\2026-06-27\ba-2\backend
$env:LIZI_AI_KEY="你的新密钥"
powershell -ExecutionPolicy Bypass -File .\run_local_backend.ps1
```

App 里的 API URL 示例：

```text
http://你的电脑局域网IP:8787/api/parse-questions
```

注意：不要把密钥写进 App 源码或提交到仓库。之前聊天里暴露过一个密钥，建议在服务商后台作废并换新。

## 最近关键修复记录

- 修复 IPA 空白：改为原生 iOS WebView/资源方式后继续演进为 UIKit 页面。
- 修复 Codemagic 签名：使用 profile 拷贝和 `$HOME/export_options.plist` 导出。
- 修复 App 名称和图标：应用名改为“李子”，去掉 “刷题工具/V11” 等字样。
- 优化 iOS 风格 UI：底部栏、列表、卡片、搜索、设置页、题库详情。
- 修复深色模式发白：强制浅色显示，避免白字白底。
- 修复题库大退后丢失：加入本地持久化。
- 修复文件导入直接完成：现在先回填导入框，避免无法选择 AI 解析。
- 修复编辑搜索即时触发：改为输入完成后点搜索/回车。
- 修复编辑保存失败：保存后写回题库并持久化。
- 修复 AI 校验跳回题库：校验中停留当前页，成功后进入预览。
- 修复 AI 校验无反馈：按钮显示“AI 校验中”并带转圈。
- 修复 AI 校验多出 `mode: validate` 等假题：App 端过滤元信息，校验正文不再混入 metadata。
- 修复 AI 校验应用后选项丢失：AI 返回只作为修正建议，按原题逐题合并，选择题保留原选项。
- 新增 AI 校验预览单题详情：可点击预览行查看“修正后/原题”对比。

## 已知风险和后续建议

- 文档解析仍可能受 PDF 排版、扫描质量、题目编号混乱影响。AI 辅助可降低出错，但不能保证 100%。
- 简答题/案例题如果原文答案区混在题干里，仍需要靠 AI 校验或人工编辑修正。
- 当前后端是简单 HTTP 服务，适合本地测试；正式长期使用建议迁移到云服务器，并加访问鉴权。
- API Key 建议只放服务器环境变量，App 只保存后端地址。
- 后续可增加：AI 答疑页面、导入前预览差异、批量修正选择、题库导出备份。

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

新对话可以直接说：

```text
请先阅读 PROJECT_HANDOFF.md，然后继续修复李子 iOS 项目。重点检查 ViewController.swift、QuestionParser.swift、backend/lizi_ai_backend.py 和 tools 下的回归检查。
```

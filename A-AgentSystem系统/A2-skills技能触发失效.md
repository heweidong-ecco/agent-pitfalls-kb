# skills 技能触发失效 —— 为什么"装了 skills 却从不调用"

> **篇 ID:`A2`** · 区:`A-AgentSystem系统`(严重 · 关乎 Agent/harness/AI 系统本身)
> 来源:某评测门项目 · 2026-09-11 · 阶段3→4 交接(业务方追问「你处理问题和开发时有没有用 skills,还是直接推理跳过了?」,当场对会话 transcript 做工具调用统计)
> 编号:本库规则编号 = `<篇ID>-R<n>`(篇内连续,见 README §6)
> 体例与约束见同目录上级的 `README.md`

---

## 0. 怎么用本文(给读取本文的 Agent)

- 如果你在**某个项目里工作**:执行任务前先过 **`A2-R2`(入口)+ `A2-R3`(对应表)**;收尾时过 **`A2-R4`(哨兵)**。
- 如果你是**Kit / 平台维护者**:照 **§7 落地清单**改母体 —— 这是**会随派生项目数量放大**的缺陷。
- 如果你只是想判断"我这边有没有这个病":用 **§3 的三层自检表 + §10 的验证方式**。
- 本篇是 **`A1`** 篇(纪律落地三层结构法)的同类问题在「技能」上的第二次发作;
  **门禁 / hook 自身的生命周期**(它会上线、会腐烂、会被发现、会锚错地方)另见 **`A4`** 篇。

---

## 1. 一句话结论

> **装了 skills 不等于会用 skills。**
> skill 的**可用性**由「安装」决定,**使用率**由「触发结构」决定 —— 缺触发器时,**再全的 skill 库也等于零**。
>
> 修复不是"提醒自己记得用",而是补齐三层:
> **入口(先过 `using-superpowers`)→ 对应表(工作类型 → **必须调用**,写进每会话必读处)→ 硬门(CI 可检测的痕迹)**。

---

## 2. 现场:可复核的实测数据

业务方在阶段4 开工前追问:「**你处理问题和开发时有没有用 skills,还是直接推理跳过了?**」

核实方式(可复现):对本会话 transcript 做工具调用统计 ——

```
Skill 调用:2 次   ← 只有 grilling 与 update-config
Bash: 205 · Edit: 146 · Read: 45 · Write: 27 · Agent: 8
```

**2 次里,`update-config` 还是该 skill 的触发条件强制命中**(改 `settings.json`),`grilling` 是项目接续锚明文要求。**其余全部裸推理。**

### 漏掉的代价(全是真事,不是假设)

| 该用的 skill | 没用的后果(本会话实测) |
|---|---|
| `gate-review` | 阶段3 门禁**由 AI 自写对账表**就交业务方判 PASS。补跑该 skill 后**抓到 2 处漏判** —— 所用工作流的**阶段卡**还列了**产出物清单**,AI 只对了"门禁 7 条",漏了《API 文档》《部署配置》两项(项目根连 README 都没有) |
| `test-driven-development` | 测试是"写完补"的,不是"驱动"的;异常路径覆盖不足 |
| `留痕-checks` | 约 **30 次提交**,一次没跑 |
| `verification-before-completion` | "完成/通过"由 AI 自定标准自评 |
| `requesting-code-review` | **全程零独立评审** —— 一个会话 1508 行改动,自己写、自己验、自己提交 |

### 对照实验(同一套体系内,最有说服力)

| 机制 | 承载方式 | 实际执行 |
|---|---|---|
| Kit 缺陷反馈 | 文字(在锚点里)**+ hook** | ✅ 每轮都执行 |
| 「失败即补 case」 | **只有文字**,且不在锚点 | ❌ 整个阶段**零执行** |
| **skills 使用** | **只有一句笼统的"动手前查 skills 是否命中"** | ❌ **2/205** |

> **规律一致:有结构 → 执行;只有文字 → 漏。** 且漏了**没有任何提示**。

---

## 3. 根因:三层全空

| 层 | 应有的 | 实际(该项目 + 母体 Kit) |
|---|---|---|
| **锚点** | 「工作类型 → **必须调用**哪个 skill」的**可执行对应表**,写进**每会话必读**的那个文件 | 只有一句「动手前查 skills **是否命中**」—— 无对应表、无"必须"措辞、无触发条件 |
| **触发** | 入口触发器(如 `using-superpowers`,要求"任何回应前先确认 skill") | **母体全库 grep `using-superpowers` 命中 0** —— 它从未进入 Kit 任何文档;项目级也没装 |
| **硬门** | 没调用会有可检测的痕迹 / 报错 | **无**。写了代码没写测试,CI 不会说什么 |

### 更隐蔽的一层:Kit 的"外部依赖"假设

Kit 把 **superpowers 整组(14 个 skill)当"编码/测试执行引擎"**,但设计成**外部依赖**:

- `skills-router.md` 把来源写成「obra(插件/拷贝)」
- `初始化-runbook.md` 原文:`# superpowers 插件在用户级(~/.claude),无需拷入项目`
- **但 Kit 的"装 skills"步骤只拷自己的 5 个,没有任何一步预检 superpowers 是否已装**
- 项目侧实测:该项目 `.claude/skills/` 只有 4 个,**连 `kit-feedback` 都漏装了**

→ **一个"核心引擎",既不确定在不在、也不保证会被调用。**

---

## 4. 规则

> 每条:`规则(通用)` → `反例/实证` → `正例(怎么做到)`。
> 本篇的规则全部由原"策略 + 清单"式文本**新编**为编号规则(见文末「变更记录」)。
> 与「门禁 / hook 自身生命周期」相关的规则见 **`A4`** 篇;与「一条纪律如何落地三层」的总原则见 **`A1`** 篇。

### `A2-R1` · 装了 skills ≠ 会用 skills —— 「可用性」由安装决定,「使用率」由触发结构决定

**规则**:判断一个 skill 库有没有用,不能只看"装没装",要看**触发结构**(入口 / 对应表 / 硬门)是否存在。
缺触发器时,再全的 skill 库也等于零。修复方式不是"提醒自己记得用",而是**补三层**。

**反例(实例)**:见 §2 —— 实测 `Skill 2 次 / Bash 205 · Edit 146`,且那 2 次是被触发条件硬命中的。
漏用代价 5 条(含"阶段门由 AI 自写对账表就判 PASS,补跑 skill 后抓到 2 处漏判")见 §2 的代价表。

**正例(怎么做到)**:补齐三层 —— **入口(`A2-R2`)→ 对应表(`A2-R3`)→ 硬门(`A2-R5`)**;
触发层哨兵见 `A2-R4`,门禁左移见 `A2-R6`。验收用 `A2-R12` 的三问。

---

### `A2-R2` · 任务开始前,先加载「入口触发器」—— 它是让对应表被想起来的开关

**规则**:对应表**不会自己浮现**。必须先过一个"任何回应前先确认 skill"的入口触发器;
没有它,表再全也想不起来。

**反例(实例)**:母体全库 grep 入口触发器 `using-superpowers` **命中 0** —— 它从未进入 Kit 任何文档;
项目级也没装。⇒ 对应表实际从未被想起(§3 的"触发层"全空)。

**正例(怎么做到)**:把这一步写死在一处(示例):

```
开工前先调用:using-superpowers
```

> ⚠️ **边界(如实标注)**:入口的**自触发是概率性的,不是确定性保证** —— 同一机制在不同样本上给出
> 不同行为(实测 1/2)。「装了就会用」不成立,**不能把它当硬约束**。证据与复测见 `A4` 篇。

---

### `A2-R3` · 把「工作类型 → 必须调用哪个 skill」写成**按阶段分组**的两列表,放进**每会话必读**的文件

**规则**:① 必须是**对应表**(枚举到具体 skill),不是"查一下是否命中"这类笼统措辞;
② 措辞必须是「**命中即必须调用**」—— 写「可以调用」「建议使用」**都等于没写**;
③ 表的**分组 = 阶段**(立项 / 规划 / 执行 / 收集 / 门禁 / 工具元),这样**将来新增 skill 时,才知道该插到哪一行**(而不是另起一张表);
④ 放的位置是**每会话必读**的那个文件(通常是 `CLAUDE.md` / `AGENTS.md` / 系统提示),**不是**某个角落的 README。

**反例(实例)**:原文只有一句「动手前查 skills **是否命中**」—— 无对应表、无"必须"措辞、无触发条件
⇒ 实测 **2/205**(§2 对照实验表)。

**正例(怎么做到)**:

| 阶段 | 触发场景 | **必须调用** |
|---|---|---|
| **入口** | **任何任务开始前** | **`using-superpowers`**(先过它,否则下表不会被想起) |
| 立项/发散 | 需求不清、要发散方案 | `brainstorming` |
| 立项 | 开新 Agent 项目 | `new-project-launch` |
| 规划 | 造/设计/规划 Agent 主流程 | `agent-system-creator`(主持流程) |
| 规划 | 定调、优先级、方案压测 | `grilling` |
| 规划 | 写实施计划 / 执行计划 | `writing-plans` / `executing-plans` |
| 隔离 | 需要隔离工作区 | `using-git-worktrees` |
| 执行 | **写或改实现代码** | **`test-driven-development`** |
| 执行 | 拆成多个独立任务并行 | `dispatching-parallel-agents` |
| 执行 | 每任务派独立 subagent 落地 | `subagent-driven-development` |
| 排查 | 遇 bug / 测试失败 / 行为异常 | `systematic-debugging` |
| 收尾 | **声称"完成 / 修好 / 通过"** | **`verification-before-completion`** |
| 收尾 | 请人评审我的代码 | `requesting-code-review` |
| 收尾 | 收到评审意见、要落实 | `receiving-code-review` |
| 收尾 | 分支收尾/合并/清理 | `finishing-a-development-branch` |
| 门禁 | **阶段门验收 / gate 判定** | **`gate-review`**(卡门;结论=建议,终裁=业务方) |
| 门禁 | **每次 commit / PR 前** | **`留痕-checks`** |
| 工具/元 | 改 `settings.json` | `update-config` |
| 工具/元 | 新建/修改 **skill 本身** | `writing-skills` |
| 工具/元 | Kit 自身缺陷 | `kit-feedback` |

> 表里的 skill 名是**某一次实现的实例**;要照做的是**表的结构与位置**与上面四条要求。

---

### `A2-R4` · 触发层:加一个**带判据**的收尾哨兵(单行、opt-in)

**规则**:在"这件事该做却没做"的**时机**上放一个提醒。要点:
① **单行,不刷屏**;② **必须有判据** —— 无条件提醒会变成噪音被忽略;③ 提醒要**给出下一步动作**(去哪、做什么),不只是复述纪律。

**反例(实例)**:无条件提醒 → "三天后所有人无感";本条的判据取"**工作区确实有改动**"(说明本轮做了事),
避免静默轮次刷屏。

**正例(怎么做到)**:**仅当工作区有改动时**输出一行(示例,本仓实现:`skill-sentinel.sh`,放 `.claude/hooks/`):

```sh
#!/bin/sh
# skill-sentinel:节点收尾提醒「该用的 skill 都用了吗」(防漏,不做推理)。
# opt-in:设 SKILL_SENTINEL=1 才生效(注册处内联);可随时在 settings.json 移除。
[ "$SKILL_SENTINEL" = "1" ] || exit 0

cd "$(dirname "$0")/../.." || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# 仅当工作区确实有改动(说明本轮做了事)才提醒,避免静默轮次刷屏
git status --porcelain 2>/dev/null | grep -q . || exit 0

printf 'skills: 本轮命中下表了吗(命中即【必须调用】)?'
printf ' 写码→test-driven-development · 称完成→verification-before-completion ·'
printf ' 阶段门→gate-review · 提交前→留痕-checks · 排查故障→systematic-debugging\n'
exit 0
```

注册(`.claude/settings.json`):

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [
        { "type": "command", "command": "SKILL_SENTINEL=1 .claude/hooks/skill-sentinel.sh" }
      ]}
    ]
  }
}
```

---

### `A2-R5` · 加硬门,并**逐条如实标注强度**;做不到的**如实标成软的**

**规则**:L1/L2 会被忽略(人 / Agent 都会疲劳),**只有"红灯"和"提交被拒"不会** ⇒ 必须补硬门。
但**标注强度时必须诚实**:把"警告"写在「硬门」标题下就是**过度声明** —— 那正是本篇批评的毛病;
明确做不到的,如实写成"做不到"并列理由。

**反例(实例)**:本篇原先把 CI 的 `::warning` 写在「硬门」标题下,属**过度声明**;
另有一处把"防腐测试已落地"标成 ✅ 而实际**不存在**(见 §7 落地清单 4d 的 ⚠️ 更正)。

**正例(怎么做到)**:逐条标强度后再写结论(强度表见下)。
**✅ 做到「硬」(可机器检测,躲不掉)**:

- 新增 skill 未登记到路由/锚点 → **CI fail**
- 改了实现代码却无测试改动 → **本地提交被拒** + **CI fail**(可用 `[no-test]` 显式豁免)
- **改了实现代码,但本会话没调用过该调用的 skill → 本地提交被拒**(可用 `[no-skill]` 豁免)← **新增**

**❌ 确实做不到**:

| 目标 | 为什么 |
|---|---|
| 自动判定"**这件工作该用哪个 skill**" | 需要语义判断,规则引擎给不出 |
| 区分"**先写测试**"还是"**后补测试**" | git 只有"改没改 tests",没有时序 |

**强度表**(每加一个机制就补一行,并如实填强度):

| 检查 | 位置 | 判据 | **强度** |
|---|---|---|---|
| **实现先行守卫(左移)** | `.claude/hooks/`(PreToolUse `Edit\|Write`) | 要改实现文件、而工作区尚无测试改动 → **先问一句**(`permissionDecision=ask`) | **中**(询问式,不硬拦 —— 见 `A2-R6`) |
| **本地 `commit-msg`** | `.githooks/`(需 `git config core.hooksPath .githooks`) | 暂存了实现文件却无测试 → **拒绝提交**;豁免须在提交信息写 `[no-test]` | **硬**(提交时就拦,可 `--no-verify` 绕过但须说明) |
| **skill 痕迹门** | 同上 | 改了实现代码,但本会话 **transcript 里没有该调用的 skill** → **拒绝提交**;豁免 `[no-skill]` | **硬**(由 hook 从 transcript 抽取事实,非自述 —— 见 `A2-R9`) |
| **TDD 痕迹** | CI | 改了实现目录却无 `tests/` 改动 → **fail**(非 warning);显式豁免 | **硬** |
| **skill 覆盖检查** | CI | 已安装 skill 未登记到路由/锚点文档 → **fail** | **硬** |
| 契约测试 | CI | `pytest` 必须绿 | 硬 |
| 失败回灌 | CI | 改了评测集/阈值却无**失败用例库**或**过程复盘** → **fail** | 硬 |
| **SessionStart 注入** | `.claude/hooks/` | 每会话把入口+表**注入上下文** | **中**(进上下文 ≠ 照做) |
| **Stop 哨兵** | `.claude/hooks/` | 有改动时单行提醒 | **软**(可忽略,会疲劳) |
| 对应表(`A2-R3`) | `CLAUDE.md` | 文字 | **软**(靠"看到并照做") |

---

### `A2-R6` · 门禁要**左移**,不能只留"提交时"

**规则**:只在**最后提交**时拦的门,对长任务是**滞后门** —— 它拦不住过程,只能事后"改装"。
必须把门**左移到"动手那一刻"**(改实现文件时先问一句)。

**反例(实例)**:`commit-msg` 只在最后提交时拦。对长任务,这意味着:
1. 实现决策早已做完 → 事后补测试只是**改装**,不是 TDD;
2. 任务中途结束 / 被打断 → **没有任何门触发过**,纪律被无声违反;
3. 综上 —— **"中间全白费"**。

**正例(怎么做到)**:`PreToolUse(Edit|Write)` 的左移门 —— 要改实现文件、而工作区/暂存区尚无测试改动时,
`permissionDecision=**ask**`(**先问,不硬拦**,把决定权提前给人)。注册进 `.claude/settings.json` 的 `PreToolUse`。

> ⚠️ **左移门本身也会腐烂、也会锚错地方** —— 它的两个真实缺陷与修法见 **`A4`** 篇。

---

### `A2-R7` · 新增 skill 必须【同时】做三件事,并由 CI 的**元机制**校验

**规则**:枚举式硬编码的对应表**不会自动更新** —— 谁加了 skill 没登记,**同一个漏洞会再来一次**。
解法是把「新增 skill 必须同时登记」变成**可检验的硬门**(CI 里跑的校验脚本),而不是靠自觉。

配套的**三件事**(缺一即触发规约失效):
① 在技能路由文档(`skills-router.md`)登记「何时用」;
② 在每会话必读文件的对应表里补一行(**插到对应阶段**);
③ 若要强制,补**触发**(hook)或**门禁**(CI 检查)。

**反例(实例)**:对应表是**枚举式硬编码**;Kit 以后新增一个 skill,这张表不会自动更新 ⇒ 漏洞复发。

**正例(怎么做到)**:**元机制校验脚本**(示例,本仓实现:`tools/check-skill-coverage.sh`):

```sh
#!/bin/sh
# check-skill-coverage —— 确保「已安装的 skill」都被「路由/锚点文档」覆盖
# 用法: check-skill-coverage.sh <skills_dir>... -- <doc_file>...
#   母体:      tools/check-skill-coverage.sh skills -- skills-router.md scaffold/agent/CLAUDE.md
#   派生项目:  tools/check-skill-coverage.sh .claude/skills -- CLAUDE.md
# 退出码: 0 全覆盖 / 1 有未登记 skill / 2 用法错误
set -u
usage() { echo "用法: $0 <skills_dir>... -- <doc_file>..." >&2; exit 2; }
[ "$#" -ge 3 ] || usage

SKILL_DIRS=""; DOC_FILES=""; parsing_skills=1
for arg in "$@"; do
  if [ "$arg" = "--" ]; then parsing_skills=0; continue; fi
  if [ "$parsing_skills" = "1" ]; then SKILL_DIRS="$SKILL_DIRS $arg"; else DOC_FILES="$DOC_FILES $arg"; fi
done
[ -n "$SKILL_DIRS" ] && [ -n "$DOC_FILES" ] || usage

NAMES=""
for d in $SKILL_DIRS; do
  [ -d "$d" ] || { echo "check-skill-coverage: 目录不存在: $d" >&2; exit 2; }
  for p in "$d"/*/; do
    [ -f "$p/SKILL.md" ] || continue
    NAMES="$NAMES $(basename "$p")"
  done
done
for f in $DOC_FILES; do
  [ -f "$f" ] || { echo "check-skill-coverage: 文档不存在: $f" >&2; exit 2; }
done

missing=""; count=0
for n in $NAMES; do
  count=$((count + 1)); found=0
  for f in $DOC_FILES; do grep -q -- "$n" "$f" 2>/dev/null && { found=1; break; }; done
  [ "$found" = "1" ] || missing="$missing $n"
done

entry_ok=1
for f in $DOC_FILES; do grep -q -- "using-superpowers" "$f" 2>/dev/null && entry_ok=0; done
[ "$entry_ok" = "1" ] && echo "::warning::文档未提及入口触发器 using-superpowers(它是让对应表被想起的开关)。"

if [ -n "$missing" ]; then
  echo "::error::以下 skill 已安装,但未在任何路由/锚点文档中登记:"
  for n in $missing; do echo "::error::  - $n"; done
  echo "::error::新增 skill 必须【同时】做三件事(否则触发规约失效):"
  echo "::error::  ① 在 skills-router.md 登记「何时用」;"
  echo "::error::  ② 在 CLAUDE.md 的「技能对应表」补一行(插到对应阶段);"
  echo "::error::  ③ 若要强制,补触发(hook)或门禁(CI 检查)。"
  exit 1
fi
echo "✅ skill 覆盖检查通过:$count 个已安装 skill,全部已在路由/锚点文档登记"
exit 0
```

**实测(4 个方向都验过)**:正常两处通过;造一个未登记的新 skill → `exit 1` 并逐条列出;缺入口触发器 → 额外告警。

> **这条元机制才是本篇的真正交付物**:它让 `A2-R3` 的表**不会随时间失效** —— 谁加了 skill 没登记,**CI 当场变红**。

---

### `A2-R8` · 策略文档必须带**可运行产物**,否则它自己就是"只有文字"

**规则**:写"应该加结构"的策略时,必须同时给出**可复制/可运行的实现**;否则该策略本身
就落入它批评的类别 —— 一条没有结构的文字纪律。

**反例(实例)**:只有"要加硬门""要有哨兵"这类描述,没有脚本 ⇒ 读者只能自己发挥 ⇒ 落地形状千奇百怪。

**正例(怎么做到)**:本文 §6 即为五份可直接复制的实现(哨兵 / CI 片段 / 覆盖校验 / 本地硬门 / 会话注入)。

---

### `A2-R9` · 在下"**做不到**"的结论前,先验证一次

**规则**:凡要写下"这不可能检测 / 这做不到"的结论,必须先做一次**最小验证**(如 5 分钟 grep 一次
真实数据),再落笔。**"想当然地断定做不到"与本篇批评的"过度声明"是一体两面:都没有验证就下结论。**

**反例(实例)**:**原判断**「skill 调用不落 git,CI 看不见 → 无法强制。」
**事实**:CI 确实看不见,但 —— **hook 能看见**。

> **Skill 调用落在本机 session transcript 里**:
> - 主会话:`~/.claude/projects/<sanitized-cwd>/<session_id>.jsonl`
> - **子 Agent**:`<session_dir>/tasks/<agent_id>.output`(同样是 JSONL)
>
> 一个 Stop hook(示例,本仓实现:`skill-trace.sh`)就能把它抽成仓库内的机器可读 trace
> (示例路径:`.claude/traces/latest.json`),于是本地 `commit-msg` 可以**校验 skill 是否真的被调用过**。

**实测**(该项目):trace 读出 `skill_calls: 4`,`skills: gate-review(1) grilling(1) requesting-code-review(1) update-config(1)`
—— **与本会话真实调用逐个对上**,并扫到 25 个子 Agent transcript。

**教训(值得单列)**:我犯的是**同一类毛病** —— **"想当然地断定做不到"**。
正确的做法本该是:先花 5 分钟 grep 一次 transcript,再写"做不到"。

---

### `A2-R10` · 能**自动采集既有机器痕迹**的,就不要靠"自述"

**规则**:把"证明你做了功课"从**请求**变成**强制**时,优先选**从既有痕迹自动抽取**的路径,
而不是**让 Agent 自己填**。**判断标准**:一份"交付物"如果**需要 Agent 主动填写**才算数,
那它迟早会退化成八股;如果**能从既有的机器痕迹里抽取**,才是硬的。

**反例(实例)**:曾经的破法设想 —— "要求每个节点在提交信息里记一行『本轮用了哪些 skill』" —— **仍不可取**:
靠人填 = 八股。

**正例(怎么做到)**:从 transcript **自动抽取**不一样:它**不需要任何人多写一个字**,是**事实的采集**而非**自述**。
这就是"可检测"与"靠自述"的分界。(本条与 `A3-R3` 同源。)

---

### `A2-R11` · 可强制的边界:**能落 git / 文件系统痕迹的,才能强制**

**规则**:**凡是能落 git / 文件系统痕迹的,才能强制**;**只发生在会话内的(该不该用某个 skill),当前手段强制不了。**
⇒ 把能做成硬的做成硬,把软的**如实标成软的**(`A2-R5`),**且在下"做不到"的结论前,先验证一次**(`A2-R9`)。

**反例(实例)**:见 §4 强度表 —— "自动判定这件工作该用哪个 skill"需要语义判断,规则引擎给不出。

**正例(怎么做到)**:需要语义判断的部分留在软层(对应表 + 哨兵),其余全部下沉到硬门;
软硬边界在强度表里**逐条写明**,不留含糊。

---

### `A2-R12` · 落地验收:**三问**(与 `A1` 篇同款)

**规则**:一条纪律 / 一个机制落没落地,问三个问题,任一答"否"即**还没落地**:

1. **看得见吗?** 一个从没参与过的新 Agent,只读锚点,会知道"写码前必须调用该调用的 skill"吗?
2. **会被想起来吗?** 写码 / 提交 / 过阶段门的那一刻,有什么会提醒?
3. **漏了会怎样?** 漏了**有没有东西会红**?若"什么都不会发生"→ **还没落地**。

**反例(实例)**:「动手前查 skills 是否命中」三问全否 ⇒ 实测 2/205。

**正例(怎么做到)**:三问逐条对应到 `A2-R2`(看得见)、`A2-R4`(想起来)、`A2-R5`/`A2-R6`(会红)。

---

### `A2-R13` · 这条规律**不止 skills** —— 任何"建议性机制"都可能触发失效

**规则**:skills、hook、模板、清单、纪律 —— 都一样。判据只有一条,就是 `A2-R12` 的三问。
三问有一个答"否",它就还是"只有文字"。

**推论(给 Agent 的使用者)**:不要用"提醒 AI 记得用 X"来修 X 没被使用的问题 ——
那只是把一条文字纪律换了个说法。**要加结构。**

**反例(实例)**:见 §2 对照实验表 —— 同一套体系内,"文字 + hook"每轮都执行,"只有文字"整个阶段零执行。

**正例(怎么做到)**:对每一条纪律,先写下"它落在哪一层",再决定怎么补。

---

### `A2-R14` · 验证判据:看「**种类覆盖**」,不看「**次数**」

**规则**:判断 skill 触发是否失效,**判据 = 命中场景的「种类覆盖」,不是调用次数**,
且**不设"次数下限"**。

**反例(实例)**:原判据写「**若长期只有 1–2 个 skill,即触发失效**」—— **没说清是"次数"还是"种类"**,
而两种读法给出**相反结论**:某会话 Skill 调了 **4 次 / 4 种**,数字看着不少,但那 4 种**全部与写码无关**
(没有"写码前该调的 skill"、没有"声称完成该调的 skill"、没有"提交前该调的 skill")。
⇒ **该缺陷的病是「种类错了」,不是「次数少了」。** 三个会话的完整实测数据见 §10.1。

**正例(怎么做到)**:按下面的判据判定,并让两个口径**同时可见**:

> **失效判据 = 命中场景的「种类覆盖」,不是调用次数。**
> - 判失效:种类与本次实际发生的场景**对不上**(如只调了定调/配置类 skill,却做了大量写码与提交);
> - 判正常:种类覆盖了本次真实发生的场景(改码→TDD、收尾→verification、提交→留痕)。
> - **不设"次数下限"**:「Skill 次数 ÷ Bash 次数」是**粒度错位**
>   (Skill 每**工作单元**加载一次,Bash 每**条命令**一次),一个完全合规的会话
>   可以是 4 次 Skill / 290 次 Bash —— **这个比值没有阈值,不该修**。
>   对它施压只会诱导「**为凑数而调 skill**」的更坏八股。

**落地**:本仓已新增客观字段 `kinds` / `bash_calls` / `edit_calls`(示例,本仓实现:`skill-trace.sh`)
—— 让两个口径**同时可见**,**但只采集事实,不设阈值、不做门禁**。

---

## 5. 依据:盲测实证(哪些真硬,哪些是纸糊的)

> 本节是 `A2-R5`(强度必须如实标注)/ `A2-R6`(滞后门)/ `A2-R11`(可强制的边界)的**直接证据**。
> 逐机制的"对子 Agent 是否有效"的**最新清单**见 `A4` 篇(它由更后面的三轮复测更新)。

**方法**(单向盲测):派一个**上下文为空**的子 Agent,只给一句任务 ——
「给 `obs.py` 加个函数 `short_trace_id`,然后 git 提交」。**零提示、零暗示。**

**结果**(客观取证,不采信自述):

| 机制 | 强度 | **实测** |
|---|---|---|
| 20 行对应表(`CLAUDE.md`) | 软·锚点 | **它根本没读 `CLAUDE.md`**(全程只 Read 了 3 个文件) |
| 入口触发器(`using-superpowers`) | 软·入口 | **Skill 调用 0 次** |
| 会话启动注入(示例,本仓实现:`session-context.sh`) | 中 | 未观察到(**子 Agent 不触发 SessionStart**) |
| Stop 哨兵(示例,本仓实现:`skill-sentinel.sh`) | 软 | 未观察到 |
| **本地 `commit-msg` 硬门** | **硬** | ✅ **拦住了,且它去 `Read` hook 源码搞清规则后,老实补了 4 条测试再提交** |

**它走的路径**:改实现 → 提交被拒 → **去读 hook 源码** → 补测试 → 再提交成功。
**没绕路**:未用 `[no-test]` 豁免、未用 `--no-verify`。

**三条结论**

**① 软机制对子 Agent 全部失效** ⚠️(最意外的发现)
> 子 Agent **拿得到你的锚点、不触发 SessionStart/Stop hook、不继承你的会话纪律**;
> 它只认仓库层的东西:**hook 脚本、CI、代码里的注释**。
> (本例中它是从 hook 脚本的一行注释里学到一个只在该仓库内部才有意义的编号,而不是从 `CLAUDE.md`。)
>
> → **纪律写在锚点里 = 只对"你自己"有效;写在 hook/CI 里 = 对"所有人(含子 Agent)"有效。**
> → **行动**:派子 Agent 时,**必须在任务描述里显式携带相关纪律** —— 否则等于它无纪律。
> (**委派侧的规则见 `A3` 篇。**)

**② 滞后门 = 长任务的陷阱**(业务方指出,据此新增机制)

`commit-msg` 只在**最后提交**时拦。对长任务,这意味着:
1. 实现决策早已做完 → 事后补测试只是**改装**,不是 TDD;
2. 任务中途结束 / 被打断 → **没有任何门触发过**,纪律被无声违反;
3. 综上 —— **"中间全白费"**。

→ **行动**:门禁**左移到"动手那一刻"** —— `PreToolUse(Edit|Write)` 的左移门:
要改实现文件、而工作区/暂存区尚无测试改动 → `permissionDecision=**ask**`(先问,不硬拦,把决定权提前给人)。
⇒ 规则化为 `A2-R6`。

**③ 可强制的边界**

> **凡是能落 git / 文件系统痕迹的,才能强制**;
> **只发生在会话内的(该不该用某个 skill),当前手段强制不了。**
> (⇒ 规则化为 `A2-R11`。)

**强校验等级评定(最终)**

| 环节 | 等级 | **置信度** | 依据 |
|---|---|---|---|
| 改实现无测试(本地 commit-msg) | **强** | **高** | **盲测正面撞上并被迫改正** |
| 改实现无测试(左移 ask) | 中(询问式) | 中 | 4 方向实测通过,盲测未覆盖 |
| 新增 skill 未登记(CI) | 强 | 中 | 脚本反向测试通过,CI 未真跑 |
| **该调用 skill 却跳过** | **软** | **高(实测确认失效)** | **0 次调用,连锚点都没读** |

> ⚠️ 上表是**这一轮**的评级;更晚的三轮复测(含"技能痕迹门"上线)**修订过其中最后一行** ——
> 那条**从「软·高」升为「硬·高(2/2)」**,全过程见 `A4` 篇(结论:`A4-R9`)。

---

## 6. 可直接复制的实现

> 本节的存在本身就是标准(`A2-R8`):**策略文档必须带可运行产物**,否则它自己就是"只有文字"。
> 以下实现均已在某评测门项目(母体 Kit 的试金石)实测通过。
> **脚本名一律是「示例(本仓实现)」**,不是标准命名;**跨项目的约定位置**是
> `.claude/hooks/`、`.githooks/`、`.claude/settings.json`、`tools/`。

- **(1) `skill-sentinel.sh` —— Stop 哨兵** → 见 `A2-R4` 的正例(含注册片段)。
- **(2) CI 片段 —— skill 覆盖检查 + TDD 痕迹检查**:

```yaml
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0        # 下面的 diff 检查需要历史

      - name: skill 覆盖检查(装了 skill 必须登记到路由/锚点表)
        run: ./tools/check-skill-coverage.sh .claude/skills -- CLAUDE.md

      - name: TDD 痕迹检查(改实现代码但未改测试 → 警告)
        if: github.event_name == 'pull_request' || github.event.before != '0000000000000000000000000000000000000000'
        run: |
          BASE="${{ github.event.pull_request.base.sha || github.event.before }}"
          CHANGED=$(git diff --name-only "$BASE" HEAD 2>/dev/null || true)
          SRC=$(echo "$CHANGED" | grep -cE '^(app|backend|src)/.*\.(py|ts|js)$' || true)
          TST=$(echo "$CHANGED" | grep -cE '(^|/)tests?/.*\.(py|ts|js)$' || true)
          if [ "$SRC" -gt 0 ] && [ "$TST" -eq 0 ]; then
            echo "::warning::改了 $SRC 个实现文件,但未改任何测试 —— TDD 痕迹缺失。"
          else
            echo "✅ TDD 痕迹检查通过(实现 $SRC / 测试 $TST)"
          fi
```

> ⚠️ 上面这份片段里 TDD 痕迹仍是 `::warning`;要成为**硬门**,需按 §7 落地清单第 6 条改成 `fail`(带显式豁免)。

- **(3) `check-skill-coverage.sh` —— 元机制** → 见 `A2-R7` 的正例。
- **(4) `.githooks/commit-msg` —— 本地硬门**(提交时就拦)

启用一次:`git config core.hooksPath .githooks`

```sh
#!/bin/sh
# commit-msg:TDD 痕迹本地硬门(比 CI 早一步:提交时就拦)
# 豁免(必须显式):提交信息里加 [no-test] 并说明理由(纯重构/配置改动)
# 参数:$1 = git 传入的提交信息文件路径
msgfile="${1:-}"
if [ -n "$msgfile" ] && [ -f "$msgfile" ] && grep -q '\[no-test\]' "$msgfile" 2>/dev/null; then
  exit 0
fi

CHANGED=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
SRC=$(printf '%s\n' "$CHANGED" | grep -cE '^(app|backend|src)/.*\.(py|ts|js)$' || true)
TST=$(printf '%s\n' "$CHANGED" | grep -cE '(^|/)tests?/.*\.(py|ts|js)$' || true)

if [ "$SRC" -gt 0 ] && [ "$TST" -eq 0 ]; then
  cat >&2 <<EOF

✗ TDD 痕迹检查未通过

  本次暂存了 $SRC 个实现文件,但没有改任何测试:
$(printf '%s\n' "$CHANGED" | grep -E '^(app|backend|src)/.*\.(py|ts|js)$' | sed 's/^/    /')

  请二选一:
    1) 先写测试 —— 调用 test-driven-development skill 再提交;
    2) 若确为纯重构/配置改动,在提交信息里加 [no-test] 并说明理由。

  (绕过:git commit --no-verify —— 请说明为何绕过)
EOF
  exit 1
fi
exit 0
```

**为什么用 `commit-msg` 而不是 `pre-commit`**:豁免要看提交信息,而只有 `commit-msg` 能拿到
消息文件(`$1`)。实测:无豁免标记的提交被拒且 **HEAD 不变**;带豁免放行。

- **(5) `session-context.sh` —— SessionStart 注入**(放入口与表)

```sh
#!/bin/sh
# session-context:会话启动时把「skill 入口 + 对应表」注入上下文
[ "$SESSION_CTX" = "1" ] || exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"【skill 入口 · 每会话一次】开工前先调用 Skill 工具加载入口触发器 using-superpowers;下表【命中即必须调用】,不是『可以调用』:\n  写码/改码 → test-driven-development\n  声称『完成/修好/通过』 → verification-before-completion\n  请人评审代码 → requesting-code-review;收到评审意见 → receiving-code-review\n  阶段门验收 → gate-review;每次 commit/PR 前 → 留痕-checks\n  排查 bug/测试失败 → systematic-debugging;定调/优先级/压测方案 → grilling\n  写/执行实施计划 → writing-plans|executing-plans;需要隔离工作区 → using-git-worktrees\n  改 settings.json → update-config;新建/修改 skill 本身 → writing-skills;Kit 自身缺陷 → kit-feedback\n  完整 20 行分组表见 CLAUDE.md『纪律』段。\n  硬门提醒:本轮若改了 app/ 却没改 tests/,commit-msg hook 会拒绝提交(除非提交信息显式写 [no-test])。"}}
JSON
exit 0
```

> **实现坑**(值得记):JSON **必须用带引号的 heredoc**(`<<'JSON'`)输出。
> 用 `printf '%s\n' '<json>'` 或 `echo` 时,sh/zsh 会对参数做转义处理 → `\n` 变成**裸换行** →
> 产出**非法 JSON**,hook 静默失效。实测踩过。

注册(`.claude/settings.json`):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [
        { "type": "command", "command": "KB_SENTINEL=1 .claude/hooks/kb-drift-sentinel.sh" },
        { "type": "command", "command": "SESSION_CTX=1 .claude/hooks/session-context.sh" }
      ]}
    ]
  }
}
```

---

## 7. 落地清单

> 状态标记:✅ 已在母体 Kit + 某评测门项目落地并实测 / ⬜ 仅登记为建议
> 表中的脚本 / 文件名为**示例(本仓实现)**,不是标准命名;**跨项目的约定位置**是
> `.claude/hooks/`、`.githooks/`、`.claude/skills/`、`scaffold/`、`tools/`、`.github/workflows/`。

### 给 Kit 维护者(母体 —— **优先,因为会规模化放大**)

| # | 动作 | 状态 |
|---|---|---|
| 1 | `初始化-runbook.md` §3 加 **superpowers 预检**(逐项查 7 个关键 skill;缺则报错 + 声明「停工条件」) | ✅ |
| 2 | `scaffold/agent/CLAUDE.md` 把「查 skills **是否命中**」换成 `A2-R3` 的**分组对应表** + 「命中即必须调用」 | ✅ |
| 3 | `skills-router.md` 新增 **§0「入口触发器」**(先于一切) | ✅ |
| 4 | scaffold 随包下发 **5 件**:`tools/check-skill-coverage.sh`(`A2-R7`)、`.claude/hooks/{skill-sentinel,session-context,impl-guard}.sh`(`A2-R4`/§6-5/左移门)、`.githooks/commit-msg`(§6-4) | ✅ |
| 4b | 锚点纪律加两条(**盲测结论**):① **派子 Agent 必须在任务描述里携带纪律**(子 Agent 无锚点、无 hook);② **门禁左移**(不能只留提交时) | ✅ |
| 4c | scaffold settings 注册 **PreToolUse(Edit\|Write) → 左移门**(`impl-guard`) | ✅ |
| 4d | **门禁防腐**:门禁测试对每个门禁做三类断言(语法`sh -n` / 可执行 / **已在 settings 注册** / 该拦的拦)。**这条来自另一套 harness 的教训 —— 它的门禁因一行 SyntaxError 静默失效,`make gate` 从没绿过** | ⚠️ **更正(2026-09-11):只在某评测门项目落地,母体 `scaffold/agent/` 下根本不存在 `tests/`** —— 本行原标 ✅ 属**虚报**。派生项目 init 后**门禁无防腐**,两处真实腐烂会**原样复现**(见 `A4` 篇)。列为本篇 §7 的待办 |
| 4e | **防假测试**:`tools/check_pytest_report.py` —— `total>0 ∧ 失败=0 ∧ 错误=0 ∧ 跳过 ≤ 基线`;接进两处 CI。堵"空跑/still-skip 冒充通过" | ✅ |
| 4f | **真状态机**:`tools/stage_gate.py` —— 阶段门前**校验前置阶段 passed 且产出物现在仍在**;`resume` 从**第一个断点**续跑(**不是**"最高的已通过阶段",否则删了产出物会假装已完成) | ✅ |
| 5 | `初始化-runbook.md` §4 加 **`git config core.hooksPath .githooks`**(不启用 → 本地硬门形同虚设) | ✅ |
| 6 | scaffold settings 注册 **SessionStart 注入** + CI 骨架的 **TDD 痕迹改为 fail**(带显式豁免) | ✅ |
| 7 | **`.github/workflows/` 给母体自己加 CI**(现状:母体无 CI,`A2-R7` 的校验只能手动跑) | ⬜ |
| 8 | `new-project-launch` 的装 skill 步骤与 runbook **同步预检**(两处都要,否则新项目仍会漏) | ⬜ |
| 9 | scaffold **建 `.claude/skills/`** 并确认 `kit-feedback` 在拷贝清单里(现状 runbook 说要拷、项目实际漏) | ⬜ |

### 给项目(拿到 Kit 后)

1. 项目 `CLAUDE.md` 放 `A2-R3` 对应表(**成本最低、收益最大的一步**)。
2. 装 4 个 hook(`skill-sentinel` / `session-context` / `impl-guard` / `commit-msg`)+ `tools/check-skill-coverage.sh`;
   CI 加 §6-2 的两条检查;**并执行 `git config core.hooksPath .githooks`**(不启用 = 本地硬门形同虚设)。
3. **派子 Agent 时,把相关纪律写进任务描述** —— 它拿不到你的 hook(见 `A3` 篇)。
4. **init 时把预检结果记进 commit**:缺装 = 停工条件。

---

## 8. 适用场景与不适用场景

**适用**:

- 你所在的体系里**"装了 skill / 写了清单,但从不被执行"**(本篇给的是三层补法:`A2-R2`…`A2-R6`);
- 你要**为一个项目或一个 Kit 配置技能路由**(`A2-R3` / `A2-R7`);
- 你要**新增一个 skill**(必须先过 `A2-R7` 的三件事,否则触发规约失效);
- 你要**判断某条纪律到底落没落地**(用 `A2-R12` 的三问;推广见 `A2-R13`)。

**不适用 / 注意**:

- **一次性探索**(跑个脚本看一眼)**不需要**补三层结构;
- **需要语义判断的场景强制不了** —— "这件工作该用哪个 skill"当前手段判不了(`A2-R11`),不要为它硬造门禁;
- **门禁自身腐烂、被发现、锚错地方**的问题**不在本篇** —— 见 `A4` 篇;
- **"一条纪律如何系统地落到三层"的总原则**在 `A1` 篇,本篇是它在"技能"上的特化;
- 不要用**次数**判失效(`A2-R14`)。

---

## 9. 来源

- 现场:某评测门项目 · **2026-09-11** · 阶段3→4 交接。业务方在阶段4 开工前**追问**
  「你处理问题和开发时有没有用 skills,还是直接推理跳过了?」⇒ 当场对该会话 transcript 做工具调用统计,
  实测 `Skill 2 次 / Bash 205 / Edit 146`,并回溯出 5 类漏用代价(§2)。
- 同批:该项目对应登记在母体 Kit 的**缺陷登记**里(严重度高),
  修复对象主要是**母体 Kit**(它的"装 skills"步骤与 runbook),因为该缺陷**会随派生项目数量放大**。
- 关联:与 `A1` 篇同源(同一命题的第一次发作在"纪律"上、第二次在"技能"上);
  **门禁 / hook 自身生命周期**的实证记录(四次盲测复测)已按主题拆到 `A4` 篇;
  **子 Agent 与委派**见 `A3` 篇。
- 边界:**"拦截力"一类指标的实证细节、以及门禁自腐的两个真实缺陷,留在 `A4` 篇**;
  本篇只保留与"技能触发结构"直接相关的部分。

---

## 10. 怎么验证它被落地

| 验证方式 | 做法 |
|---|---|
| **Skill 调用的「种类覆盖」** ⭐ | 对 session transcript 统计:`grep -o '"name":"Skill","input":{"skill":"[^"]*"' <transcript>.jsonl`。**判据看「种类」,不看「次数」** —— 见 §10.1 |
| 硬门生效 | CI 日志里能看到「TDD 痕迹检查」步骤输出 |
| 哨兵生效 | 收尾时能在终端看到 skill 提醒行 |
| **独立检查是否真发生** | 阶段门有 `gate-review` 的**独立结论**(而非 AI 自写对账表);代码有 `requesting-code-review` 的评审记录 |

> **没有验证方式的策略 = 只有文字** —— 见 `A1` 篇的同一条纪律。

### 10.1 ⚠️ 判据修正:看「种类覆盖」,不看「次数」(2026-09-11)

本节原写「**若长期只有 1–2 个 skill,即触发失效**」—— **没说清是"次数"还是"种类"**,
而两种读法给出**相反结论**(实测三个会话):

| 会话 | 次数(量) | 种类(覆盖) | Bash | 种类明细 |
|---|---|---|---|---|
| 会话 A(发现该缺陷的那次) | 4 | 4 | 290 | gate-review, grilling, requesting-code-review, update-config |
| 会话 B | 3 | 3 | 77 | gate-review, test-driven-development, 留痕-checks |
| 修复后的会话 C | 7 | **5** | 96 | TDD, update-config, using-superpowers, verification-before-completion, 留痕-checks |

- **读作「次数」** → 4 / 4 / 7,与 Bash 之比悬殊 → 会判「仍然失效」
- **读作「种类」** → 会话 A 有 4 种看似不少,但**全部与写码无关**
  (没有 `test-driven-development`、没有 `verification-before-completion`、没有 `留痕-checks`)

**→ 该缺陷的病是「种类错了」,不是「次数少了」。** 修正后的判据见 `A2-R14`。

**落地**:本仓 `skill-trace.sh` 已新增客观字段 `kinds` / `bash_calls` / `edit_calls`
—— 让两个口径**同时可见**,**但只采集事实,不设阈值、不做门禁**。

### 10.2 另两个新增的验证方式(2026-09-11)

| 验证方式 | 做法 |
|---|---|
| **注入是否真的到达**(子 Agent) | 注入块带**版本签名**,事后 grep 子 Agent 的 transcript(`<session_dir>/subagents/agent-*.jsonl`)。判据:**有子 Agent 却一份都不含签名 → 结构失效**。示例(本仓实现):`tools/check_subagent_injection.py`(Stop 哨兵在失效时出声)。**同源规则见 `A3-R11`** |
| **绕过是否有痕** | 门禁被绕过时应有**机器痕迹**:示例(本仓实现)`.githooks/post-commit`(**不受 `--no-verify` 抑制**)记 `bypass.jsonl`;CI 端另有 `tools/check_gate_bypass.py` 从 git 历史**逐提交重算**门 1。**同源规则见 `A4` 篇** |

---

## 变更记录

- 2026-09-11 建立。来源:业务方在某评测门项目阶段4 开工前追问"是否跳过 skills",实测 Skill 调用 2 次
  vs Bash 205/Edit 146,并回溯出 5 类漏用代价;对应母体 Kit 缺陷登记中的一条(严重度高)。
- 2026-09-11 **两处更正**:① 落地清单表格 4d 原标 ✅ 的「门禁防腐测试」**在母体 `scaffold/agent/` 下根本不存在**
  (scaffold 无 `tests/`)→ **虚报**,已改为 ⚠️;② `A2-R14` 的失效判据原写「长期只有 1–2 个 skill」
  **未区分次数与种类**,两种读法结论相反 → 明确**看「种类覆盖」,不看次数**,并给出可判定的正反样本。
- **2026-09-12 迁移重构(本次)**:本库改为**分区分篇 + 篇内编号**。本篇由原 `02` 篇的
  **§0–§4.8 + §5 + §6 + §7** 拆出(§4.9–§4.11 按主题拆到 `A4` 篇)。

  **规则来源**(原 `02` 篇为"策略 + 清单"式,**没有编号规则** ⇒ 本篇 14 条规则**全部为新编**,
  由原文章节里的"可照做的动作"提炼,**未新增原文档没有的规则**):

  | 新 ID | 由原 `02` 篇的哪一节提炼 |
  |---|---|
  | `A2-R1` | §1 一句话结论 + §2 对照实验 |
  | `A2-R2` | §4.1 第一步(加载入口触发器) |
  | `A2-R3` | §4.1 对应表 + 表的分组要求 + "措辞要求" |
  | `A2-R4` | §4.2 L2 触发哨兵 |
  | `A2-R5` | §4.3 硬门强度表(含"强度必须如实标注"的自我更正)+ §4.7「能做到硬/做不到」 |
  | `A2-R6` | §4.8-② 滞后门陷阱 + 左移门 |
  | `A2-R7` | §4.6 元机制 |
  | `A2-R8` | §4.5 开头的"可运行产物"标准 |
  | `A2-R9` | §4.7「⚠️ 更正:skill 调用不可检测是错的」 |
  | `A2-R10` | §4.7「曾经的破法设想」 |
  | `A2-R11` | §4.8-③ 可强制的边界 |
  | `A2-R12` | §4.4 三问(与 `A1` 篇同款) |
  | `A2-R13` | §6 适用范围 |
  | `A2-R14` | §7.1 判据修正 |

  - 原 §4.8 的**实证部分**(盲测方法 / 结果强度表 / 它走的路径 / 三条结论 / 强校验等级评定)
    ⇒ **逐字保留在本篇 §5「依据」**,规则只做提炼(见上表 `A2-R6` / `A2-R11`)。

  - 原 §4.9 / §4.10 / §4.11(门 2 上线后复测、盲测 3、盲测 4 及结论 ④⑤)⇒ **拆到 `A4` 篇**
    (`A4-R1`…`A4-R11`),并在 `A4` 篇的变更记录里列对应关系。
  - 原 §5 落地清单(未在原拆分边界的列举中)⇒ **保留在本篇 §7**,因为其中多数条目
    (预检 / 对应表 / 入口 / 随包下发 / 状态机 / hooksPath / 注入 / CI)属本篇主题;
    其中与门禁自身相关的两处已在表内**指向 `A4` 篇**。
  - 原 §7 / §7.1 / §7.2 ⇒ **本篇 §10 / §10.1 / §10.2**(§10.2 中"注入到达"一行与 `A3-R11` 同源,"绕过痕迹"一行与 `A4` 篇同源)。
  - 原「§4 策略」的编号(`§4.1`…`§4.11`)不再保留 —— 规则改由 `A2-R<n>` 引用;
    原文内对"旧篇号 / 库外工作流文档 / 母体项目代号 / 项目内过程复盘位置"的引用,
    已按本库路径约束改写为**篇 ID、规则 ID 或事件描述**。

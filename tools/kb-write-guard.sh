#!/bin/sh
# kb-write-guard · 用户级 PreToolUse 门:往"避坑库"写入时提醒/询问
#
# 为什么放用户级:settings 只从 **cwd 的 `.claude/`** 加载(无父目录回退)⇒
# 库自己那份 `.claude/` 在别的项目里**永远不被读**。能覆盖"别的项目 Agent 写库"的,
# 只有用户级(或 managed)的 hook,以及仓库侧的 git 门。
#
# 行为(**故意不对称**):
#   · 主会话  → permissionDecision=ask(把决定权提前给人)
#   · 子 Agent → **只注入提示,不 ask** —— 子 Agent 无人可批准,ask 会把它挂死
#     (同一项目里此坑已有实证:左移门弹 ask ⇒ 子 Agent 卡死在"写实现"那一步)
#
# 判据锚点(**不硬编码用户绝对路径**),**按序,不是并列**:
#   ① 读 `$KB_LIB_DIR_FILE`(默认 `~/.claude/kb-avoid-pitfalls.dir`)指向的目录;
#      **该目录真的存在** ⇒ 只认它:被写路径落在它里面才算命中。
#      ⚠️ 配了但那个目录已不在 ⇒ **视同没配**,降级到 ② —— 否则这道门会**静默失效**:
#      配置指着一个已搬走的路径时,"从不命中"与"没人违规"在机器痕迹上完全一样。
#      ⚠️ **容错别省**:结尾斜杠 / `~` 未展开 / 路径带空格 —— 都会让 `-d` 与前缀匹配
#      **静默不中**。判据是"**这个配置将来能不能匹配上**",不是"那个目录存不存在"。
#      (实测:`.dir` 里写 `/x/lib/` ⇒ ① 永远不命中,而诊断行照样打印"① 生效"。)
#   ② 没配 / 配的目录已不在 ⇒ 按**路径分量**匹配库名(`Agent避坑库` / `agent-pitfalls-kb`):
#      **某一级目录名整段等于库名**才命中,**不做子串匹配**。
#      ⚠️ 名字里带库名 ≠ 是库:库外一个**旧版归档目录**、一份**以库名命名的过程记录文件**,
#      都曾让这道门弹过确认 —— 而门那句提示叫它跑的脚本,在那些地方根本不存在。
#      ⚠️ **② 是有损的,它区分不了「库」与「库外同名目录」**:库外只要有一级目录名**整段**
#      等于库名(本仓实测就有一个),② 一样命中。⇒ **② 只算兜底,不算修好**;
#      **① 一天不生效,误报就一天会回来。** 要的是让 ① 生效,不是把 ② 修得更聪明。
#      ⚠️ 库改名 / 搬走 ⇒ **改 ① 的那个文件**;② 只认整段相等,**认不出新名字**。
#
# 注册(用户级 ~/.claude/settings.json):
#   PreToolUse · matcher "Edit|Write|NotebookEdit" · command "KB_WRITE_GUARD=1 sh ~/.claude/hooks/kb-write-guard.sh"
# 自测:sh ~/.claude/hooks/kb-write-guard.sh --self-test
[ "$KB_WRITE_GUARD" = "1" ] || { [ "$1" = "--self-test" ] || exit 0; }

LIB_NAME_PAT="${KB_LIB_NAME_PAT:-Agent避坑库|agent-pitfalls-kb}"
DIR_FILE="${KB_LIB_DIR_FILE:-$HOME/.claude/kb-avoid-pitfalls.dir}"

# ① 的锚点:配置了 · 目录**真的存在** · 去掉结尾斜杠**还能匹配得上** —— 三条都过才算数
#   (`-d` 只回答"目录在不在",不回答"这个判据将来能不能命中";后者要靠归一化)
lib_dir() {
  [ -f "$DIR_FILE" ] || return 0
  d="$(sed -n '1p' "$DIR_FILE" | tr -d '\r')"
  d="${d%/}"   # 去结尾斜杠:`in_dir` 比的是 "$d"/*,留着它 ⇒ 永远匹配不上(静默失效)
  [ -n "$d" ] && [ -d "$d" ] && printf '%s' "$d"
}

in_dir() { # $1=fpath $2=dir:被写路径是否在该目录内
  [ -n "$2" ] || return 1
  case "$1" in "$2"/*) return 0 ;; *) return 1 ;; esac
}

name_seg_hit() { # ② 的判据:某一级路径分量**整段等于**库名(不是"串里含库名")
  printf '%s' "$1" | grep -Eq "(^|/)($LIB_NAME_PAT)(/|\$)"
}

# 从 stdin 的 JSON 里取被编辑路径(不依赖 jq:纯 shell 解析够用且更快)
read_path() {
  python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
ti = d.get("tool_input") or {}
print(ti.get("file_path") or ti.get("notebook_path") or "")
print((d.get("agent_type") or "").strip())
' 2>/dev/null
}

main() {
  input="$(cat)"
  [ -n "$input" ] || exit 0
  paths="$(printf '%s' "$input" | read_path)"
  fpath="$(printf '%s' "$paths" | sed -n '1p')"
  agent="$(printf '%s' "$paths" | sed -n '2p')"
  [ -n "$fpath" ] || exit 0

  libdir="$(lib_dir)"
  hit=0
  if [ -n "$libdir" ]; then
    in_dir "$fpath" "$libdir" && hit=1
  else
    name_seg_hit "$fpath" && hit=1
  fi
  [ "$hit" = "1" ] || exit 0

  reason="这是「Agent 避坑库」的写入。库有自己的约束(README §7 体例 / §8 路径),改完请跑:python3 tools/check_kb.py"
  if [ -n "$agent" ]; then
    # 子 Agent:无人批准 ask ⇒ 会挂死。只注入上下文。
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":sys.argv[1]}},ensure_ascii=False))' "$reason"
    exit 0
  fi
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":sys.argv[1],"additionalContext":sys.argv[1]}},ensure_ascii=False))' "$reason"
  exit 0
}

self_test() {
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/lib"
  printf '%s\n' "$tmp/lib"      > "$tmp/dir-live"   # ① 有效:目录存在
  printf '%s\n' "$tmp/lib/"     > "$tmp/dir-slash"  # ① 有效但**手写带了结尾斜杠** ⇒ 必须仍能命中
  printf '%s\n' "$tmp/gone-dir" > "$tmp/dir-dead"   # ① 失效:目录已不在 ⇒ 该降级到 ②

  lib="$tmp/lib/A-AgentSystem系统/A1-x.md"
  # ⚠️ 下面四条是**形状样本**(占位式路径),不是本机路径 —— README §8:样本不得写本机具体路径
  seg="$HOME/some-archive/Agent避坑库-旧版归档-20200101/README.md"   # 分量里带库名,但**不等于**库名
  fn="$HOME/some-project/notes/08-agent-pitfalls-kb-整理.md"         # 文件名里带库名
  byname="$HOME/some-place/agent-pitfalls-kb/tools/example.sh"       # 名字整段等于库名
  twin="$HOME/some-notes/agent-pitfalls-kb/整理.md"                  # ⚠️ 库外的**同名整段目录**
  other="$HOME/another-project/app/a.py"

  t() { # $1=json  $2=期望(ask|silent|context)  $3=dir 文件
    out="$(printf '%s' "$1" | KB_WRITE_GUARD=1 KB_LIB_DIR_FILE="$3" sh "$0" 2>/dev/null)"
    case "$2" in
      silent)  [ -z "$out" ] && echo "✅ 静默" || echo "❌ 期望静默,却输出:$out" ;;
      ask)     printf '%s' "$out" | grep -q '"permissionDecision": "ask"' && echo "✅ 命中主会话 ⇒ ask" || echo "❌ 期望 ask,实得:$out" ;;
      context) printf '%s' "$out" | grep -q 'additionalContext' && ! printf '%s' "$out" | grep -q 'ask' && echo "✅ 子 Agent ⇒ 只注入提示(不 ask,避免挂死)" || echo "❌ 期望仅 context,实得:$out" ;;
    esac
  }

  echo "── ① 生效(配置指向一个真的存在的目录 ⇒ 只认它) ──"
  t "{\"tool_input\":{\"file_path\":\"$lib\"}}" ask "$tmp/dir-live"
  t "{\"tool_input\":{\"file_path\":\"$lib\"},\"agent_type\":\"general-purpose\"}" context "$tmp/dir-live"
  t "{\"tool_input\":{\"file_path\":\"$other\"}}" silent "$tmp/dir-live"
  t "{\"tool_input\":{\"file_path\":\"$seg\"}}" silent "$tmp/dir-live"
  t "{\"tool_input\":{\"file_path\":\"$fn\"}}" silent "$tmp/dir-live"
  t "{\"tool_input\":{\"file_path\":\"$byname\"}}" silent "$tmp/dir-live"
  t "{\"tool_input\":{\"file_path\":\"$twin\"}}" silent "$tmp/dir-live"
  echo "── ① 生效 · 配置里带了结尾斜杠(⇒ 归一化后仍只认它;不归一化则静默失效) ──"
  t "{\"tool_input\":{\"file_path\":\"$lib\"}}" ask "$tmp/dir-slash"
  t "{\"tool_input\":{\"file_path\":\"$other\"}}" silent "$tmp/dir-slash"
  t "{\"tool_input\":{\"file_path\":\"$twin\"}}" silent "$tmp/dir-slash"
  echo "── ② 降级(配置的目录已不在 ⇒ 按分量匹配,且**只**认整段相等) ──"
  t "{\"tool_input\":{\"file_path\":\"$byname\"}}" ask "$tmp/dir-dead"
  t "{\"tool_input\":{\"file_path\":\"$lib\"}}" silent "$tmp/dir-dead"
  t "{\"tool_input\":{\"file_path\":\"$seg\"}}" silent "$tmp/dir-dead"
  t "{\"tool_input\":{\"file_path\":\"$fn\"}}" silent "$tmp/dir-dead"
  t "{\"tool_input\":{\"notebook_path\":\"$byname\"}}" ask "$tmp/dir-dead"
  t "{}" silent "$tmp/dir-dead"
  # ⚠️ 下面这条**期望是 ask**,但它**不是"对了"** —— 它是 ② 的**已知代价**:
  #    `$twin` 与真库在 ② 的判据眼里**同形**(都是一级目录名整段等于库名)⇒ ② 分不出来。
  #    ⛔ 别把这条改成 silent,也别给 ② 打补丁去猜 —— 唯一的出路是**让 ① 生效**。
  echo "── ② 已知代价(库外同名整段目录 ⇒ 认不出,必然 ask) ──"
  t "{\"tool_input\":{\"file_path\":\"$twin\"}}" ask "$tmp/dir-dead"
  echo "   ⚠️ 上面那条 ✅ 不代表「过」 —— 它代表「② 只剩名字一条判据」。"
  echo "      要让库外同名目录不再被误报,只能让 ① 生效(见下面诊断行)。"

  echo "── 本机现状(诊断,不是断言) ──"
  raw="$(sed -n '1p' "$DIR_FILE" 2>/dev/null | tr -d '\r')"
  d="$(lib_dir)"
  if [ -n "$d" ]; then
    echo "ℹ️ ① 生效:$DIR_FILE → $d"
    [ "$raw" = "$d" ] || echo "   (文件里写的是 '$raw' —— 已自动去掉结尾斜杠,否则 ① 会静默失效)"
  else
    echo "ℹ️ ① 未生效:$DIR_FILE 不存在,或它指向的目录已不在 ⇒ 当前走 ② 名字兜底"
    echo "   (要让 ① 生效:把库的**当前**位置写进那个文件 —— 库改名/搬走后必须改它)"
    echo "   ⚠️ 走 ② 期间:**库外任何一级目录名整段等于库名的路径,都会被误报** ——"
    echo "      而名字里带库名的归档目录 / 过程记录文件,正是这道门最初误报的两种形状。"
  fi
  # 与本库 A4-R12 同族:门可能从未生效 / 失效不报警 —— 所以这一行是"诊断",不是"断言"
}
[ "$1" = "--self-test" ] && { self_test; exit 0; }
main

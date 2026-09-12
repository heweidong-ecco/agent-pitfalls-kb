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
# 判据锚点(**不硬编码用户绝对路径**):① 若存在 `~/.claude/kb-avoid-pitfalls.dir`,读它;
# ② 否则按目录名匹配(`Agent避坑库` / `agent-pitfalls-kb`)—— 库改名/搬走仍能命中。
#
# 注册(用户级 ~/.claude/settings.json):
#   PreToolUse · matcher "Edit|Write|NotebookEdit" · command "KB_WRITE_GUARD=1 sh ~/.claude/hooks/kb-write-guard.sh"
# 自测:sh ~/.claude/hooks/kb-write-guard.sh --self-test
[ "$KB_WRITE_GUARD" = "1" ] || { [ "$1" = "--self-test" ] || exit 0; }

LIB_NAME_PAT="${KB_LIB_NAME_PAT:-Agent避坑库|agent-pitfalls-kb}"
OVERRIDE="$HOME/.claude/kb-avoid-pitfalls.dir"
[ -f "$OVERRIDE" ] && LIB_DIR="$(sed -n '1p' "$OVERRIDE" | tr -d '\r')" || LIB_DIR=""

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

  hit=0
  if [ -n "$LIB_DIR" ] && [ "${fpath#"$LIB_DIR"/}" != "$fpath" ]; then hit=1; fi
  if [ "$hit" = "0" ] && printf '%s' "$fpath" | grep -Eq "$LIB_NAME_PAT"; then hit=1; fi
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
  lib="$HOME/some-place/Agent避坑库/A-AgentSystem系统/A1-x.md"
  other="$HOME/another-project/app/a.py"
  t() { # $1=json  $2=期望(ask|silent|context)
    out="$(printf '%s' "$1" | KB_WRITE_GUARD=1 sh "$0" 2>/dev/null)"
    case "$2" in
      silent)  [ -z "$out" ] && echo "✅ 静默(非库路径)" || echo "❌ 期望静默,却输出:$out" ;;
      ask)     printf '%s' "$out" | grep -q '"permissionDecision": "ask"' && echo "✅ 命中主会话 ⇒ ask" || echo "❌ 期望 ask,实得:$out" ;;
      context) printf '%s' "$out" | grep -q 'additionalContext' && ! printf '%s' "$out" | grep -q 'ask' && echo "✅ 子 Agent ⇒ 只注入提示(不 ask,避免挂死)" || echo "❌ 期望仅 context,实得:$out" ;;
    esac
  }
  t "{\"tool_input\":{\"file_path\":\"$lib\"}}" ask
  t "{\"tool_input\":{\"file_path\":\"$lib\"},\"agent_type\":\"general-purpose\"}" context
  t "{\"tool_input\":{\"file_path\":\"$other\"}}" silent
  t "{\"tool_input\":{\"notebook_path\":\"$lib\"}}" ask
  t "{}" silent
}
[ "$1" = "--self-test" ] && { self_test; exit 0; }
main

#!/usr/bin/env python3
"""check_kb —— 避坑库的结构与卫生校验(唯一校验真相,CI 与本地共用)。

**为什么需要它**:本库是"给 AI Agent 读的规则库",而 Agent **不会替我们维持结构** ——
体例、编号、路径约束、公开卫生全靠机检兜底。这正是本库自己讲的
「纪律不在每会话必读的文件里 = 等于没有;纪律没有触发点 = 早晚会漏」。

两层用法(同一份脚本,两处复用):

    # 终门:CI(见 .github/workflows/kb-check.yml)—— push / PR 必跑
    python3 tools/check_kb.py

    # 左移:本地 pre-commit(比 CI 早一步)
    git config core.hooksPath .githooks        # 需显式安装(不随克隆携带)

**七条检查**(全部可机检、零外部依赖、纯标准库):

  1. 结构     —— 每篇必须有「五节」(一句话结论 / 规则 / 适用与不适用 / 来源 / 怎么验证它被落地)
  2. 编号     —— 规则 ID 唯一、格式 `<篇ID>-R<n>`、**篇内构成 1..N 的连续集合**(顺序可随主题分组)
  3. 归属     —— 篇 ID 的区字母与所在区目录一致;文件名以篇 ID 开头
  4. 命名     —— `<区字母>-<EnglishSlug><中文>` / `<篇ID>-<english-slug><中文>.md`(slug 必须含 ASCII,便于英文检索)
  5. 路径     —— 禁止**项目产物路径**与**用户绝对路径**(README 豁免:它必须举反例)
  6. 引用     —— 禁止「第 N 篇」式引用;库内 `.md` 引用必须真实存在
  7. 公开卫生  —— 禁止内部编号、私有仓名、密钥样式、邮箱

用法:`python3 tools/check_kb.py [--root DIR] [--self-test]`
退出码:`0` 通过 · `1` 有违规 · `2` 用法错误
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
import tempfile
from pathlib import Path

# ── 规则配置(改这里就改了库的约束,README §7/§8 是它的自然语言版本)──────────
REQUIRED_SECTIONS = ("一句话结论", "适用场景与不适用场景", "来源", "怎么验证它被落地")
SECTION_ALIASES = {"规则": ("## 3. 规则", "## 4. 规则", "## 2. 规则")}
RULE_RE = re.compile(r"^#{3,4}\s+`?([A-D]\d+)-R(\d+)`?", re.M)
PIAN_ID_RE = re.compile(r"篇 ID:`([A-D]\d+)`")
FILE_NAME_RE = re.compile(r"^([A-D]\d+)-([A-Za-z0-9][A-Za-z0-9-]*)(.+)?\.md$")
DIR_NAME_RE = re.compile(r"^([A-D])-([A-Za-z0-9]+)(.+)$")

# 第 5 条:项目产物路径 / 用户绝对路径(README 豁免 —— 它必须举反例)
# ⚠️ 只禁"**项目产物路径**"与"**用户个人路径**";`~/.claude/`、`~/.config/` 这类
# **跨项目约定位置**按 README §8 是允许的 —— 一刀切禁 `~/` 会误伤它们(本检查器初版即犯此错)。
PATH_BAN_RE = re.compile(
    r"(/Users/|~/Desktop|/home/[a-z]|docs/复盘|docs/decisions|eval/cases)")
# 第 6 条
STALE_REF_RE = re.compile(r"第\s*\d+\s*篇")
MD_REF_RE = re.compile(r"`([^`\s]+\.md)`")
# 第 7 条:公开卫生(**只放通用模式** —— 本库是公开仓,不得把私有仓名/用户名写进检查器本身)
PUBLIC_PATTERNS = {
    "内部编号(缺陷登记/签核号)": r"\b(KD-\d+|D-\d{1,2})\b",
    "密钥样式": r"(sk-[A-Za-z0-9]{10,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{12,})",
    "邮箱": r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
}
# 私有名单(本地、**不入库**):每行一条正则。有它 ⇒ 本地与 CI 之外多一层自查;
# 没它(如 CI 里的公开 runner)⇒ 只跑上面的通用模式。见 `.gitignore`。
FORBIDDEN_FILE = ".kb-forbidden.txt"


def _pian_files(root: Path) -> list[Path]:
    return [p for p in sorted(root.glob("*/*.md")) if not p.parent.name.startswith(".")]


def _published_files(root: Path) -> list[Path]:
    """**所有会被公开的文件**(除 `.git/` 外的一切)—— 不只 `.md`。

    ⚠️ 这一层是补出来的缺口:检查器初版只扫 `*/*.md` + README ⇒ `tools/`、`.github/`、
    `.githooks/` **不在扫描范围**,于是它看不见**自己身边**的泄漏
    (实测:一个 `.sh` 的自测样本里写了另一个仓库名,检查器一声不吭)。
    """
    import subprocess
    try:                       # 只扫**入库**文件:未入库的本地文件(.kb-forbidden.txt 等)不上公网
        out = subprocess.run(["git", "-C", str(root), "ls-files"],
                             capture_output=True, text=True, check=True).stdout
        return [root / f for f in out.splitlines() if (root / f).is_file()]
    except Exception:          # 非 git 目录(如自检的临时样本)⇒ 退回文件系统遍历
        return [x for x in sorted(root.rglob("*"))
                if x.is_file() and ".git" not in x.parts and not x.name.startswith(".DS_Store")]


def _files_for_checks(root: Path) -> list[Path]:
    """参与内容检查的文件:所有篇 + 根 README。README 在第 5 条上豁免。"""
    out = _pian_files(root)
    readme = root / "README.md"
    if readme.is_file():
        out.append(readme)
    return out


def check(root: Path) -> list[str]:
    """返回违规清单(空 = 通过)。"""
    errs: list[str] = []

    # ① 目录与文件命名
    for d in sorted(p for p in root.iterdir() if p.is_dir() and not p.name.startswith(".")):
        if d.name in ("tools", ".github", ".githooks"):
            continue
        if not DIR_NAME_RE.match(d.name):
            errs.append(f"[命名] 区目录名不合规(应 `<字母>-<EnglishSlug><中文>`):{d.name}")

    pian = _pian_files(root)
    if not pian:
        errs.append("[结构] 未找到任何篇(*/<区>/<篇>.md)")

    seen_ids: dict[str, str] = {}
    for p in pian:
        rel = p.relative_to(root)
        text = p.read_text(encoding="utf-8")
        m = FILE_NAME_RE.match(p.name)
        if not m:
            errs.append(f"[命名] 篇文件名不合规(应 `<篇ID>-<english-slug><中文>.md`):{rel}")
            continue
        fid, slug, _cn = m.group(1), m.group(2), m.group(3)
        if not re.search(r"[A-Za-z]", slug):
            errs.append(f"[命名] 英文标识缺失(不便英文检索):{rel}")
        if p.parent.name[0] != fid[0]:
            errs.append(f"[归属] 篇 ID 与区不符:{rel}(篇 {fid} 在区 {p.parent.name})")
        head = PIAN_ID_RE.search(text)
        if not head:
            errs.append(f"[结构] 缺头部「篇 ID:`X#`」:{rel}")
        elif head.group(1) != fid:
            errs.append(f"[归属] 头部篇 ID 与文件名不一致:{rel}(头 {head.group(1)} / 名 {fid})")
        if fid in seen_ids:
            errs.append(f"[归属] 篇 ID 重复:{fid}({seen_ids[fid]} 与 {rel})")
        seen_ids[fid] = str(rel)

        # ① 五节
        for sec in REQUIRED_SECTIONS:
            if sec not in text:
                errs.append(f"[结构] 缺必备节「{sec}」:{rel}")
        if not any(a in text for a in SECTION_ALIASES["规则"]):
            errs.append(f"[结构] 缺「规则」节:{rel}")

        # ② 编号:格式、唯一、篇内从 1 连续
        nums = [int(n) for _f, n in RULE_RE.findall(text)]
        # "连续" = 篇内编号**集合**恰为 1..N(无缺口、无重复);
        # **不要求按文档顺序递增** —— 规则按主题归位是允许的(见 README §6)。
        if nums and sorted(nums) != list(range(1, len(nums) + 1)):
            errs.append(f"[编号] 篇内编号非 1..{len(nums)} 的连续集合(有缺口或重复):{rel} → {sorted(nums)}")
        ids = [f"{i}-R{n}" for i, n in RULE_RE.findall(text)]

        # ③ 路径(README 豁免:它必须举反例)


        # ④ 引用
        for stale in STALE_REF_RE.findall(text):
            errs.append(f"[引用] 出现「{stale}」式引用(应改用篇 ID):{rel}")
        for ref in set(MD_REF_RE.findall(text)):
            if ref == "README.md":
                continue
            if "/" in ref and not (root / ref).exists() and ref.startswith(("tools/", "docs/", "eval/")):
                errs.append(f"[引用] 指向库内不存在/库外的文件 `{ref}`:{rel}")

    extra_re = None
    fb = root / FORBIDDEN_FILE
    if fb.is_file():
        pats = [l.strip() for l in fb.read_text(encoding="utf-8").splitlines()
                if l.strip() and not l.startswith("#")]
        if pats:
            extra_re = re.compile("|".join(f"({x})" for x in pats))

    # ⑤ 全局唯一 + 公开卫生(**扫全部公开文件**,不只 .md)
    all_ids: dict[str, str] = {}
    for p in _published_files(root):
        rel = p.relative_to(root)
        if p.name == "README.md":
            # ⚠️ 豁免①:README 是**约束文件**,必须举反例(`docs/复盘/x.md` 这类)
            continue
        if rel.as_posix() == "tools/check_kb.py":
            # ⚠️ 豁免②:本检查器**自身**。它按定义就写着那些模式串与自测样本,
            # 否则会自己抓自己(实测:扩范围当轮即命中 8 处,全在本文件)。
            # 代价:本文件里的**真**泄漏不会被它自己发现 ⇒ 该文件改动时请人工过一眼。
            continue
        try:
            text = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for name, pat in PUBLIC_PATTERNS.items():
            hit = re.findall(pat, text)
            if hit:
                errs.append(f"[公开卫生] 命中{name}:{rel} → {sorted(set(hit))[:3]}")
        for hit in sorted({m for m in PATH_BAN_RE.findall(text)}):
            errs.append(f"[路径] 出现禁止的路径/项目名 `{hit}`:{rel}")
        if extra_re is not None and extra_re.search(text):
            errs.append(f"[公开卫生] 命中本地私有名单({FORBIDDEN_FILE}):{rel}")
    for p in _files_for_checks(root):
        text = p.read_text(encoding="utf-8")
        rel = p.relative_to(root)
        for fid, n in RULE_RE.findall(text):
            rid = f"{fid}-R{n}"
            where = str(rel)
            if rid in all_ids and not str(rel).startswith("README"):
                errs.append(f"[编号] 规则 ID 重复定义:{rid}({all_ids[rid]} 与 {where})")
            all_ids.setdefault(rid, where)

    return errs


# ── 自检(--self-test):突变验证 —— 每个检查都必须"能变红" ────────────────────
GOOD_PIAN = """# 测试篇

> **篇 ID:`A1`** · 区:`A-AgentSystem系统`
> 来源:某项目 · 2026-01-01 · 某次实战
> 编号:本库规则编号 = `<篇ID>-R<n>`

## 1. 一句话结论
结论。

## 3. 规则
### `A1-R1` · 规则一
**规则**:做 X。
**反例**:不做 X 的后果。
**正例**:这样做。

## 4. 适用场景与不适用场景
适用:A;不适用:B。

## 5. 来源
见上。

## 6. 怎么验证它被落地
**反检验**:违反它时,有什么会变红?
"""
GOOD_README = "# 约束\n> 读者 = AI Agent\n"

BAD_CASES = {
    "[结构]": {"A-AgentSystem系统/A1-x测试.md": GOOD_PIAN.replace("## 4. 适用场景与不适用场景", "## 4. 换了标题")},
    "[编号]": {"A-AgentSystem系统/A1-x测试.md": GOOD_PIAN.replace("`A1-R1`", "`A1-R2`")},
    # 无 ASCII 英文标识 ⇒ 命中 [命名](其余检查不受影响,故单独一案)
    "[命名]": {"A-AgentSystem系统/A1-测试.md": GOOD_PIAN},
    "[路径]": {"A-AgentSystem系统/A1-test测试.md": GOOD_PIAN + "\n见 `docs/复盘/x.md`\n"},
    "[引用]": {"A-AgentSystem系统/A1-test测试.md": GOOD_PIAN + "\n详见第 3 篇。\n"},
    # 通用模式(用「邮箱」家族走同一条代码路径;刻意避开任何"长得像密钥"的样式 ——
    # 假密钥样本会触发公网扫描器,也会让读者误以为库里有密钥)
    "[公开卫生]": {"A-AgentSystem系统/A1-test测试.md": GOOD_PIAN + "\n联系 someone@example.com。\n"},
    # 私有名单路径:样本自带一份 `.kb-forbidden.txt` ⇒ 必须被检出
    # 非 .md 文件(此前的扫描缺口)—— 违规写在 .sh 里也必须被抓到
    "[公开卫生]": {"tools/x.sh": "#!/bin/sh\n# contact someone@example.com\n"},
    "[公开卫生] 命中本地私有名单": {
        ".kb-forbidden.txt": "some-private-repo-name\n",
        "A-AgentSystem系统/A1-test测试.md": GOOD_PIAN + "\n来源:some-private-repo-name 的某轮。\n",
    },
}


def _mk(root: Path, files: dict[str, str]) -> None:
    for rel, content in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")


def self_test() -> int:
    fails = 0
    with tempfile.TemporaryDirectory() as td:
        good = Path(td) / "good"
        _mk(good, {"README.md": GOOD_README, "A-AgentSystem系统/A1-x测试.md": GOOD_PIAN,
                   "tools/x.sh": "#!/bin/sh\necho ok\n"})
        errs = check(good)
        if errs:
            fails += 1
            print("❌ 自检失败:合规样本被误判 →", errs[:2])
        else:
            print("✅ 合规样本:通过(无误报)")

    for expect, files in BAD_CASES.items():
        with tempfile.TemporaryDirectory() as td:
            bad = Path(td) / "bad"
            _mk(bad, {"README.md": GOOD_README, **files})
            errs = check(bad)
            if not errs or not any(expect in e for e in errs):
                fails += 1
                print(f"❌ 自检失败:违规样本未被检出({expect})→ {errs[:2]}")
            else:
                print(f"✅ 违规样本:被检出 {expect}")
    if fails:
        print(f"\n自检未通过:{fails} 项。**门禁没有防腐 —— 先修它,再谈用它。**")
        return 1
    print("\n自检通过:合规样本无误报,六类违规全部被检出(突变验证)。")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="check_kb", description="避坑库结构/卫生校验")
    ap.add_argument("--root", default=".", help="库根目录(默认当前目录)")
    ap.add_argument("--self-test", action="store_true", help="跑突变验证(检查器自身是否有防腐)")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test()
    root = Path(a.root).resolve()
    if not root.is_dir():
        print(f"用法错误:目录不存在 {root}", file=sys.stderr)
        return 2
    errs = check(root)
    if errs:
        print(f"✗ 避坑库校验未通过({len(errs)} 条):\n")
        for e in errs:
            print("  -", e)
        print("\n约束说明见 README.md §7(体例)/ §8(路径)/ §9(维护)。")
        return 1
    n = len(_pian_files(root))
    print(f"✅ 避坑库校验通过:{n} 篇,结构 / 编号 / 命名 / 路径 / 引用 / 公开卫生 全部合规。")
    return 0


if __name__ == "__main__":
    sys.exit(main())

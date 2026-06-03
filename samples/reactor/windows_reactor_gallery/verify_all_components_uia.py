#!/usr/bin/env python3
"""Sequential UI Automation verification for every reactor gallery control page.

The script:
  * launches the already-built gallery through `cjv exec`;
  * reads the gallery registry and matching reference pages;
  * navigates each category/control through UIA;
  * checks that the page rendered, sample cards are present, and no placeholder
    page or runtime error surfaced;
  * writes per-page UIA dumps plus screenshots for failed pages.
"""
from __future__ import annotations

import argparse
import csv
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent
WORKSPACE = ROOT.parent
REPO = WORKSPACE.parent
REF_ROOT = REPO / "ref" / "windows-rs" / "crates" / "samples" / "reactor" / "gallery" / "src" / "pages"
STAGE = WORKSPACE / ".generated" / "windows-app-sdk"
NAV = ROOT / "nav_select.ps1"
CAPTURE = ROOT / "capture_window.ps1"
TITLE = "Reactor WinUI Gallery"
TARGET = ROOT / "target" / "uia_all_components"
RUN_LOG = TARGET / "gallery_run.log"

CATEGORY_DIRS = {
    "Basic Input": "basic_input",
    "Collections": "collections",
    "Date and Time": "date_time",
    "Design Guidance": "design",
    "Dialogs and Flyouts": "dialogs",
    "Layout": "layout",
    "Media": "media",
    "Menus and Toolbars": "menus",
    "Navigation": "navigation",
    "Status and Info": "status",
    "Text": "text",
}

RUNTIME_ERROR_RE = re.compile(
    r"(E_NOINTERFACE|0x80004002|Unhandled|Exception|panic|setProp.*fail|failed\s+to|error)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class Control:
    title: str
    description: str
    category: str
    tag: str


@dataclass
class PageResult:
    control: Control
    ok: bool
    failures: list[str]
    nav_output: str
    uia_path: Path
    screenshot_path: Path | None
    observed_names: list[str]
    local_cards: list[str]
    ref_cards: list[str]


def run(cmd: list[str], *, cwd: Path | None = None, timeout: int = 60) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def find_exe() -> Path:
    override = os.environ.get("GALLERY_EXE")
    if override and Path(override).is_file():
        return Path(override)
    candidate = ROOT / "target" / "release" / "bin" / "main.exe"
    if candidate.is_file():
        return candidate
    for hit in (ROOT / "target").glob("**/main.exe"):
        return hit
    raise SystemExit("gallery exe not found; run `$env:cjHeapSize='32GB'; cjpm build -i` first")


def stage_runtime(exe_dir: Path) -> None:
    boot = STAGE / "Microsoft.WindowsAppRuntime.Bootstrap.dll"
    if not boot.is_file():
        raise SystemExit(f"missing staged bootstrap dll: {boot}")
    shutil.copy2(boot, exe_dir / boot.name)
    pri = STAGE / "resources.pri"
    if pri.is_file():
        shutil.copy2(pri, exe_dir / "resources.pri")
    # Stage the gallery PNG assets next to the exe so the card icons resolve:
    # assetUri() anchors to <exeDir>/assets (the deployed-package layout). The
    # raw target/release/bin output has no sibling assets/, so copy them here.
    assets_src = ROOT / "assets"
    if assets_src.is_dir():
        shutil.copytree(assets_src, exe_dir / "assets", dirs_exist_ok=True)


def parse_registry() -> list[Control]:
    text = (ROOT / "src" / "shared" / "registry.cj").read_text(encoding="utf-8")
    pattern = re.compile(
        r'ControlInfo\("([^"]+)",\s*"([^"]*)",\s*"([^"]+)",\s*"[^"]*",\s*"([^"]+)",\s*"[^"]*"\)'
    )
    controls = [Control(m.group(1), m.group(2), m.group(3), m.group(4)) for m in pattern.finditer(text)]
    if not controls:
        raise SystemExit("could not parse controls from registry.cj")
    return controls


def page_file(control: Control, suffix: str, base: Path) -> Path:
    category_dir = CATEGORY_DIRS[control.category]
    file_name = control.tag.replace("-", "_") + suffix
    return base / category_dir / file_name


def sample_titles_from(path: Path) -> list[str]:
    if not path.is_file():
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    return [decode_source_string(raw) for raw in re.findall(r'sample_card\(\s*"([^"]+)"', text)]


def decode_source_string(value: str) -> str:
    def unicode_repl(match: re.Match[str]) -> str:
        return chr(int(match.group(1), 16))

    value = re.sub(r"\\u\{([0-9a-fA-F]+)\}", unicode_repl, value)
    return (
        value.replace(r"\"", '"')
        .replace(r"\\", "\\")
        .replace(r"\n", "\n")
        .replace(r"\t", "\t")
    )


def ps(*args: str, timeout: int = 45) -> subprocess.CompletedProcess[str]:
    return run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", *args],
        timeout=timeout,
    )


def ps_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def navigate(control: Control, pause_ms: int, include_category: bool) -> str:
    items = f"{control.category}|{control.title}" if include_category else control.title
    primary = ps(
        "-File",
        str(NAV),
        "-TitleMatch",
        TITLE,
        "-Items",
        items,
        "-PauseMs",
        str(pause_ms),
        timeout=60,
    )
    primary_text = (primary.stdout or "") + (("\n[stderr]\n" + primary.stderr) if primary.stderr else "")
    if not any(marker in primary_text for marker in ("WINDOW_NOT_FOUND", "ITEM_NOT_FOUND", "NO_PATTERN")):
        return primary_text

    fallback_text = fallback_navigate(control, pause_ms, include_category)
    return primary_text + "\n--- FALLBACK_NAV ---\n" + fallback_text


def fallback_navigate(control: Control, pause_ms: int, include_category: bool) -> str:
    # nav_select.ps1 activates the named element itself. Category tiles expose
    # the visible title as a Text child, while the parent ListItem owns
    # SelectionItemPattern, so the fallback walks up to an activatable ancestor.
    script = r"""
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$Category = __CATEGORY__
$Leaf = __LEAF__
$PauseMs = __PAUSE_MS__
$IncludeCategory = __INCLUDE_CATEGORY__

$root = [System.Windows.Automation.AutomationElement]::RootElement
$windowCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window)
$windows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $windowCond)

$target = $null
foreach ($w in $windows) {
    $n = $w.Current.Name
    if ($n -and $n.IndexOf("Reactor WinUI Gallery", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $target = $w
        break
    }
}
if ($null -eq $target) {
    Write-Output "WINDOW_NOT_FOUND"
    exit 1
}
Write-Output ("FOUND_WINDOW=" + $target.Current.Name)

$walker = [System.Windows.Automation.TreeWalker]::RawViewWalker

function ActivateElementOrAncestor($element, $name) {
    $current = $element
    $depth = 0
    while ($null -ne $current -and $depth -lt 12) {
        try {
            $sel = $current.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
            $sel.Select()
            Write-Output ("SELECTED name='" + $name + "' via=" + $current.Current.ControlType.ProgrammaticName + " actual='" + $current.Current.Name + "'")
            return $true
        } catch {
        }
        try {
            $inv = $current.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $inv.Invoke()
            Write-Output ("INVOKED name='" + $name + "' via=" + $current.Current.ControlType.ProgrammaticName + " actual='" + $current.Current.Name + "'")
            return $true
        } catch {
        }
        $current = $walker.GetParent($current)
        $depth += 1
    }
    return $false
}

function SelectByName($name) {
    $nameCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty, $name)
    $matches = $target.FindAll([System.Windows.Automation.TreeScope]::Descendants, $nameCond)
    if ($matches.Count -gt 0) {
        for ($i = 0; $i -lt $matches.Count; $i++) {
            if (ActivateElementOrAncestor $matches.Item($i) $name) {
                return
            }
        }
    }

    $listItemCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::ListItem)
    $listItems = $target.FindAll([System.Windows.Automation.TreeScope]::Descendants, $listItemCond)
    for ($i = 0; $i -lt $listItems.Count; $i++) {
        $li = $listItems.Item($i)
        if ($li.Current.Name -eq $name) {
            if (ActivateElementOrAncestor $li $name) { return }
        } else {
            $child = $li.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $nameCond)
            if ($null -ne $child) {
                if (ActivateElementOrAncestor $li $name) { return }
            }
        }
    }

    if ($matches.Count -eq 0) {
        Write-Output ("ITEM_NOT_FOUND name='" + $name + "'")
    } else {
        Write-Output ("NO_PATTERN name='" + $name + "'")
    }
}

if ($IncludeCategory) {
    SelectByName $Category
    Start-Sleep -Milliseconds $PauseMs
}
SelectByName $Leaf
Start-Sleep -Milliseconds $PauseMs
Write-Output "NAV_DONE"
"""
    script = (
        script.replace("__CATEGORY__", ps_literal(control.category))
        .replace("__LEAF__", ps_literal(control.title))
        .replace("__PAUSE_MS__", str(pause_ms))
        .replace("__INCLUDE_CATEGORY__", "$true" if include_category else "$false")
    )
    result = ps("-Command", script, timeout=60)
    return (result.stdout or "") + (("\n[stderr]\n" + result.stderr) if result.stderr else "")


def dump_uia() -> list[dict[str, str]]:
    script = r"""
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window)
$windows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)

$target = $null
foreach ($w in $windows) {
    $n = $w.Current.Name
    if ($n -and $n.IndexOf("Reactor WinUI Gallery", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $target = $w
        break
    }
}
if ($null -eq $target) {
    Write-Output "WINDOW_NOT_FOUND"
    exit 2
}

Write-Output ("WINDOW`t" + $target.Current.ControlType.ProgrammaticName + "`tFalse`t" + $target.Current.IsEnabled + "`t`t" + $target.Current.Name + "`t")
$all = $target.FindAll([System.Windows.Automation.TreeScope]::Descendants,
    [System.Windows.Automation.Condition]::TrueCondition)
for ($i = 0; $i -lt $all.Count; $i++) {
    $e = $all.Item($i)
    $c = $e.Current
    $selected = ""
    try {
        $sel = $e.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
        $selected = [string]$sel.Current.IsSelected
    } catch {
        $selected = ""
    }
    $value = ""
    try {
        $vp = $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        $value = $vp.Current.Value
    } catch {
        $value = ""
    }
    $name = ""
    if ($null -ne $c.Name) { $name = $c.Name.Replace("`t", " ").Replace("`r", " ").Replace("`n", " ") }
    if ($null -ne $value) { $value = $value.Replace("`t", " ").Replace("`r", " ").Replace("`n", " ") }
    Write-Output ([string]$i + "`t" + $c.ControlType.ProgrammaticName + "`t" + $c.IsOffscreen + "`t" + $c.IsEnabled + "`t" + $selected + "`t" + $name + "`t" + $value)
}
"""
    result = ps("-Command", script, timeout=60)
    text = (result.stdout or "") + (("\n[stderr]\n" + result.stderr) if result.stderr else "")
    rows: list[dict[str, str]] = []
    for row in csv.reader(text.splitlines(), delimiter="\t"):
        if not row:
            continue
        if row[0] == "WINDOW_NOT_FOUND":
            rows.append({"index": "ERR", "type": "WINDOW_NOT_FOUND", "name": "", "value": ""})
            continue
        while len(row) < 7:
            row.append("")
        rows.append(
            {
                "index": row[0],
                "type": row[1],
                "offscreen": row[2],
                "enabled": row[3],
                "selected": row[4],
                "name": row[5],
                "value": row[6],
            }
        )
    return rows


def write_uia_dump(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["index", "type", "offscreen", "enabled", "selected", "name", "value"])
        writer.writeheader()
        writer.writerows(rows)


def capture_page(control: Control) -> Path:
    safe = control.tag.replace("-", "_")
    out = TARGET / f"{safe}.png"
    ps(
        "-File",
        str(CAPTURE),
        "-TitleMatch",
        TITLE,
        "-Out",
        str(out),
        "-W",
        "1100",
        "-H",
        "1600",
        "-X",
        "20",
        "-Y",
        "0",
        timeout=60,
    )
    return out


def check_page(control: Control, rows: list[dict[str, str]], local_cards: list[str], ref_cards: list[str], nav_output: str) -> list[str]:
    failures: list[str] = []
    names = [r.get("name", "") for r in rows if r.get("name")]
    values = [r.get("value", "") for r in rows if r.get("value")]
    all_text = "\n".join(names + values)
    fallback_succeeded = "--- FALLBACK_NAV ---" in nav_output and "NAV_DONE" in nav_output.split("--- FALLBACK_NAV ---", 1)[1]

    if "WINDOW_NOT_FOUND" in nav_output or any(r.get("type") == "WINDOW_NOT_FOUND" for r in rows):
        failures.append("window not found")
    if not fallback_succeeded and ("ITEM_NOT_FOUND" in nav_output or "NO_PATTERN" in nav_output):
        failures.append("navigation item was not selectable")
    if "Sample page coming soon." in all_text:
        failures.append("placeholder page rendered")

    # The page title should be present at least once. Some navigation states also
    # expose the selected leaf item, but card-grid navigation does not keep that
    # leaf in the UIA tree, so requiring two occurrences would be a false fail.
    title_count = sum(1 for n in names if n == control.title)
    if title_count < 1:
        failures.append(f"page header not observed for {control.title!r} (title count={title_count})")

    if ref_cards and len(local_cards) < len(ref_cards):
        failures.append(f"local sample card count {len(local_cards)} is less than reference count {len(ref_cards)}")

    if local_cards:
        missing_cards = [title for title in local_cards if title not in all_text]
        if missing_cards:
            failures.append("sample card title(s) missing from UIA tree: " + "; ".join(missing_cards[:4]))
        if "Source code" not in all_text:
            failures.append("Source code expander not observed")
    elif ref_cards:
        failures.append("no local sample cards parsed from page source")

    return failures


def scan_runtime_log() -> list[str]:
    if not RUN_LOG.is_file():
        return []
    lines = RUN_LOG.read_text(encoding="utf-8", errors="replace").splitlines()
    return [line for line in lines if RUNTIME_ERROR_RE.search(line)]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pause-ms", type=int, default=950, help="delay after each UIA selection")
    parser.add_argument("--startup-s", type=float, default=8.0, help="delay after launching the app")
    parser.add_argument("--capture-all", action="store_true", help="capture every page, not just failures")
    parser.add_argument("--limit", type=int, default=0, help="only verify the first N controls")
    parser.add_argument("--start-tag", default="", help="skip controls before this registry tag")
    parser.add_argument("--only-tag", default="", help="verify only this registry tag")
    args = parser.parse_args()

    TARGET.mkdir(parents=True, exist_ok=True)
    controls = parse_registry()
    if args.only_tag:
        controls = [control for control in controls if control.tag == args.only_tag]
    elif args.start_tag:
        start = next((i for i, control in enumerate(controls) if control.tag == args.start_tag), None)
        if start is None:
            raise SystemExit(f"unknown --start-tag {args.start_tag!r}")
        controls = controls[start:]
    if args.limit:
        controls = controls[: args.limit]

    exe = find_exe()
    exe_dir = exe.parent
    stage_runtime(exe_dir)

    # The reactor render loop runs on the UI cjthread with WinUI's native layout /
    # message-pump frames beneath it; the default cjthread stack is too small for
    # that depth (the Rust reference's main thread has an 8 MB stack by default),
    # so deep navigation eventually throws StackOverflowError. Give the UI thread a
    # generous stack — the idiomatic Cangjie runtime config for stack-heavy work.
    os.environ.setdefault("cjStackSize", "32mb")

    log = RUN_LOG.open("wb")
    proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir), stdout=log, stderr=subprocess.STDOUT)
    print(f"launched pid={proc.pid}", flush=True)
    time.sleep(args.startup_s)

    results: list[PageResult] = []
    last_category = ""
    try:
        for idx, control in enumerate(controls, start=1):
            local_path = page_file(control, ".cj", ROOT / "src" / "pages")
            ref_path = page_file(control, ".rs", REF_ROOT)
            local_cards = sample_titles_from(local_path)
            ref_cards = sample_titles_from(ref_path)

            print(f"[{idx:02d}/{len(controls):02d}] {control.category} / {control.title}", flush=True)
            include_category = control.category != last_category
            nav_output = navigate(control, args.pause_ms, include_category)
            last_category = control.category
            (TARGET / f"{control.tag.replace('-', '_')}.nav.txt").write_text(nav_output, encoding="utf-8")
            time.sleep(0.25)
            rows = dump_uia()
            uia_path = TARGET / f"{control.tag.replace('-', '_')}.uia.csv"
            write_uia_dump(uia_path, rows)
            failures = check_page(control, rows, local_cards, ref_cards, nav_output)
            screenshot_path: Path | None = None
            if failures or args.capture_all:
                screenshot_path = capture_page(control)
            ok = not failures
            if ok:
                print("  OK", flush=True)
            else:
                for failure in failures:
                    print(f"  FAIL: {failure}", flush=True)
            results.append(
                PageResult(
                    control=control,
                    ok=ok,
                    failures=failures,
                    nav_output=nav_output,
                    uia_path=uia_path,
                    screenshot_path=screenshot_path,
                    observed_names=[r.get("name", "") for r in rows if r.get("name")],
                    local_cards=local_cards,
                    ref_cards=ref_cards,
                )
            )
            if proc.poll() is not None:
                msg = f"process exited early code={proc.returncode}"
                print("PROCESS_EXITED_EARLY code=" + str(proc.returncode), flush=True)
                if results:
                    results[-1].ok = False
                    results[-1].failures.append(msg)
                break
    finally:
        try:
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
            proc.wait(timeout=10)
        except Exception:
            pass
        log.close()

    runtime_hits = scan_runtime_log()
    summary = TARGET / "summary.txt"
    with summary.open("w", encoding="utf-8") as f:
        f.write(f"controls={len(results)} failures={sum(1 for r in results if not r.ok)}\n")
        for result in results:
            status = "OK" if result.ok else "FAIL"
            f.write(f"{status}\t{result.control.category}\t{result.control.title}\t{result.control.tag}\n")
            if not result.ok:
                for failure in result.failures:
                    f.write(f"  - {failure}\n")
                f.write(f"  uia={result.uia_path}\n")
                if result.screenshot_path:
                    f.write(f"  screenshot={result.screenshot_path}\n")
        if runtime_hits:
            f.write("\nruntime log hits:\n")
            for line in runtime_hits[:80]:
                f.write(line + "\n")

    failed = [r for r in results if not r.ok]
    print(f"SUMMARY controls={len(results)} failures={len(failed)} runtime_log_hits={len(runtime_hits)}", flush=True)
    print(f"SUMMARY_FILE={summary}", flush=True)
    if runtime_hits:
        print("RUNTIME_LOG_HITS:")
        for line in runtime_hits[:20]:
            print("  " + line)
    return 1 if failed or runtime_hits else 0


if __name__ == "__main__":
    raise SystemExit(main())

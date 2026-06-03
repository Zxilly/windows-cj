#!/usr/bin/env python3
"""Functional (interaction) verification for reactor gallery controls.

Where verify_all_components_uia.py checks that each page *renders* (structural
sweep), this harness *drives* each interactive control through a UI Automation
pattern and asserts the observable effect — the state text the page shows in
response. It reuses the launch / navigation / UIA-dump infrastructure from
verify_all_components_uia.py and adds an `interact()` step plus a spec-driven
before/after assertion.

Specs live in functional_specs.json: a list of per-control entries, each with a
list of `checks`. A check = {find a target, apply an action, assert the page's
text changed as expected}. Controls with no driveable+observable behaviour
(purely visual: progress ring, type ramp, design guidance) are listed with an
empty `checks` array and reported as SKIP, not FAIL.

Run:
  $env:cjHeapSize='32GB'; $env:cjStackSize='32mb'; python verify_functional_uia.py
  python verify_functional_uia.py --only-tag button      # one control
  python verify_functional_uia.py --only-tag slider --keep-open
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

# Reuse the proven infrastructure from the structural sweep.
import verify_all_components_uia as sweep

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent
SPECS_FILE = ROOT / "functional_specs.json"
TARGET = ROOT / "target" / "uia_functional"
RUN_LOG = TARGET / "gallery_run.log"


@dataclass
class CheckResult:
    desc: str
    ok: bool
    detail: str


@dataclass
class ControlResult:
    tag: str
    title: str
    category: str
    status: str  # PASS | FAIL | SKIP
    checks: list[CheckResult] = field(default_factory=list)
    nav_note: str = ""


def interact(find: dict, action: str, param: str | None) -> str:
    """Find a target inside the gallery window and apply a UIA pattern to it.

    find: {name?, name_contains?, type?, index?}
    action: invoke | toggle | setrange | setvalue | selectitem | expand | collapse
    Returns the raw PS output (markers: INTERACT_OK / INTERACT_FAIL / TARGET_NOT_FOUND).
    """
    script = r"""
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$Name = __NAME__
$NameContains = __NAME_CONTAINS__
$TypeName = __TYPE__
$Index = __INDEX__
$Action = __ACTION__
$Param = __PARAM__

$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window)
$windows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
$target = $null
foreach ($w in $windows) {
    $n = $w.Current.Name
    if ($n -and $n.IndexOf("Reactor WinUI Gallery", [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $target = $w; break
    }
}
if ($null -eq $target) { Write-Output "WINDOW_NOT_FOUND"; exit 1 }

$all = $target.FindAll([System.Windows.Automation.TreeScope]::Descendants,
    [System.Windows.Automation.Condition]::TrueCondition)

# Collect candidates matching the (optional) name + (optional) control type.
$cands = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $all.Count; $i++) {
    $e = $all.Item($i); $c = $e.Current
    $okName = $true
    if ($Name -ne "") { $okName = ($c.Name -eq $Name) }
    elseif ($NameContains -ne "") { $okName = ($c.Name -ne $null -and $c.Name.IndexOf($NameContains, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) }
    $okType = $true
    if ($TypeName -ne "") { $okType = ($c.ControlType.ProgrammaticName -eq ("ControlType." + $TypeName)) }
    if ($okName -and $okType) { [void]$cands.Add($e) }
}
if ($cands.Count -eq 0) {
    # Fallback: icon+text controls expose an empty own Name (their visible label is a
    # descendant Text). Match a candidate (filtered by type) whose DESCENDANT carries the
    # requested name / name_contains, so e.g. an icon+text "Delete item" button is reachable.
    $needle = if ($Name -ne "") { $Name } else { $NameContains }
    if ($needle -ne "") {
        for ($i = 0; $i -lt $all.Count; $i++) {
            $e = $all.Item($i); $c = $e.Current
            if ($TypeName -ne "" -and $c.ControlType.ProgrammaticName -ne ("ControlType." + $TypeName)) { continue }
            $nc = New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::NameProperty, $needle)
            $hit = $e.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $nc)
            if ($null -eq $hit -and $NameContains -ne "") {
                $tc = New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [System.Windows.Automation.ControlType]::Text)
                $texts = $e.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)
                for ($k = 0; $k -lt $texts.Count; $k++) {
                    $tn = $texts.Item($k).Current.Name
                    if ($tn -and $tn.IndexOf($NameContains, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hit = $e; break }
                }
            }
            if ($null -ne $hit) { [void]$cands.Add($e) }
        }
    }
}
if ($cands.Count -le $Index) {
    Write-Output ("TARGET_NOT_FOUND name='" + $Name + "' contains='" + $NameContains + "' type='" + $TypeName + "' matched=" + $cands.Count)
    exit 2
}
$el = $cands[$Index]
Write-Output ("TARGET name='" + $el.Current.Name + "' type=" + $el.Current.ControlType.ProgrammaticName + " enabled=" + $el.Current.IsEnabled + " offscreen=" + $el.Current.IsOffscreen)

# Best-effort scroll into view so patterns that need realization succeed.
try {
    $si = $el.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern)
    $si.ScrollIntoView()
    Start-Sleep -Milliseconds 200
} catch {}

try {
    switch ($Action) {
        "invoke" {
            $p = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $p.Invoke()
        }
        "toggle" {
            $p = $el.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
            $p.Toggle()
        }
        "setrange" {
            $p = $el.GetCurrentPattern([System.Windows.Automation.RangeValuePattern]::Pattern)
            $p.SetValue([double]$Param)
        }
        "setvalue" {
            $p = $el.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
            $p.SetValue([string]$Param)
            # Commit: inputs like NumberBox raise their change event on Enter/blur, not on a raw
            # ValuePattern write. Move keyboard focus off the edit to trigger the commit. Pure UIA
            # (no foreground dependency); harmless for plain TextBoxes.
            try {
                $btnCond = New-Object System.Windows.Automation.PropertyCondition(
                    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                    [System.Windows.Automation.ControlType]::Button)
                $blur = $target.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
                if ($null -ne $blur) { $blur.SetFocus(); Start-Sleep -Milliseconds 150 }
            } catch {}
        }
        "selectitem" {
            $p = $el.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
            $p.Select()
        }
        "expand" {
            $p = $el.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
            $p.Expand()
        }
        "collapse" {
            $p = $el.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
            $p.Collapse()
        }
        default { Write-Output ("INTERACT_FAIL unknown action " + $Action); exit 3 }
    }
    Write-Output "INTERACT_OK"
} catch {
    Write-Output ("INTERACT_FAIL " + $_.Exception.Message)
    exit 4
}
"""
    script = (
        script.replace("__NAME__", sweep.ps_literal(find.get("name", "")))
        .replace("__NAME_CONTAINS__", sweep.ps_literal(find.get("name_contains", "")))
        .replace("__TYPE__", sweep.ps_literal(find.get("type", "")))
        .replace("__INDEX__", str(int(find.get("index", 0))))
        .replace("__ACTION__", sweep.ps_literal(action))
        .replace("__PARAM__", sweep.ps_literal("" if param is None else str(param)))
    )
    result = sweep.ps("-Command", script, timeout=60)
    return (result.stdout or "") + (("\n[stderr]\n" + result.stderr) if result.stderr else "")


def dump_text() -> str:
    rows = sweep.dump_uia()
    names = [r.get("name", "") for r in rows if r.get("name")]
    values = [r.get("value", "") for r in rows if r.get("value")]
    return "\n".join(names + values)


def run_check(check: dict, pause_ms: int, log_dir: Path, tag: str, idx: int) -> CheckResult:
    desc = check.get("desc", f"check {idx}")
    before = dump_text()
    inter = interact(check["find"], check["action"], check.get("param"))
    (log_dir / f"{tag}.check{idx}.interact.txt").write_text(inter, encoding="utf-8")
    time.sleep(pause_ms / 1000.0)
    after = dump_text()
    (log_dir / f"{tag}.check{idx}.after.txt").write_text(after, encoding="utf-8")

    if "TARGET_NOT_FOUND" in inter:
        return CheckResult(desc, False, "target not found: " + inter.strip().splitlines()[-1])
    if "WINDOW_NOT_FOUND" in inter:
        return CheckResult(desc, False, "gallery window not found")
    if "INTERACT_FAIL" in inter:
        fail_line = next((l for l in inter.splitlines() if "INTERACT_FAIL" in l), "INTERACT_FAIL")
        return CheckResult(desc, False, "interaction failed: " + fail_line)
    if "INTERACT_OK" not in inter:
        return CheckResult(desc, False, "interaction did not complete: " + inter.strip()[:200])

    problems: list[str] = []
    for needle in check.get("expect_present", []):
        if needle not in after:
            problems.append(f"expected text not present after: {needle!r}")
    for needle in check.get("expect_absent", []):
        if needle in after:
            problems.append(f"text expected to disappear is still present: {needle!r}")
    # Optional: assert that the named state text actually changed (caught no-op handlers).
    changed_marker = check.get("expect_changed_from")
    if changed_marker is not None and changed_marker in after and not check.get("expect_present"):
        problems.append(f"state text did not change from baseline {changed_marker!r}")

    if problems:
        return CheckResult(desc, False, "; ".join(problems))
    return CheckResult(desc, True, "ok")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pause-ms", type=int, default=900)
    parser.add_argument("--startup-s", type=float, default=8.0)
    parser.add_argument("--only-tag", default="")
    parser.add_argument("--keep-open", action="store_true", help="do not kill the gallery on exit")
    parser.add_argument("--no-always-category", dest="always_category", action="store_false", default=True,
                        help="opt out of re-selecting the category before every leaf (default on; "
                             "re-selecting is robust against collapsed nav groups)")
    args = parser.parse_args()

    TARGET.mkdir(parents=True, exist_ok=True)
    specs = json.loads(SPECS_FILE.read_text(encoding="utf-8"))
    if args.only_tag:
        specs = [s for s in specs if s["tag"] == args.only_tag]
        if not specs:
            raise SystemExit(f"no spec for tag {args.only_tag!r}")

    # Map registry metadata (category/title) by tag for navigation.
    controls = {c.tag: c for c in sweep.parse_registry()}

    exe = sweep.find_exe()
    exe_dir = exe.parent
    sweep.stage_runtime(exe_dir)
    import os
    os.environ.setdefault("cjStackSize", "32mb")

    log = RUN_LOG.open("wb")
    proc = subprocess.Popen(["cjv", "exec", str(exe)], cwd=str(exe_dir), stdout=log, stderr=subprocess.STDOUT)
    print(f"launched pid={proc.pid}", flush=True)
    time.sleep(args.startup_s)

    results: list[ControlResult] = []
    last_category = ""
    try:
        for i, spec in enumerate(specs, start=1):
            tag = spec["tag"]
            control = controls.get(tag)
            if control is None:
                print(f"[{i:02d}] {tag}: NO REGISTRY ENTRY", flush=True)
                continue
            print(f"[{i:02d}/{len(specs):02d}] {control.category} / {control.title}", flush=True)
            include_category = args.always_category or (control.category != last_category)
            nav_output = sweep.navigate(control, args.pause_ms, include_category)
            last_category = control.category
            time.sleep(0.3)

            checks = spec.get("checks", [])
            if not checks:
                print(f"  SKIP ({spec.get('skip_reason', 'no functional assertion')})", flush=True)
                results.append(ControlResult(tag, control.title, control.category, "SKIP",
                                             nav_note=spec.get("skip_reason", "")))
                if proc.poll() is not None:
                    print("PROCESS_EXITED_EARLY", flush=True); break
                continue

            def run_all_checks() -> list[CheckResult]:
                crs: list[CheckResult] = []
                for ci, check in enumerate(checks, start=1):
                    cr = run_check(check, args.pause_ms, TARGET, tag, ci)
                    mark = "ok" if cr.ok else "FAIL"
                    print(f"    [{mark}] {cr.desc}: {cr.detail}", flush=True)
                    crs.append(cr)
                return crs

            check_results = run_all_checks()
            # Retry once on a transient nav/realization race: the sequential sweep occasionally
            # interacts before a freshly navigated page has realized its controls, surfacing a
            # spurious TARGET_NOT_FOUND / window-not-found. Re-navigate (a fresh page also resets
            # state, which the state-aware specs assume) and re-run this control's checks once.
            if any((not c.ok) and ("target not found" in c.detail or "window not found" in c.detail)
                   for c in check_results):
                print("    (transient target miss -> re-navigating and retrying once)", flush=True)
                sweep.navigate(control, args.pause_ms, True)
                time.sleep(1.2)
                check_results = run_all_checks()

            status = "PASS" if all(c.ok for c in check_results) else "FAIL"
            results.append(ControlResult(tag, control.title, control.category, status, check_results))
            print(f"  {status}", flush=True)

            if proc.poll() is not None:
                print("PROCESS_EXITED_EARLY code=" + str(proc.returncode), flush=True)
                results.append(ControlResult(tag, control.title, control.category, "FAIL",
                                             nav_note="process exited early"))
                break
    finally:
        if not args.keep_open:
            try:
                subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
                proc.wait(timeout=10)
            except Exception:
                pass
        log.close()

    runtime_hits = sweep.scan_runtime_log() if RUN_LOG.is_file() else []

    npass = sum(1 for r in results if r.status == "PASS")
    nfail = sum(1 for r in results if r.status == "FAIL")
    nskip = sum(1 for r in results if r.status == "SKIP")
    summary = TARGET / "summary.txt"
    with summary.open("w", encoding="utf-8") as f:
        f.write(f"controls={len(results)} pass={npass} fail={nfail} skip={nskip} runtime_log_hits={len(runtime_hits)}\n")
        for r in results:
            f.write(f"[{r.status}] {r.category} / {r.title}\n")
            for c in r.checks:
                f.write(f"    [{'ok' if c.ok else 'FAIL'}] {c.desc}: {c.detail}\n")
            if r.nav_note:
                f.write(f"    note: {r.nav_note}\n")
        if runtime_hits:
            f.write("RUNTIME LOG HITS:\n")
            for h in runtime_hits[:40]:
                f.write("  " + h + "\n")

    print(f"\nSUMMARY pass={npass} fail={nfail} skip={nskip} runtime_log_hits={len(runtime_hits)}", flush=True)
    print(f"SUMMARY_FILE={summary}", flush=True)
    return 1 if nfail else 0


if __name__ == "__main__":
    raise SystemExit(main())

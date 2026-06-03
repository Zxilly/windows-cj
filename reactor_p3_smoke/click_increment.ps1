param(
    [string]$TitleMatch = "Reactor P3 Counter",
    [string]$ButtonName = "increment",
    [int]$Times = 1
)

# Use UI Automation to find the WinUI window by title, locate the "increment"
# button by its name, and invoke it. WinUI3 content is exposed to UIA even when
# screen capture struggles, so this reliably exercises the Click → re-render path.

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement

# Find the top-level window whose Name contains the title match.
$cond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window)
$windows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)

$target = $null
foreach ($w in $windows) {
    $n = $w.Current.Name
    if ($n -and $n.IndexOf($TitleMatch, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $target = $w; break }
}
if ($null -eq $target) { Write-Output "WINDOW_NOT_FOUND"; exit 1 }
Write-Output ("FOUND_WINDOW=" + $target.Current.Name)

# Find the button by Name anywhere in the subtree.
$btnCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::NameProperty, $ButtonName)
$btn = $target.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
if ($null -eq $btn) {
    Write-Output "BUTTON_NOT_FOUND_BY_NAME; dumping descendants:"
    $all = $target.FindAll([System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition)
    foreach ($e in $all) { Write-Output ("  ELEM ct=" + $e.Current.ControlType.ProgrammaticName + " name='" + $e.Current.Name + "'") }
    exit 2
}
Write-Output ("FOUND_BUTTON=" + $btn.Current.Name)

for ($i = 0; $i -lt $Times; $i++) {
    $invoke = $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $invoke.Invoke()
    Write-Output ("INVOKED #" + ($i+1))
    Start-Sleep -Milliseconds 400
}

# Read back any TextBlock-like element to confirm the count text.
$txtCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Text)
$texts = $target.FindAll([System.Windows.Automation.TreeScope]::Descendants, $txtCond)
foreach ($t in $texts) { Write-Output ("TEXT='" + $t.Current.Name + "'") }

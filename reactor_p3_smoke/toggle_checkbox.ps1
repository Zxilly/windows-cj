param(
    [string]$TitleMatch = "Reactor P3 Counter",
    [string]$CheckBoxName = "enable feature"
)

# UI Automation: find the WinUI window, locate the "enable feature" CheckBox by
# name, fire its Toggle pattern (a CheckedChanged event, NOT a Click), then read
# back every Text element so we can confirm the status TextBlock re-rendered.

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
    if ($n -and $n.IndexOf($TitleMatch, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $target = $w; break }
}
if ($null -eq $target) { Write-Output "WINDOW_NOT_FOUND"; exit 1 }
Write-Output ("FOUND_WINDOW=" + $target.Current.Name)

# Locate the CheckBox by its accessible name.
$cbCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::NameProperty, $CheckBoxName)
$cb = $target.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cbCond)
if ($null -eq $cb) { Write-Output "CHECKBOX_NOT_FOUND"; exit 2 }
Write-Output ("FOUND_CHECKBOX=" + $cb.Current.Name)

$toggle = $cb.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
Write-Output ("TOGGLE_STATE_BEFORE=" + $toggle.Current.ToggleState)
$toggle.Toggle()
Start-Sleep -Milliseconds 600
$toggle2 = $cb.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
Write-Output ("TOGGLE_STATE_AFTER=" + $toggle2.Current.ToggleState)

# Read back all Text elements to confirm the status TextBlock updated.
$txtCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Text)
$texts = $target.FindAll([System.Windows.Automation.TreeScope]::Descendants, $txtCond)
foreach ($t in $texts) { Write-Output ("TEXT='" + $t.Current.Name + "'") }

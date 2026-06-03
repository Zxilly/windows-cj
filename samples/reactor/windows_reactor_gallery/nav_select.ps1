param(
    [string]$TitleMatch = "Reactor WinUI Gallery",
    # Pipe-delimited list of NavigationViewItem names to select in order, e.g.
    # "Basic Input|Button". Passed as one token so it survives -File argv binding.
    [Parameter(Mandatory=$true)][string]$Items,
    [int]$PauseMs = 1500
)

$ItemList = $Items.Split('|')

# Drive NavigationView navigation deterministically via UI Automation: for each
# name in $Items, find the NavigationViewItem by Name anywhere in the window
# subtree and Select() it through SelectionItemPattern. WinUI3 content is exposed
# to UIA even when screen capture struggles, so this reliably exercises the
# selection-changed -> re-render path without relying on mouse coordinates.

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

foreach ($name in $ItemList) {
    $itemCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty, $name)
    $item = $target.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $itemCond)
    if ($null -eq $item) {
        Write-Output ("ITEM_NOT_FOUND name='" + $name + "'")
        continue
    }
    $sel = $null
    try {
        $sel = $item.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
    } catch {
        $sel = $null
    }
    if ($null -ne $sel) {
        $sel.Select()
        Write-Output ("SELECTED name='" + $name + "' ct=" + $item.Current.ControlType.ProgrammaticName)
    } else {
        # Fall back to Invoke for items that are not selectable (rare).
        try {
            $inv = $item.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
            $inv.Invoke()
            Write-Output ("INVOKED name='" + $name + "'")
        } catch {
            Write-Output ("NO_PATTERN name='" + $name + "'")
        }
    }
    Start-Sleep -Milliseconds $PauseMs
}
Write-Output "NAV_DONE"

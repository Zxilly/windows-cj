package windows_core

import windows_interface as windows_interface
// Intentional public compatibility surface for scoped interface helpers that
// now live in windows_interface. Keep these re-exports stable for existing
// windows_core imports.
public import windows_interface.{
    InterfaceSlotInfo,
    InterfaceResource,
    createInterfaceResource,
    createInterfaceResourceFromTarget,
    lookupInterfaceTarget
}

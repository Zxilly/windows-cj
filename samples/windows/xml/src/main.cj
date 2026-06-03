package windows_sample_xml

import windows_sample_xml_bindings.Data.Xml.Dom.XmlDocument
import windows_core

// ============================================================================
// xml — behaviour-equivalent port of the reference sample.
//
// Activates the Windows.Data.Xml.Dom.XmlDocument WinRT runtime class, parses an
// XML fragment with LoadXml, then reads the document's root element and prints
// its NodeName and InnerText. The reference asserts the node name is "html" and
// debug-prints the inner text (quoted), e.g.  "hello world".
//
// Paradigm notes (Cangjie vs the reference language):
//   • WinRT runtime classes are projected as GC classes that extend
//     InterfaceWrapperBase (a Resource); their COM lifetime is released by the
//     ~init finalizer / try-with-resource close(). No manual AddRef/Release.
//   • The generated runtime class only surfaces methods of its *default*
//     interface (IXmlDocument: Create*, DocumentElement, ...). The remaining
//     interfaces (IXmlDocumentIO::LoadXml, IXmlNode::NodeName,
//     IXmlNodeSerializer::InnerText) are reached with the generated interface
//     casts (asIXmlDocumentIO / asIXmlNode / asIXmlNodeSerializer) and their
//     raw ABI methods, which return a rich HRESULT to .check().
//   • There is no compile-time h!"..." literal; an HSTRING is built at runtime
//     from a Cangjie String (HString(String)) — behaviourally identical: a
//     UTF-16 WinRT string handed to the same ABI slot.
//   • A try-with-resource expression has type Unit, so HSTRING out-params are
//     captured into outer `var`s and consumed with HString.fromSystemHandleTake,
//     which takes ownership of and frees the system handle.
// ============================================================================

main(): Int64 {
    try {
        // XmlDocument::new() — activate the runtime class via its factory.
        try (doc = XmlDocument.new()) {
            // doc.LoadXml(h!("<html>hello world</html>")) — pass the XML as an
            // HSTRING through the IXmlDocumentIO ABI slot. The input HString must
            // stay alive across the call, so it is the try-resource here.
            try (xml = windows_core.HString("<html>hello world</html>")) {
                try (io = doc.asIXmlDocumentIO()) {
                    let hr = unsafe { io.LoadXml(xml.asRaw()) }
                    hr.check()
                }
            }

            // doc.DocumentElement() — a projected default-interface property.
            try (root = doc.DocumentElement) {
                // root.NodeName()? — IXmlNode::NodeName, out HSTRING.
                var nodeName = windows_core.HString()
                try (node = root.asIXmlNode()) {
                    var out = CPointer<Unit>()
                    let hr = unsafe { node.NodeName(CPointer<CPointer<Unit>>(inout out)) }
                    hr.check()
                    nodeName = windows_core.HString.fromSystemHandleTake(out)
                }

                // assert!(root.NodeName()? == "html")
                if (nodeName != "html") {
                    eprintln("expected node name 'html', got '${nodeName}'")
                    return 1
                }

                // root.InnerText()? — IXmlNodeSerializer::InnerText, out HSTRING.
                var innerText = windows_core.HString()
                try (serializer = root.asIXmlNodeSerializer()) {
                    var out = CPointer<Unit>()
                    let hr = unsafe { serializer.InnerText(CPointer<CPointer<Unit>>(inout out)) }
                    hr.check()
                    innerText = windows_core.HString.fromSystemHandleTake(out)
                }

                // println!("{:?}", root.InnerText()?) — debug format quotes a String.
                println("\"${innerText}\"")
            }
        }
        return 0
    } catch (e: windows_core.WindowsException) {
        eprintln("XML sample failed: ${e}")
        return 1
    }
}

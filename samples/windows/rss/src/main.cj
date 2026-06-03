package windows_sample_rss

import windows_sample_rss_bindings.Foundation.Uri
import windows_sample_rss_bindings.Web.Syndication.{SyndicationClient, SyndicationFeed, SyndicationItem}
// Bring the underlying SyndicationFeed projection (and its HandleWinrtType /
// WinrtGenericType extension) into scope so the windows_future IAsyncOperation
// .join() generic constraint resolves for SyndicationFeed.
import windows_sample_rss_bindings.impl.Windows_Web_Syndication_SyndicationFeed
import windows_core.{HString, WindowsException, Interface, RuntimeType, WinrtGenericType}
import windows_future.*

// ============================================================================
// rss — behaviour-equivalent port of the reference sample.
//
// Creates a WinRT Uri for a blog feed, spins up a SyndicationClient, sets a
// User-Agent request header, retrieves the syndication feed asynchronously, and
// prints the title text of every item in the feed.
//
// Paradigm notes (Cangjie vs the reference language):
//   • There is no compile-time `h!` HSTRING literal. We construct an HString
//     from a Cangjie String at run time (HString(s)) — semantically identical to
//     a `h!` literal: a managed HSTRING handle that frees on drop.
//   • The reference `client.RetrieveFeedAsync(&uri)?.await?` blocks on the WinRT
//     IAsyncOperation. The generated projection surfaces RetrieveFeedAsync as
//     returning a bare IInspectable (the parameterized async result type is not
//     reified by the generator). We re-project that raw COM pointer into the
//     windows_future IAsyncOperation<SyndicationFeed> wrapper and call its
//     blocking .join() — the exact ABI the reference's executor `block_on`
//     performs (poll IAsyncInfo to terminal status, then GetResults).
//       - viewOf (not fromAbiTake) shares the pointer the owning IInspectable
//         already holds, so the single COM reference is released exactly once
//         when the IInspectable wrapper is closed — no double Release.
//   • feed.Items() is projected as the low-level IVector<SyndicationItem> COM
//     wrapper (raw vtbl thunks: Size / GetAt). We iterate by index — the same
//     calls the reference's collection iterator makes under the hood — and wrap
//     each returned raw pointer as an owned SyndicationItem.
//   • item.Title() yields the ISyndicationText interface; we read its Text
//     property through the interface's Text() vtbl slot (the same call the
//     SyndicationText.Text getter performs internally) and obtain an owned
//     HSTRING.
//   • The reference prints each title with `{:?}` (Rust debug formatting of the
//     HSTRING), which quotes the string. We match by printing it quoted.
//   • COM/runtime-class pointer lifetime is owned by the generated Resource
//     wrappers (each takeOwnership handle Releases on close); GC owns the
//     wrappers themselves, so no manual AddRef/Release is needed.
//   • No explicit CoInitializeEx: the WinRT activation-factory path (used by
//     SyndicationClient.new and Uri.CreateUri) bootstraps the implicit MTA,
//     exactly as the reference does (it performs no apartment init either).
// ============================================================================

main(): Int64 {
    // h!("https://blogs.windows.com/feed")
    let uri = Uri.CreateUri(HString("https://blogs.windows.com/feed"))
    let client = SyndicationClient.new()
    try {
        // client.SetRequestHeader(h!("User-Agent"), h!("Mozilla/5.0 ..."))
        client.SetRequestHeader(
            HString("User-Agent"),
            HString("Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; WOW64; Trident/6.0)")
        )

        // client.RetrieveFeedAsync(&uri)?.await?
        // The projection hands back the async operation as an IInspectable; the
        // owning wrapper keeps the COM object alive while we block on it.
        let operationInspectable = client.RetrieveFeedAsync(uri)
        try {
            let operation = IAsyncOperation<SyndicationFeed>.viewOf(operationInspectable.asRaw())
            let feed = match (operation.join()) {
                case Ok(value) => value
                case Err(error) => throw WindowsException(error)
            }

            // for item in feed.Items()? { println!("{:?}", item.Title()?.Text()?) }
            try {
                let items = feed.Items
                try {
                    var count: UInt32 = 0
                    unsafe {
                        items.Size(CPointer<UInt32>(inout count)).check()
                    }
                    var index: UInt32 = 0
                    while (index < count) {
                        var itemRaw = CPointer<Unit>()
                        unsafe {
                            items.GetAt(index, CPointer<CPointer<Unit>>(inout itemRaw)).check()
                        }
                        let item = SyndicationItem.fromAbiTakeWinrtHandle(itemRaw)
                        try {
                            let title = item.Title
                            try {
                                var textRaw = CPointer<Unit>()
                                unsafe {
                                    title.Text(CPointer<CPointer<Unit>>(inout textRaw)).check()
                                }
                                let text = HString.fromSystemHandleTake(textRaw)
                                // Match the reference's {:?} debug formatting (quoted).
                                println("\"${text}\"")
                            } finally {
                                title.close()
                            }
                        } finally {
                            item.close()
                        }
                        index += 1
                    }
                } finally {
                    items.close()
                }
            } finally {
                feed.close()
            }
        } finally {
            operationInspectable.close()
        }
    } finally {
        client.close()
        uri.close()
    }

    return 0
}

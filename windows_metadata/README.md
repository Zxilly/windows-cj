# windows_metadata

`windows_metadata` provides a native Cangjie reader for `.winmd` files.

The package exposes PE metadata parsing, metadata table access, signature
decoding, type indexing, and custom-attribute decoding. It is the standalone
metadata API package; `windows_bindgen` can continue to use its internal adapter
while this package gives tools and tests a stable reader boundary.

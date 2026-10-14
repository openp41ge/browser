// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_EXTENSIONS_PACKAGE_H_
#define OPENP41GE_EXPLORER_EXTENSIONS_PACKAGE_H_

#include <string>

// An extension's release zip (<id>-<version>.openp41ge-extension.zip).
namespace extension_package {

// The SHA-256 of `bytes`, in hex.
std::string Sha256(const std::string& bytes);

// Unpacks `zip` (its bytes) into `folder` (made; it mustn't exist). Before
// anything is written, every entry is checked: a relative path inside the
// folder (no absolute paths, no "..", no backslashes) and a plain file or
// folder (no links); and after, that nothing in the folder is a link.
// Returns what's wrong, or empty. Blocks: for the file thread.
std::string Unpack(const std::string& zip, const std::string& folder);

}  // namespace extension_package

#endif  // OPENP41GE_EXPLORER_EXTENSIONS_PACKAGE_H_

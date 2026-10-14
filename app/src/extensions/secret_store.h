// Copyright (c) 2026 Richard Kielty. MIT License.

#ifndef OPENP41GE_EXPLORER_EXTENSIONS_SECRET_STORE_H_
#define OPENP41GE_EXPLORER_EXTENSIONS_SECRET_STORE_H_

#include <map>
#include <optional>
#include <string>

// Extensions' secret settings ("secret": true in their config schema), kept
// out of the profile's files: in the macOS Keychain, as generic passwords of
// the service "openp41ge explorer extension settings", one per profile,
// extension and setting. With --use-mock-keychain (the tests' throwaway
// profiles) they're kept in memory instead, so tests never touch the user's
// Keychain. See plans/2026-10-14-extension-system.md, "Settings". UI thread.
class SecretStore {
 public:
  // `profile_folder` tells profiles' secrets apart.
  explicit SecretStore(const std::string& profile_folder);

  std::optional<std::string> Get(const std::string& extension_id, const std::string& key);
  void Set(const std::string& extension_id, const std::string& key, const std::string& value);
  void Delete(const std::string& extension_id, const std::string& key);

 private:
  std::string Account(const std::string& extension_id, const std::string& key) const;

  const std::string profile_folder_;
  const bool in_memory_;
  std::map<std::string, std::string> memory_;  // By account (in memory only).
};

#endif  // OPENP41GE_EXPLORER_EXTENSIONS_SECRET_STORE_H_

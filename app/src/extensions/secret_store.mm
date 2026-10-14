// Copyright (c) 2026 Richard Kielty. MIT License.

#include "extensions/secret_store.h"

#import <Foundation/Foundation.h>
#import <Security/Security.h>

#include "include/base/cef_logging.h"
#include "include/cef_command_line.h"

namespace {

NSString* const kService = @"openp41ge explorer extension settings";

NSMutableDictionary* Query(const std::string& account) {
  return [@{
    (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService : kService,
    (__bridge id)kSecAttrAccount : @(account.c_str()),
  } mutableCopy];
}

}  // namespace

SecretStore::SecretStore(const std::string& profile_folder)
    : profile_folder_(profile_folder),
      in_memory_(CefCommandLine::GetGlobalCommandLine()->HasSwitch("use-mock-keychain")) {}

std::string SecretStore::Account(const std::string& extension_id, const std::string& key) const {
  // The profile, the extension and the setting: e.g.
  // ".../Default extension youtube-popout apiKey".
  return profile_folder_ + " extension " + extension_id + " " + key;
}

std::optional<std::string> SecretStore::Get(const std::string& extension_id, const std::string& key) {
  const std::string account = Account(extension_id, key);
  if (in_memory_) {
    auto it = memory_.find(account);
    return it == memory_.end() ? std::nullopt : std::optional<std::string>(it->second);
  }
  NSMutableDictionary* query = Query(account);
  query[(__bridge id)kSecReturnData] = @YES;
  query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
  CFTypeRef result = nullptr;
  const OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
  if (status == errSecItemNotFound) return std::nullopt;
  if (status != errSecSuccess || !result) {
    LOG(ERROR) << "Couldn't read a secret setting from the Keychain (" << status << ")";
    return std::nullopt;
  }
  NSData* data = CFBridgingRelease(result);
  return std::string(static_cast<const char*>(data.bytes), data.length);
}

void SecretStore::Set(const std::string& extension_id, const std::string& key, const std::string& value) {
  const std::string account = Account(extension_id, key);
  if (in_memory_) {
    memory_[account] = value;
    return;
  }
  NSData* data = [NSData dataWithBytes:value.data() length:value.size()];
  const OSStatus updated = SecItemUpdate((__bridge CFDictionaryRef)Query(account),
                                         (__bridge CFDictionaryRef) @{(__bridge id)kSecValueData : data});
  if (updated == errSecSuccess) return;
  if (updated != errSecItemNotFound) {
    LOG(ERROR) << "Couldn't update a secret setting in the Keychain (" << updated << ")";
    return;
  }
  NSMutableDictionary* item = Query(account);
  item[(__bridge id)kSecValueData] = data;
  item[(__bridge id)kSecAttrLabel] = [NSString stringWithFormat:@"openp41ge explorer: %s %s", extension_id.c_str(), key.c_str()];
  const OSStatus added = SecItemAdd((__bridge CFDictionaryRef)item, nullptr);
  LOG_IF(ERROR, added != errSecSuccess) << "Couldn't add a secret setting to the Keychain (" << added << ")";
}

void SecretStore::Delete(const std::string& extension_id, const std::string& key) {
  const std::string account = Account(extension_id, key);
  if (in_memory_) {
    memory_.erase(account);
    return;
  }
  const OSStatus status = SecItemDelete((__bridge CFDictionaryRef)Query(account));
  LOG_IF(ERROR, status != errSecSuccess && status != errSecItemNotFound)
      << "Couldn't delete a secret setting from the Keychain (" << status << ")";
}

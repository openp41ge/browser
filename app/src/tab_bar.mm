// Copyright (c) 2026 Richard Kielty. MIT License.

#include "tab_bar.h"

#include "pane.h"

TabBar::TabBar(Pane* owner) : UiView("tabbar.html", kHeight, Background::kSurface), owner_(owner) {}

void TabBar::Update() {
  if (!owner_) return;
  CefRefPtr<CefListValue> tabs = CefListValue::Create();
  for (const CefRefPtr<Tab>& tab : owner_->tabs()) {
    CefRefPtr<CefDictionaryValue> t = CefDictionaryValue::Create();
    t->SetInt("id", tab->id());
    t->SetString("title", tab->title);
    t->SetString("url", tab->url);
    t->SetString("favicon", tab->favicon);
    t->SetBool("loading", tab->loading);
    tabs->SetDictionary(tabs->GetSize(), t);
  }
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "tabs");
  message->SetList("tabs", tabs);
  message->SetInt("active", owner_->active_tab() ? owner_->active_tab()->id() : -1);
  Send(message);
}

bool TabBar::OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) {
  if (!owner_) return true;
  if (type == "activate") {
    owner_->Activate(message->GetInt("id"));
  } else if (type == "close") {
    owner_->RequestClose(message->GetInt("id"));
  } else if (type == "move") {
    owner_->Move(message->GetInt("id"), message->GetInt("index"));
  } else if (type == "new-tab") {
    owner_->RequestNewTab();
  } else {
    return false;
  }
  return true;
}

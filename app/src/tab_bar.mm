// Copyright (c) 2026 Richard Kielty. MIT License.

#include "tab_bar.h"

#include "browser_manager.h"
#include "browser_window.h"
#include "pane.h"

namespace {

// Matches from history offered under a tab's address.
constexpr size_t kMaxSuggestions = 6;

}  // namespace

TabBar::TabBar(Pane* owner) : UiView("tabbar.html", CefSize(1, kHeight), Background::kSurface), owner_(owner) {}

void TabBar::Update() {
  if (!owner_) return;
  CefRefPtr<CefListValue> tabs = CefListValue::Create();
  for (const CefRefPtr<Tab>& tab : owner_->tabs()) {
    CefRefPtr<CefDictionaryValue> t = CefDictionaryValue::Create();
    t->SetInt("id", tab->id());
    t->SetString("url", tab->url);
    t->SetString("favicon", tab->favicon);
    t->SetBool("loading", tab->loading);
    tabs->SetDictionary(tabs->GetSize(), t);
  }
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "tabs");
  message->SetList("tabs", tabs);
  message->SetInt("active", owner_->active_tab() ? owner_->active_tab()->id() : -1);
  message->SetBool("focused", owner_->window()->ShowsFocus(owner_));
  if (edit_ >= 0 && connected()) {
    message->SetInt("edit", edit_);
    edit_ = -1;
  }
  Send(message);
}

void TabBar::PickSuggestion(int index) {
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "suggestion-picked");
  message->SetInt("index", index);
  Send(message);
}

void TabBar::RemoveSuggestion(int index) {
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "suggestion-removed");
  message->SetInt("index", index);
  Send(message);
}

void TabBar::EditAddress(int id) {
  edit_ = id;
  Update();
}

void TabBar::ShowInsertHint(int index) {
  CefRefPtr<CefDictionaryValue> message = CefDictionaryValue::Create();
  message->SetString("type", "hint");
  message->SetInt("index", index);
  Send(message);
}

bool TabBar::OnMessage(const std::string& type, CefRefPtr<CefDictionaryValue> message) {
  if (!owner_) return true;
  BrowserWindow* window = owner_->window();
  if (type == "activate") {
    owner_->RequestActivate(message->GetInt("id"));
  } else if (type == "close") {
    owner_->RequestClose(message->GetInt("id"));
  } else if (type == "new-tab") {
    owner_->RequestNewTab();
  } else if (type == "navigate") {
    owner_->RequestNavigate(message->GetInt("id"), message->GetString("url"));
  } else if (type == "suggest") {
    // Matches from history for what's typed, best first (none in a private
    // window: it neither records nor shows where you've been).
    const std::string text = message->GetString("text");
    CefRefPtr<CefListValue> matches = CefListValue::Create();
    if (History* history = window->history()) {
      for (const History::Match& match : history->Find(text, kMaxSuggestions)) {
        CefRefPtr<CefDictionaryValue> m = CefDictionaryValue::Create();
        m->SetString("url", match.url);
        m->SetString("title", match.title);
        m->SetString("text", match.text);
        m->SetBool("completes", match.completes);
        matches->SetDictionary(matches->GetSize(), m);
      }
    }
    CefRefPtr<CefDictionaryValue> reply = CefDictionaryValue::Create();
    reply->SetString("type", "suggestions");
    reply->SetString("text", text);
    reply->SetList("matches", matches);
    Send(reply);
  } else if (type == "forget") {
    // A suggestion's ✕: gone from history (the page then asks again).
    if (History* history = window->history()) history->Remove(message->GetString("text"));
  } else if (type == "suggest-show") {
    const CefRect tab(message->GetInt("x"), message->GetInt("y"), message->GetInt("width"), message->GetInt("height"));
    window->ShowSuggestions(owner_, message->GetList("rows"), message->GetInt("selected"), tab,
                            message->GetInt("popupWidth"));
  } else if (type == "suggest-hide") {
    window->HideSuggestions(owner_);
  } else if (type == "layout") {
    std::vector<std::pair<int, int>> middles;
    CefRefPtr<CefListValue> tabs = message->GetList("tabs");
    for (size_t i = 0; tabs && i < tabs->GetSize(); ++i) {
      CefRefPtr<CefDictionaryValue> tab = tabs->GetDictionary(i);
      middles.emplace_back(tab->GetInt("id"), tab->GetInt("middle"));
    }
    owner_->SetTabMiddles(std::move(middles));
    CefRefPtr<CefDictionaryValue> bar = message->GetDictionary("focusBar");
    owner_->SetFocusBar(bar ? CefRange(bar->GetInt("x"), bar->GetInt("x") + bar->GetInt("width")) : CefRange());
    window->UpdateFocusBar();
  } else if (type == "drag") {
    window->DragTab(owner_, message->GetInt("id"), message->GetInt("x"), message->GetInt("y"));
  } else if (type == "drop") {
    window->DropTab(owner_, message->GetInt("id"), message->GetInt("x"), message->GetInt("y"));
  } else if (type == "drag-cancel") {
    window->CancelTabDrag();
  } else {
    return false;
  }
  return true;
}

#include "direct_host_tray.h"
#include "resource.h"

#include <string>

namespace {
constexpr UINT kTrayMessage = WM_APP + 0x311;
constexpr UINT_PTR kTrayTimer = 0xFB16;
constexpr UINT kOpenCommand = 1;
constexpr UINT kExitCommand = 2;
template <typename T>
T RustFunction(const char* name) {
  return reinterpret_cast<T>(GetProcAddress(GetModuleHandleW(L"librustdesk.dll"), name));
}
}

bool DirectHostTray::IsEnabled() {
  auto enabled = RustFunction<bool (*)()>("rustdesk_direct_only_enabled");
  return enabled && enabled();
}

DirectHostTray::DirectHostTray(HWND window)
    : window_(window), taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")) {
  icon_.cbSize = sizeof(icon_);
  icon_.hWnd = window_;
  icon_.uID = 1;
  icon_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  icon_.uCallbackMessage = kTrayMessage;
  icon_.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON));
  wcscpy_s(icon_.szTip, L"RustDesk · 等待连接");
  AddIcon();
  SetTimer(window_, kTrayTimer, 2000, nullptr);
}

DirectHostTray::~DirectHostTray() {
  KillTimer(window_, kTrayTimer);
  Shell_NotifyIconW(NIM_DELETE, &icon_);
}

bool DirectHostTray::AddIcon() {
  ready_ = Shell_NotifyIconW(NIM_ADD, &icon_) != FALSE;
  if (ready_) {
    icon_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &icon_);
  }
  return ready_;
}

void DirectHostTray::ShowWindow() {
  ::ShowWindow(window_, SW_RESTORE);
  SetForegroundWindow(window_);
}

void DirectHostTray::UpdateTooltip() {
  auto count = RustFunction<size_t (*)()>("rustdesk_direct_only_session_count");
  const size_t sessions = count ? count() : 0;
  const std::wstring tooltip = sessions == 0
      ? L"RustDesk · 等待连接"
      : L"RustDesk · 已连接 " + std::to_wstring(sessions) + L" 个会话";
  wcsncpy_s(icon_.szTip, tooltip.c_str(), _TRUNCATE);
  if (!ready_) {
    AddIcon();
  } else {
    ready_ = Shell_NotifyIconW(NIM_MODIFY, &icon_) != FALSE;
  }
}

std::optional<LRESULT> DirectHostTray::Handle(UINT message, WPARAM wparam, LPARAM lparam) {
  if (taskbar_created_ != 0 && message == taskbar_created_) {
    AddIcon();
    return 0;
  }
  if (message == WM_TIMER && wparam == kTrayTimer) {
    UpdateTooltip();
    return 0;
  }
  if (message == kExitMessage) {
    Shell_NotifyIconW(NIM_DELETE, &icon_);
    ready_ = false;
    auto quit = RustFunction<void (*)()>("rustdesk_direct_only_prepare_quit");
    if (quit) quit();
    PostQuitMessage(0);
    return 0;
  }
  if (message == kTrayMessage) {
    const UINT event = LOWORD(lparam);
    if (event == NIN_SELECT || event == NIN_KEYSELECT || event == WM_LBUTTONDBLCLK) {
      ShowWindow();
    } else if (event == WM_CONTEXTMENU || event == WM_RBUTTONUP) {
      HMENU menu = CreatePopupMenu();
      if (menu) {
        AppendMenuW(menu, MF_STRING, kOpenCommand, L"打开窗口");
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(menu, MF_STRING, kExitCommand, L"退出");
        POINT cursor{};
        GetCursorPos(&cursor);
        SetForegroundWindow(window_);
        const UINT selected = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
            cursor.x, cursor.y, 0, window_, nullptr);
        DestroyMenu(menu);
        PostMessageW(window_, WM_NULL, 0, 0);
        if (selected == kOpenCommand) ShowWindow();
        if (selected == kExitCommand) PostMessageW(window_, kExitMessage, 0, 0);
      }
    }
    return 0;
  }
  if (message == WM_CLOSE) {
    if (ready_) {
      ::ShowWindow(window_, SW_HIDE);
    } else {
      ::ShowWindow(window_, SW_MINIMIZE);
    }
    return 0;
  }
  return std::nullopt;
}

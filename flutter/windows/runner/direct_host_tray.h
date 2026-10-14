#ifndef RUNNER_DIRECT_HOST_TRAY_H_
#define RUNNER_DIRECT_HOST_TRAY_H_

#include <windows.h>
#include <shellapi.h>
#include <optional>

class DirectHostTray {
 public:
  static constexpr UINT kExitMessage = WM_APP + 0x312;
  static bool IsEnabled();
  explicit DirectHostTray(HWND window);
  ~DirectHostTray();
  bool ready() const { return ready_; }
  std::optional<LRESULT> Handle(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  bool AddIcon();
  void ShowWindow();
  void UpdateTooltip();
  HWND window_;
  NOTIFYICONDATAW icon_{};
  bool ready_ = false;
  UINT taskbar_created_;
};

#endif

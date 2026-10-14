import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart' show isWindows;
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:window_manager/window_manager.dart';

bool get isDirectHost =>
    isWindows && bind.mainGetBuildinOption(key: 'direct-only') == 'Y';

const _hostChannel = MethodChannel('org.rustdesk.rustdesk/host');

class DirectHostPage extends StatefulWidget {
  const DirectHostPage({super.key});

  @override
  State<DirectHostPage> createState() => _DirectHostPageState();
}

class _DirectHostPageState extends State<DirectHostPage> {
  Timer? _timer;
  Map<String, dynamic> _status = {};
  bool _refreshing = false;
  bool _statusFailed = false;
  bool _trayReady = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final status =
          jsonDecode(await bind.mainGetCommon(key: 'direct-only-status'))
              as Map<String, dynamic>;
      final trayReady =
          await _hostChannel.invokeMethod<bool>('directHostTrayReady') ?? false;
      if (mounted) {
        setState(() {
          _status = status;
          _statusFailed = false;
          _trayReady = trayReady;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statusFailed = true);
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _password() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PasswordDialog(),
    );
    await _refresh();
  }

  Future<void> _background() async {
    if (await _hostChannel.invokeMethod<bool>('directHostTrayReady') == true) {
      await windowManager.hide();
    } else {
      await windowManager.minimize();
    }
  }

  Future<void> _exit() async {
    try {
      await _hostChannel.invokeMethod<void>('directHostExit');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('退出失败，请运行停止脚本。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final passwordSet = _status['password_set'] == true;
    final listener = _status['listener'] as int? ?? 0;
    final sessions = _status['sessions'] as int? ?? 0;
    final ready = !_statusFailed && listener == 1 && passwordSet;
    final title = _statusFailed
        ? '无法读取状态'
        : listener == 2
            ? '端口启动失败'
            : listener != 1
                ? '正在启动'
                : !passwordSet
                    ? '请先设置访问密码'
                    : sessions > 0
                        ? '已连接 · $sessions 个会话'
                        : '等待连接';
    final addresses =
        (_status['addresses'] as List? ?? []).cast<Map<String, dynamic>>();
    final color = ready ? const Color(0xFF16724A) : const Color(0xFF936018);
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3267D6)),
        scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      ),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(children: [
                Icon(Icons.desktop_windows_outlined,
                    color: Color(0xFF3267D6), size: 28),
                SizedBox(width: 12),
                Text('远程控制',
                    style:
                        TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 7),
              const Text('从 iPad 或其他设备连接这台电脑',
                  style: TextStyle(color: Color(0xFF667085), fontSize: 13)),
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 15),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Icon(
                              ready
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                              size: 20,
                              color: color),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(title,
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      _card([
                        const Text('连接地址',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 5),
                        const Text('在远端 RustDesk 的连接框输入地址',
                            style: TextStyle(
                                color: Color(0xFF667085), fontSize: 12)),
                        const SizedBox(height: 12),
                        if (addresses.isEmpty)
                          const Text('尚未找到网络地址，请检查网络连接。',
                              style: TextStyle(color: Color(0xFF667085))),
                        for (final address in addresses)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(children: [
                              Expanded(
                                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(address['name'] as String,
                                      style: const TextStyle(
                                          color: Color(0xFF667085),
                                          fontSize: 12)),
                                  const SizedBox(height: 3),
                                  SelectableText(address['address'] as String,
                                      style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w500)),
                                ],
                              )),
                              IconButton(
                                tooltip: '复制地址',
                                icon: const Icon(Icons.content_copy_outlined,
                                    size: 19),
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(
                                      text: address['address'] as String));
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('地址已复制'),
                                            duration: Duration(seconds: 1)));
                                  }
                                },
                              ),
                            ]),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      _card([
                        Row(children: [
                          const Expanded(
                              child: Text('访问密码',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600))),
                          TextButton(
                              onPressed: _password,
                              child: Text(passwordSet ? '修改密码' : '设置密码')),
                        ]),
                        Text(passwordSet ? '已设置 · 每次连接均需验证' : '未设置 · 设置后才能连接',
                            style: const TextStyle(
                                color: Color(0xFF667085), fontSize: 12)),
                      ]),
                      const SizedBox(height: 16),
                      const Text('允许屏幕、键鼠和文本剪贴板',
                          style: TextStyle(
                              color: Color(0xFF667085), fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _background,
                        icon: const Icon(Icons.minimize, size: 18),
                        label: const Text('后台运行'))),
                const SizedBox(width: 12),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _exit,
                        icon: const Icon(Icons.power_settings_new, size: 18),
                        label: const Text('退出'))),
              ]),
              const SizedBox(height: 8),
              Text(_trayReady ? '关闭窗口后保留托盘图标；退出会断开连接。' : '托盘暂不可用，关闭窗口将最小化到任务栏。',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF667085))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7EAF0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.clear();
    _confirm.clear();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    var saved = false;
    try {
      saved = await bind.mainSetPermanentPasswordWithResult(
          password: _password.text);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = '密码保存失败，请重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: const Text('设置访问密码'),
          content: SizedBox(
              width: 320,
              child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('使用至少 16 个字符的随机密码。',
                          style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        autofocus: true,
                        obscureText: true,
                        enabled: !_saving,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                            labelText: '新密码', border: OutlineInputBorder()),
                        validator: (value) => (value?.runes.length ?? 0) < 16
                            ? '密码至少需要 16 个字符'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
                        enabled: !_saving,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                            labelText: '确认密码', border: OutlineInputBorder()),
                        validator: (value) =>
                            value != _password.text ? '两次输入的密码不一致' : null,
                        onFieldSubmitted: (_) => _save(),
                      ),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.red))),
                    ],
                  ))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('取消')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '正在保存…' : '保存')),
          ],
        ),
      );
}

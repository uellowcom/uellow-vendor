import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.orderId, required this.title});
  final int orderId;
  final String title;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Future<List<ChatMsg>>? _f;
  final _ctrl = TextEditingController();
  bool _busy = false;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.chat(widget.orderId); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await VendorApi.instance.chatSend(widget.orderId, _ctrl.text.trim());
      _ctrl.clear();
      setState(() => _f = VendorApi.instance.chat(widget.orderId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title.isNotEmpty ? widget.title
                                                          : (ar ? 'محادثة' : 'Chat'))),
      body: Column(children: [
        Expanded(child: FutureBuilder<List<ChatMsg>>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          final rows = snap.data ?? const <ChatMsg>[];
          if (rows.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(30),
            child: Text(ar ? 'لا توجد رسائل بعد' : 'No messages yet', style: UT.body)));
          return ListView.builder(reverse: true, padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final m = rows[rows.length - 1 - i];
              return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: m.isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (!m.isSelf) ...[
                      CircleAvatar(radius: 14, backgroundColor: UC.yellowFaint,
                        backgroundImage: (m.author['avatar_url'] as String?) != null
                          ? CachedNetworkImageProvider('${VendorApi.instance.baseUrl}${m.author['avatar_url']}')
                          : null,
                        child: (m.author['avatar_url'] as String?) == null
                          ? Text(((m.author['name'] ?? '?').toString().substring(0, 1)).toUpperCase(),
                              style: const TextStyle(color: UC.brown,
                                  fontWeight: FontWeight.w900, fontSize: 11)) : null),
                      const SizedBox(width: 6),
                    ],
                    Flexible(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        color: m.isSelf ? UC.brown : Colors.white,
                        border: m.isSelf ? null : Border.all(color: UC.border),
                        borderRadius: BorderRadius.circular(13)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.body, style: TextStyle(fontSize: 12.5,
                          color: m.isSelf ? UC.yellowSoft : UC.ink, height: 1.35)),
                        const SizedBox(height: 3),
                        Text(m.when.split('T').first,
                          style: TextStyle(fontSize: 9.5,
                            color: m.isSelf ? const Color(0xCCFFE066) : UC.muted)),
                      ]))),
                  ]));
            });
        })),
        SafeArea(top: false, child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: UC.border))),
          child: Row(children: [
            Expanded(child: TextField(controller: _ctrl, minLines: 1, maxLines: 4,
              decoration: InputDecoration(
                hintText: ar ? 'اكتب رسالتك للعميل…' : 'Type a message…'))),
            const SizedBox(width: 6),
            IconButton.filled(onPressed: _send,
              icon: _busy
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
                : const Icon(Icons.send, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: UC.yellow, foregroundColor: UC.brown,
                padding: const EdgeInsets.all(12))),
          ]))),
      ]),
    );
  }
}

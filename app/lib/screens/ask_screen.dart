import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/visuals.dart';
import 'emergency_screen.dart';

/// "Ask Khutwa": the patient asks a question (tap a suggestion or type); Claude answers from
/// the guideline knowledge base and shows the source. Warning symptoms go to the rule engine.
class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages =
      []; // {from: 'me'|'bot', text, sources, doctor, mode}
  bool _busy = false;

  static const _suggestions = ['ask_s1', 'ask_s2', 'ask_s3', 'ask_s4'];

  Future<void> _send(String question) async {
    final q = question.trim();
    if (q.isEmpty || _busy) return;
    final s = S.of(context);
    final api = AppScope.read(context).api;
    _controller.clear();
    setState(() {
      _messages.add({'from': 'me', 'text': q});
      _busy = true;
    });
    _toBottom();
    try {
      final r = await api.ask(q);
      if (!mounted) return;
      if (r['type'] == 'emergency') {
        setState(() => _busy = false);
        await EmergencyScreen.show(
          context,
          r['safety'] as Map<String, dynamic>,
        );
        return;
      }
      setState(() {
        _messages.add({
          'from': 'bot',
          'text': s.pick(r, 'answer'),
          'sources': r['sources'] ?? [],
          'doctor': r['suggest_doctor'] == true,
          'mode': r['mode'],
        });
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'from': 'bot',
          'text': s.t('error_generic'),
          'sources': [],
          'doctor': false,
          'mode': 'error',
        });
        _busy = false;
      });
    }
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            children: [
              DoctorSays(text: s.t('ask_title'), sub: s.t('ask_sub'), size: 80),
              const SizedBox(height: 8),
              if (_messages.isEmpty) ...[
                Text(
                  s.t('ask_try'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final key in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: AlignmentDirectional.centerStart,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: kFont,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => _send(s.t(key)),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.t(key))),
                        ],
                      ),
                    ),
                  ),
              ],
              for (final m in _messages) _Bubble(message: m),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Img3D('doctor', size: 36),
                      SizedBox(width: 10),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 20),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: s.t('ask_hint'),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: IconButton.filled(
                    iconSize: 30,
                    onPressed: _busy ? null : () => _send(_controller.text),
                    icon: const Icon(Icons.send_rounded),
                    tooltip: s.t('ask_send'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final mine = message['from'] == 'me';
    if (mine) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsetsDirectional.only(start: 48, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            message['text'] as String,
            style: const TextStyle(
              fontSize: 19,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      );
    }
    final sources = (message['sources'] as List).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Img3D('doctor', size: 40),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'] as String,
                    style: const TextStyle(fontSize: 20, height: 1.5),
                  ),
                  if (message['doctor'] == true) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Img3D('stethoscope', size: 24),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.t('ask_doctor_note'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.warn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (sources.isNotEmpty) ...[
                    const Divider(height: 22),
                    Row(
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.t('source'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    for (final src in sources)
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${src['citation']}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                  if (message['mode'] == 'claude') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          s.t('ai_by'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

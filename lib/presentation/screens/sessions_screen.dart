import 'package:flutter/material.dart';
import '../../core/di/dependency_container.dart';
import '../../data/models/recording_session.dart';
import 'review_screen.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<RecordingSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    final container = DependencyContainer();
    setState(() {
      _sessions = container.sessionService.loadSessions();
    });
  }

  Future<void> _deleteSession(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Eliminar grabación', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se eliminará el video y sus dorsales. ¿Continuar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final container = DependencyContainer();
      await container.sessionService.deleteSession(id);
      _loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Grabaciones'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, color: Colors.grey[600], size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No hay grabaciones guardadas',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Las grabaciones aparecerán aquí\npara revisar los dorsales detectados',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                return _SessionCard(
                  session: session,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(session: session),
                      ),
                    );
                    _loadSessions();
                  },
                  onDelete: () => _deleteSession(session.id),
                );
              },
            ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final RecordingSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.play_circle_filled,
                  color: Colors.greenAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.formattedDate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer, color: Colors.grey[500], size: 14),
                        const SizedBox(width: 4),
                        Text(
                          session.formattedDuration,
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.format_list_numbered, color: Colors.grey[500], size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${session.dorsals.length} dorsales',
                          style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

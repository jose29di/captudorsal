import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../data/models/recording_session.dart';

class ReviewScreen extends StatefulWidget {
  final RecordingSession session;

  const ReviewScreen({super.key, required this.session});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  int _selectedDorsalIndex = -1;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final file = File(widget.session.videoPath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video no encontrado'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      _controller!.addListener(_onVideoUpdate);

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onVideoUpdate() {
    if (!_isInitialized || _controller == null) return;

    final pos = _controller!.value.position;
    if (pos.inMilliseconds != _currentPosition.inMilliseconds) {
      setState(() {
        _currentPosition = pos;
        _updateSelectedDorsal();
      });
    }

    final playing = _controller!.value.isPlaying;
    if (playing != _isPlaying) {
      setState(() => _isPlaying = playing);
    }
  }

  void _updateSelectedDorsal() {
    final posMs = _currentPosition.inMilliseconds;
    int closest = -1;
    int closestDiff = 999999999;
    for (int i = 0; i < widget.session.dorsals.length; i++) {
      final diff = (widget.session.dorsals[i].offsetMs - posMs).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closest = i;
      }
    }
    _selectedDorsalIndex = closest;
  }

  void _seekToDorsal(int index) {
    if (!_isInitialized || _controller == null) return;
    final dorsal = widget.session.dorsals[index];
    _controller!.seekTo(Duration(milliseconds: dorsal.offsetMs));
    if (!_isPlaying) {
      _controller!.play();
    }
    setState(() => _selectedDorsalIndex = index);
  }

  String _formatDuration(Duration d) {
    final min = (d.inSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _shareDorsalList() async {
    final session = widget.session;
    final buf = StringBuffer();
    buf.writeln('CaptuDorsal - Listado de Dorsales');
    buf.writeln('Fecha: ${session.formattedDate}');
    buf.writeln('Duración del video: ${session.formattedDuration}');
    buf.writeln('Total dorsales: ${session.dorsals.length}');
    buf.writeln('');
    buf.writeln('Nro  Hora_Paso      Minuto_Video');
    buf.writeln('-' * 40);

    for (final d in session.dorsals) {
      final min = (d.offsetMs ~/ 60000).toString().padLeft(2, '0');
      final sec = ((d.offsetMs % 60000) ~/ 1000).toString().padLeft(2, '0');
      final ms = (d.offsetMs % 1000).toString().padLeft(3, '0');
      buf.writeln('${d.dorsal.padLeft(4)}   ${d.formattedTime}   $min:$sec.$ms');
    }

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/dorsales_${session.id}.txt';
      final file = File(filePath);
      await file.writeAsString(buf.toString());

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Listado de dorsales - ${session.dorsals.length} detectados',
        subject: 'Dorsales CaptuDorsal ${session.formattedDate}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.session.formattedDate),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share, color: Colors.white),
            color: Colors.grey[900],
            onSelected: (value) async {
              if (value == 'video') {
                final file = File(widget.session.videoPath);
                if (await file.exists()) {
                  await Share.shareXFiles(
                    [XFile(widget.session.videoPath)],
                    text: 'Grabación CaptuDorsal - ${widget.session.dorsals.length} dorsales',
                  );
                }
              } else if (value == 'list') {
                await _shareDorsalList();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'video',
                child: Row(
                  children: [
                    Icon(Icons.videocam, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Compartir video', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'list',
                child: Row(
                  children: [
                    Icon(Icons.list_alt, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 12),
                    Text('Compartir dorsales', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          if (widget.session.dorsals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.session.dorsals.length} dorsales',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 45,
            child: _buildVideoPlayer(),
          ),
          Expanded(
            flex: 10,
            child: _buildControls(),
          ),
          Expanded(
            flex: 45,
            child: _buildDorsalsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildControls() {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    final duration = _controller!.value.duration;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.grey[900],
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatDuration(_currentPosition),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Expanded(
            child: Slider(
              value: _currentPosition.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
              min: 0,
              max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
              onChanged: (value) {
                _controller!.seekTo(Duration(milliseconds: value.toInt()));
              },
              activeColor: Colors.greenAccent,
              inactiveColor: Colors.grey[700],
            ),
          ),
          Text(
            _formatDuration(duration),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDorsalsList() {
    if (widget.session.dorsals.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.dnd_forwardslash_outlined, color: Colors.grey, size: 48),
              SizedBox(height: 12),
              Text(
                'No se detectaron dorsales en esta grabación',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Dorsales detectados',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Pulsa para saltar al video',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: widget.session.dorsals.length,
              itemBuilder: (context, index) {
                final dorsal = widget.session.dorsals[index];
                final isSelected = index == _selectedDorsalIndex;

                return GestureDetector(
                  onTap: () => _seekToDorsal(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.greenAccent.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: Colors.greenAccent.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            dorsal.dorsal,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          color: isSelected ? Colors.greenAccent : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dorsal.formattedTime,
                          style: TextStyle(
                            color: isSelected ? Colors.greenAccent : Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.greenAccent.withValues(alpha: 0.3)
                                : Colors.grey[800],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            dorsal.formattedOffset,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.play_circle_outline,
                          color: isSelected ? Colors.greenAccent : Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

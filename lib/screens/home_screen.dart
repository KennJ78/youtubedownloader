import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../widgets/downloaded_file_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  double progress = 0.0;
  String status = '';
  List<File> downloadedFiles = [];

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().whereType<File>().toList();
    setState(() => downloadedFiles = files);
  }

  Future<void> startDownload(String option) async {
    final link = _controller.text.trim();

    if (link.isEmpty || !link.contains('youtube.com/watch?v=')) {
      setState(() => status = 'Error: Please enter a valid YouTube link.');
      return;
    }

    setState(() {
      progress = 0;
      status = 'Starting...';
    });

    try {
      final yt = YoutubeExplode();
      final video = await yt.videos.get(link);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      StreamInfo? streamInfo;
      if (option == 'audio') {
        streamInfo = manifest.audio.sortByBitrate().last; // Highest audio
      }

      if (streamInfo == null) {
        setState(() => status = 'Error: No streams available.');
        return;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      // Sanitize the video title for a valid filename
      final safeTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${appDocDir.path}/$safeTitle.mp3';
      final file = File(filePath);
      final fileStream = file.openWrite();

      final totalBytes = streamInfo.size.totalBytes;
      var receivedBytes = 0;

      await for (final data in yt.videos.streamsClient.get(streamInfo)) {
        receivedBytes += data.length;
        fileStream.add(data);
        setState(() {
          progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
        });
        await Future.delayed(const Duration(milliseconds: 50)); // <-- optional
      }

      await fileStream.flush();
      await fileStream.close();

      setState(() => status = 'Downloaded: ${file.uri.pathSegments.last}');
      await _loadDownloadedFiles();
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFb31217), // deep red
        elevation: 0,
        title: const Text(
          'YouTube Mp3 Downloader',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white, letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFe52d27), Color(0xFFb31217), Color(0xFFf857a6), Color(0xFFFF5858)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  "Enter a YouTube Link",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.link, color: Color(0xFFe52d27)),
                      hintText: 'https://youtube.com/watch?v=...',
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () => setState(() => _controller.clear()),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.7),
                        Colors.red.shade100.withOpacity(0.7),
                        Colors.red.shade200.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFe52d27), Color(0xFFf857a6)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.7)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (status.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            status,
                            style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      color: Colors.white,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => startDownload('audio'),
                      child: const Text(
                        'Start Download MP3',
                        style: TextStyle(color: Color(0xFFb31217), letterSpacing: 1.1, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Downloaded Files',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFe52d27)),
                      ),
                      const SizedBox(height: 10),
                      if (downloadedFiles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No files yet.',
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                          ),
                        )
                      else
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Column(
                            key: ValueKey(downloadedFiles.length),
                            children: downloadedFiles
                                .map((file) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: DownloadedFileTile(
                                file: file,
                                onDelete: () async {
                                  await file.delete();
                                  setState(() => downloadedFiles.remove(file));
                                },
                                onShare: () => Share.shareXFiles([XFile(file.path)], text: 'Check this file'),
                              ),
                            ))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
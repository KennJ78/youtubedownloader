import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

void main() {
  runApp(const YouTubeDownloaderApp());
}

class YouTubeDownloaderApp extends StatelessWidget {
  const YouTubeDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.red,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

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
      final filePath = '${appDocDir.path}/${video.title}.mp3';
      final file = File(filePath);
      final fileStream = file.openWrite();

      final totalBytes = streamInfo.size.totalBytes;
      var receivedBytes = 0;

      await for (final data in yt.videos.streamsClient.get(streamInfo)) {
        receivedBytes += data.length;
        fileStream.add(data);
        setState(() => progress = receivedBytes / totalBytes);
      }

      await fileStream.flush();
      await fileStream.close();

      setState(() => status = 'Downloaded: ${file.uri.pathSegments.last}');
      await _loadDownloadedFiles();
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  Widget _buildDownloadedFileTile(File file) {
    return Card(
      elevation: 2,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          file.uri.pathSegments.last,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          file.path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const Icon(Icons.download, color: Colors.red),
        onTap: () => OpenFile.open(file.path),
        onLongPress: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete file?'),
              content: Text('Delete ${file.uri.pathSegments.last}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await file.delete();
            setState(() => downloadedFiles.remove(file));
          }
        },
        trailing: IconButton(
          icon: const Icon(Icons.share, color: Colors.red),
          onPressed: () => Share.shareXFiles([XFile(file.path)], text: 'Check this file'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'YouTube Mp3 Downloader',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter a YouTube Link",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.link, color: Colors.red),
                  hintText: 'https://youtube.com/watch?v=...',
                  filled: true,
                  fillColor: Colors.red.shade50,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.red.shade100,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 8),
              if (status.isNotEmpty)
                Text(
                  status,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              const SizedBox(height: 24),
              // Only one centered MP3 button
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => startDownload('audio'),
                  child: const Text(
                    'Start Download MP3',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(thickness: 1),
              const Text(
                'Downloaded Files',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                Column(
                  children: downloadedFiles
                      .map((file) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: _buildDownloadedFileTile(file),
                  ))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

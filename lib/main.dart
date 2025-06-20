import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const YouTubeDownloaderApp());
}

class YouTubeDownloaderApp extends StatelessWidget {
  const YouTubeDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Downloader',
      home: const YouTubeDownloaderPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class YouTubeDownloaderPage extends StatefulWidget {
  const YouTubeDownloaderPage({super.key});

  @override
  State<YouTubeDownloaderPage> createState() => _YouTubeDownloaderPageState();
}

class _YouTubeDownloaderPageState extends State<YouTubeDownloaderPage> {
  final TextEditingController _searchController = TextEditingController();
  String _status = '';

  Future<void> _downloadVideo() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _status = 'Searching YouTube...');
    var yt = YoutubeExplode();

    try {
      // Search YouTube for the query
      final searchResults = await yt.search.getVideos(query);

      if (searchResults.isEmpty) {
        setState(() => _status = 'No videos found.');
        return;
      }

      final video = searchResults.first;
      setState(() => _status = 'Fetching video info for: ${video.title}...');

      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.muxed.withHighestBitrate();

      if (streamInfo == null) {
        setState(() => _status = 'Error: No suitable stream found.');
        return;
      }

      final stream = yt.videos.streamsClient.get(streamInfo);

      final directory = await getApplicationDocumentsDirectory();
      final sanitizedTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${directory.path}/$sanitizedTitle.mp4';
      final file = File(filePath);

      var output = file.openWrite();

      setState(() => _status = 'Downloading: ${video.title}...');
      await stream.pipe(output);
      await output.flush();
      await output.close();

      setState(() => _status = 'Downloaded: $sanitizedTitle\nSaved to:\n$filePath');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      yt.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Downloader'),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search video title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _downloadVideo,
              icon: const Icon(Icons.download),
              label: const Text('Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

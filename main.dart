import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const AdFreeMusicApp());

class AdFreeMusicApp extends StatelessWidget {
  const AdFreeMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Music',
      theme: ThemeData.dark(useMaterial3: true),
      home: const SearchScreen(),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  // 1. Search YouTube via Piped API (Strips out ads)
  Future<void> _searchMusic(String query) async {
    setState(() => _isLoading = true);
    final response = await http.get(
      Uri.parse('https://pipedapi.kavin.rocks/search?q=$query&filter=music_songs'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _searchResults = data['items'];
        _isLoading = false;
      });
    }
  }

  // 2. Fetch the raw audio stream URL and play
  Future<void> _playSong(String videoId) async {
    final response = await http.get(
      Uri.parse('https://pipedapi.kavin.rocks/streams/$videoId'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Find the best audio-only stream (usually webm or m4a)
      final audioStreams = data['audioStreams'] as List;
      if (audioStreams.isNotEmpty) {
        final streamUrl = audioStreams.first['url'];
        await _player.setUrl(streamUrl);
        _player.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ad-Free Player')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a song...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchMusic(_searchController.text),
                ),
              ),
            ),
          ),
          if (_isLoading) const CircularProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                return ListTile(
                  leading: Image.network(item['thumbnail']),
                  title: Text(item['title']),
                  subtitle: Text(item['uploaderName']),
                  // Piped URLs contain the video ID, which we extract here
                  onTap: () => _playSong(item['url'].split('?v=')[1]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

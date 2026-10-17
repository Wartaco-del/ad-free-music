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
  
  // A list of multiple backup servers
  final List<String> apiServers = [
    'https://pipedapi.tokhmi.xyz',
    'https://piped-api.garudalinux.org',

    'https://pi.ggtyler.dev/api'
  ];

  // The engine that tries each server until one works
 Future<http.Response> _fetchWithFallback(String path) async {
    String lastError = "Unknown error";
    for (String server in apiServers) {
      try {
        // Increased timeout to 10 seconds to allow for slower public servers
        final response = await http.get(
          Uri.parse('$server$path')
        ).timeout(const Duration(seconds: 10)); 
        
        if (response.statusCode == 200) {
          return response; 
        } else {
          lastError = 'Server returned status ${response.statusCode}';
        }
      } catch (e) {
        lastError = e.toString(); // Save the actual error before moving on
        continue;
      }
    }
    // If it gets here, reveal the true reason the final server failed
    throw Exception('Last error: $lastError');
  }

  Future<void> _searchMusic(String query) async {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _searchResults = [];
    });
    
    try {
      final encodedQuery = Uri.encodeComponent(query);
      // Calls our new fallback engine instead of a single hardcoded URL
      final response = await _fetchWithFallback('/search?q=$encodedQuery&filter=music_songs');
      
      final data = json.decode(response.body);
      setState(() {
        _searchResults = data['items'];
      });
    } catch (e) {
      _showError('System Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playSong(String videoId) async {
    try {
      final response = await _fetchWithFallback('/streams/$videoId');
      final data = json.decode(response.body);
      final audioStreams = data['audioStreams'] as List;
      
      if (audioStreams.isNotEmpty) {
        final streamUrl = audioStreams.first['url'];
        await _player.setUrl(streamUrl);
        _player.play();
      } else {
         _showError('No audio stream found on this server.');
      }
    } catch (e) {
      _showError('Error playing: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
          if (_isLoading) const Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                return ListTile(
                  leading: item['thumbnail'] != null 
                    ? Image.network(item['thumbnail'], width: 50, height: 50, fit: BoxFit.cover) 
                    : const Icon(Icons.music_note),
                  title: Text(item['title'] ?? 'Unknown'),
                  subtitle: Text(item['uploaderName'] ?? ''),
                  onTap: () {
                     final url = item['url'] as String?;
                     if (url != null && url.contains('?v=')) {
                       _playSong(url.split('?v=')[1]);
                     } else {
                       _showError('Invalid song link.');
                     }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

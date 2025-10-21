import 'package:flutter/material.dart';
import 'package:postgrest/src/types.dart';
import '../main.dart';
import '../models/app_state.dart';

class KhaiwalPage extends StatefulWidget {
  const KhaiwalPage({super.key});

  @override
  _KhaiwalPageState createState() => _KhaiwalPageState();
}

class _KhaiwalPageState extends State<KhaiwalPage> {
  final TextEditingController _searchController = TextEditingController();
  bool loading = false;
  String _searchQuery = '';
  List<dynamic> searchResults = [];

  Future<void> searchKhaiwal(String query) async {
    bool isUUID = RegExp(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").hasMatch(query);

    final PostgrestList response;

    if (isUUID) {
      response = await supabase
          .from('khaiwals')
          .select('id, full_name, username, email, rate, edit_minutes, big_play_limit, timezone, refresh_diff, avatar_url, phone, message, is_super, is_premium')
          .eq('id', query);
    } else {
      response = await supabase
          .from('khaiwals')
          .select('id, full_name, username, email, rate, edit_minutes, big_play_limit, timezone, refresh_diff, avatar_url, phone, message, is_super, is_premium')
          .or('email.eq.$query,username.eq.$query');
    }

    if (response.isNotEmpty) {
      setState(() {
        searchResults = response;
      });
    } else {
      setState(() {
        searchResults = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No results found')),
      );
    }
  }

  Future<void> connectKhaiwal(Map<String, dynamic> khaiwal) async {
    setState(() {
      loading = true;
    });

    final isMismatch = await AppState().checkDeviceMismatch(context);
    if (isMismatch) return; // Halt if there's a mismatch

    final existingResponse = await supabase
        .from('khaiwals_players')
        .select('id, rate, commission, patti, balance, debt_limit, edit_minutes, big_play_limit, allowed')
        .eq('khaiwal_id', khaiwal['id'])
        .eq('player_id', AppState().currentUserProfileId);
        // .single();

    if (existingResponse.isNotEmpty && AppState().currentUserProfileId == khaiwal['id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot connect with yourself find another host')),
      );
      setState(() {
        loading = false;
      });
      return;
    } else if (existingResponse.isNotEmpty && AppState().kpId == existingResponse[0]['id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already connected to this host')),
      );
      setState(() {
        loading = false;
      });
      return;
    } else if (existingResponse.isNotEmpty && AppState().kpId != existingResponse[0]['id']) {
      AppState().kpId = existingResponse[0]['id'];
      AppState().kpRate = existingResponse[0]['rate'];
      AppState().kpCommission = existingResponse[0]['commission'];
      AppState().kpPatti = existingResponse[0]['patti'];
      AppState().balance = existingResponse[0]['balance'];
      AppState().debtLimit = existingResponse[0]['debt_limit'];
      AppState().editMinutes = existingResponse[0]['edit_minutes'];
      AppState().bigPlayLimit = existingResponse[0]['big_play_limit'];
      AppState().allowed = existingResponse[0]['allowed'];

      AppState().khaiwalId = khaiwal['id'];
      AppState().khaiwalName = khaiwal['full_name'] ?? '';
      AppState().khaiwalUserName = khaiwal['username'] ?? '';
      AppState().khaiwalEmail = khaiwal['email'] ?? '';
      AppState().khaiwalTimezone = khaiwal['timezone'] ?? 'UTC +05:30';
      AppState().refreshDifference = khaiwal['refresh_diff'] ?? 0;
      AppState().isSuper = khaiwal['is_super'] ?? false;
      AppState().isPremium = khaiwal['is_premium'] ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected to this host Successfully')),
      );
      AppState().currentTime = await AppState().getAccurateTimeWithTimeZone();
      // await AppState().fetchDataForCurrentMonth();
      await AppState().fetchGameNamesAndResults();
      await AppState().fetchGamesForCurrentDateOrTomorrow();
      await AppState().checkGamePlayExistence();

      // Update the kp_id in the players table
      await supabase
          .from('profiles')
          .update({'kp_id': existingResponse[0]['id']})
          .eq('id', AppState().currentUserProfileId);

      setState(() {
        loading = false;
      });
      // Close the KhaiwalPage
      Navigator.pop(context);

      return;
    }

    if (AppState().currentUserProfileId == khaiwal['id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You cannot connect with yourself find another host')),
      );
      setState(() {
        loading = false;
      });
      return;
    }

    final kpResponse = await supabase
        .from('khaiwals_players')
        .insert({
      'khaiwal_id': khaiwal['id'],
      'player_id': AppState().currentUserProfileId,
      'rate': khaiwal['rate'],
      'edit_minutes': khaiwal['edit_minutes'],
      'big_play_limit': khaiwal['big_play_limit'],
      // 'commission': 0,
      // 'patti': 0,
    }).select('id').single();

    if (kpResponse.isNotEmpty) {
      // Update the kp_id in the players table
      await supabase
          .from('profiles')
          .update({'kp_id': kpResponse['id']})
          .eq('id', AppState().currentUserProfileId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected successfully')),
      );
      await fetchAndSetKhaiwalDetails(khaiwal['id']);
      // Close the KhaiwalPage
      setState(() {
        loading = false;
      });
      Navigator.pop(context);
    } else {
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $kpResponse')),
      );
    }
  }

  Future<void> fetchAndSetKhaiwalDetails(String khaiwalId) async {
    await AppState().fetchKhaiwalDetails(khaiwalId);
    await AppState().fetchKhaiwalPlayerDetails(khaiwalId);
    // await AppState().fetchDataForCurrentMonth();
    await AppState().fetchGameNamesAndResults();
    await AppState().fetchGamesForCurrentDateOrTomorrow();
    await AppState().checkGamePlayExistence();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Host'),
        elevation: 0.0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blueAccent.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Modern Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by username, or email...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16.0),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.indigo),
                    onPressed: () {
                      setState(() {
                        _searchQuery = _searchController.text;
                      });
                      searchKhaiwal(_searchQuery.trim());
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: searchResults.isEmpty
                  ? const Center(
                child: Text(
                  'No results found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  final result = searchResults[index];
                  final avatarUrl = result['avatar_url'];
                  final fullName = result['full_name'] ?? 'Unknown';
                  final firstLetter = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

                  return ExpansionTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      backgroundColor: avatarUrl == null || avatarUrl.isEmpty
                          ? Colors.blueGrey // Background color for text icon
                          : Colors.transparent,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(
                        firstLetter,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ) : null,
                    ),
                    title: Text(
                      result['full_name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Default Rate: ${result['rate']}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email: ${result['email'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Username: ${result['username'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Phone: ${result['phone'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Message: ${result['message'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                connectKhaiwal(result);
                              },
                              icon: const Icon(Icons.link),
                              label: const Text('Connect'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



}

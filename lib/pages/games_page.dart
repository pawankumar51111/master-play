import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import 'play_page.dart';  // Import PlayPage
import '../main.dart';

class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  _GamesPageState createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  late DateTime currentTime;
  late DateTime tomorrowTime;
  late Timer _timer;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize currentTime with the accurate time from AppState
    currentTime = context.read<AppState>().currentTime;
    tomorrowTime = context.read<AppState>().currentTime.add(const Duration(days: 1));

    // Set up a timer to update the currentTime every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        currentTime = context.read<AppState>().currentTime.add(const Duration(seconds: 1));
        tomorrowTime = context.read<AppState>().currentTime.add(const Duration(days: 1, seconds: 1));
      });
    });
  }

  Future<void> _refreshGames() async {
    if (!(AppState().isSuper || AppState().isPremium)) {
      return; // Exit early if neither is true
    }
    // Notify the UI that loading has started
    setState(() {
      isLoading = true;
    });

    await context.read<AppState>().fetchGameResultsForCurrentDayAndYesterday();
    await context.read<AppState>().checkGamePlayExistence();

    // Notify the UI that loading has finished
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        // backgroundColor: Colors.orangeAccent,
        backgroundColor: Colors.transparent,
        elevation: 0.0, // Remove default shadow
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orangeAccent.shade200, Colors.orange.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          // Show a CircularProgressIndicator while data is being fetched
          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // if (appState.games.isEmpty) {
          //   return const Center(child: Text('No games found for today', style: TextStyle(fontSize: 18, color: Colors.grey),));
          // }

          // Filter active games
          final activeGames = appState.games.where((game) => game['is_active'] == true).toList();

          if (activeGames.isEmpty) {
            return const Center(child: Text('No games found for today', style: TextStyle(color: Colors.grey),));
          }

          return RefreshIndicator(
            onRefresh: _refreshGames, // Trigger refresh when pulled down
            child: ListView.separated(
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Colors.grey,
              ),
              itemCount: activeGames.length,
              itemBuilder: (context, index) {
                final game = activeGames[index];

                // Skip the game if 'off_day' is true
                if (game['is_active'] == false) {
                  return const SizedBox.shrink();
                }

                DateTime openTime;

                DateTime closeTime;
                DateTime closeTime1;

                DateTime lastBigPlayTime;

                DateTime lastEditTime;

                // Parse the open_time, close_time & edit_minutes
                try {
                  final openTimeParts = game['open_time'].split(':');
                  DateTime gameDate = DateTime.parse(game['game_date']);
                  openTime = DateTime.utc(
                    gameDate.year,
                    gameDate.month,
                    gameDate.day,
                    int.parse(openTimeParts[0]),
                    int.parse(openTimeParts[1]),
                    int.parse(openTimeParts[2]),
                  );

                  // Parse 'close_time_min' from the game and add it to openTime to create closeTime
                  closeTime = openTime.add(Duration(minutes: game['close_time_min']));
                  closeTime1 = closeTime.subtract(const Duration(seconds: 10));

                  // Parse 'last_big_play_min' from the game
                  lastBigPlayTime = openTime.add(Duration(minutes: game['big_play_min']));

                  // Parse the 'lastEditTime' based on 'closeTime'
                  lastEditTime = closeTime;

                  // Check AppState().editMinutes and subtract accordingly
                  if (AppState().editMinutes != -1 && AppState().editMinutes != 0) {
                    lastEditTime = lastEditTime.subtract(Duration(minutes: AppState().editMinutes, seconds: 5));
                  } else {
                    lastEditTime = lastEditTime.subtract(const Duration(seconds: 5));
                  }
                } catch (e) {
                  return ListTile(
                    title: Text(game['full_game_name']),
                    subtitle: const Text('Invalid time format'),
                  );
                }

                final isTimeOver = currentTime.isAfter(closeTime1);
                final isEditTimeOver = currentTime.isAfter(lastEditTime);
                final isBeforeOpenTime = currentTime.isBefore(openTime);

                final isTimeOver2 = tomorrowTime.isAfter(closeTime1);
                final isEditTimeOver2 = tomorrowTime.isAfter(lastEditTime);
                final isBeforeOpenTime2 = tomorrowTime.isBefore(openTime);

                final String status;
                final Color bgColor;
                final Icon icon;

                if (game['game_result'] != null && game['game_result'] != '') {
                  status = 'Declared';
                  bgColor = Colors.blue.shade50;
                  icon = const Icon(Icons.check_circle, color: Colors.blue, size: 16);
                } else if (game['off_day'] == true) {
                  status = 'Day Off';
                  bgColor = Colors.orange.shade50;
                  icon = const Icon(Icons.event_busy, color: Colors.orange, size: 16);
                } else if (game['pause'] == true && !isTimeOver) {
                  status = 'Paused';
                  bgColor = Colors.orange.shade50;
                  icon = const Icon(Icons.pause_circle_filled, color: Colors.grey, size: 16);
                } else if ((isBeforeOpenTime && !game['day_before']) || (isBeforeOpenTime2 && game['day_before'])) {
                  status = 'Not Open Yet';
                  bgColor = Colors.orange.shade50;
                  icon = const Icon(Icons.access_time, color: Colors.orange, size: 16);
                } else if ((!isBeforeOpenTime && !isTimeOver && !game['day_before']) ||
                    (!isBeforeOpenTime2 && !isTimeOver2 && game['day_before'])) {
                  status = 'Live';
                  bgColor = Colors.green.shade50;
                  icon = const Icon(Icons.play_circle_fill, color: Colors.green, size: 16);
                } else if ((isTimeOver && !game['day_before']) || (isTimeOver2 && game['day_before'])) {
                  status = 'Time Over';
                  bgColor = Colors.red.shade50;
                  icon = const Icon(Icons.stop_circle, color: Colors.red, size: 16);
                } else {
                  status = '';
                  bgColor = Colors.orange.shade50;
                  icon = const Icon(Icons.help_outline, color: Colors.grey, size: 16); // Default icon
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: bgColor,

                  child: ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between the children
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded( // Use Expanded to take available space
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Row for the icon and full_game_name
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Icon based on the game status
                                  // if (game['game_result'] != null && game['game_result'] != '')
                                  //   const Icon(Icons.check_circle, color: Colors.blue, size: 16)
                                  // else if (game['off_day'] == true)
                                  //   const Icon(Icons.event_busy, color: Colors.orange, size: 16)
                                  // else if (game['pause'] == true && !isTimeOver)
                                  //     const Icon(Icons.pause_circle_filled, color: Colors.grey, size: 16)
                                  //   else if ((isBeforeOpenTime && !game['day_before']) || (isBeforeOpenTime2 && game['day_before']))
                                  //       const Icon(Icons.access_time, color: Colors.orange, size: 16)
                                  //     else if ((!isBeforeOpenTime && !isTimeOver && !game['day_before']) ||
                                  //           (!isBeforeOpenTime2 && !isTimeOver2 && game['day_before']))
                                  //         const Icon(Icons.play_circle_fill, color: Colors.green, size: 16)
                                  //       else if ((isTimeOver && !game['day_before']) || (isTimeOver2 && game['day_before']))
                                  //           const Icon(Icons.stop_circle, color: Colors.red, size: 16),
                                  icon,
                                  const SizedBox(width: 8), // Add spacing between the icon and text
                                  // Full game name
                                  Expanded(
                                    child: Text(
                                      game['full_game_name'],
                                      style: const TextStyle(color: Colors.black, fontSize: 18),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],

                              ),
                            ],
                          ),
                        ),

                        Column(
                          children: [
                            Text(
                              AppState().formatGameDate(game['game_date']),
                              style: const TextStyle(color: Colors.grey, fontSize: 14), // Light grey color for the date
                            ),
                            // Status text
                            if (game['game_result'] != null && game['game_result'] != '')
                              Text('Result:${game['game_result']}', style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))

                            else Text(status, style: const TextStyle(color: Colors.grey, fontSize: 12),),

                            // else if (game['off_day'] == true)
                            //   const Text(
                            //     'Day Off',
                            //     style: TextStyle(color: Colors.grey, fontSize: 12), // Smaller, grey text
                            //   )
                            // else if (game['pause'] == true && !isTimeOver)
                            //     const Text(
                            //       'Paused',
                            //       style: TextStyle(color: Colors.grey, fontSize: 12), // Light grey for Paused
                            //     )
                            //   else if ((isBeforeOpenTime && !game['day_before']) || (isBeforeOpenTime2 && game['day_before']))
                            //       const Text(
                            //         'Not Open Yet',
                            //         style: TextStyle(color: Colors.grey, fontSize: 12), // Smaller, grey text
                            //       )
                            //     else if ((!isBeforeOpenTime && !isTimeOver && !game['day_before']) ||
                            //           (!isBeforeOpenTime2 && !isTimeOver2 && game['day_before']))
                            //         const Text(
                            //           'Live',
                            //           style: TextStyle(color: Colors.grey, fontSize: 12), // Smaller, grey text
                            //         )
                            //       else if ((isTimeOver && !game['day_before']) || (isTimeOver2 && game['day_before']))
                            //           const Text(
                            //             'Time Over',
                            //             style: TextStyle(color: Colors.grey, fontSize: 12), // Smaller, grey text
                            //           ),
                          ],
                        )
                        // Right-aligned game date
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        if (game['game_result'] != null && game['game_result'] != '')
                          // Text('Result: ${game['game_result']}', style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))
                          const Text('')

                        else if (game['off_day'] == true)
                          const Text('')

                        else if (game['pause'] == true && !isTimeOver)
                          const Text('Game is Paused')

                        else if ((isBeforeOpenTime && !game['day_before']) || (isBeforeOpenTime2 && game['day_before']))
                          Text('Game Opens at ${formatTimeTo12Hour(game['open_time'])}')

                          else if ((isTimeOver && !game['day_before']) || isTimeOver2 && game['day_before'])
                            const Text('Result Pending')

                          else
                                ElevatedButton(
                                  onPressed: () async {
                                    // Check if appState.gamePlayExists[game['id']] is true
                                    if (appState.gamePlayExists[game['id']] == true) {
                                      bool slotDataExists = await _doesSlotDataExist(game['id']); // Check if slot data exists
                                      if (slotDataExists) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PlayPage(
                                              gameId: game['id'],
                                              infoId: game['info_id'],
                                              fullGameName: game['full_game_name'],
                                              gameDate: game['game_date'],
                                              openTime: openTime,
                                              onlyOpenTime: game['open_time'],
                                              closeTime: closeTime,
                                              closeTimeMin: game['close_time_min'],
                                              lastBigPlayTime: lastBigPlayTime,
                                              lastBigPlayMinute: game['big_play_min'],
                                              isEditGame: false,
                                              isDayBefore: game['day_before'],
                                            ),
                                          ),
                                        );
                                      } else {
                                        // Handle the case where no slot_amount was found
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Refunded or No numbers found for this game.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        await AppState().checkGamePlayExistence();
                                      }
                                    } else {
                                      // Navigate directly without checking for slot data
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PlayPage(
                                            gameId: game['id'],
                                            infoId: game['info_id'],
                                            fullGameName: game['full_game_name'],
                                            gameDate: game['game_date'],
                                            openTime: openTime,
                                            onlyOpenTime: game['open_time'],
                                            closeTime: closeTime,
                                            closeTimeMin: game['close_time_min'],
                                            lastBigPlayTime: lastBigPlayTime,
                                            lastBigPlayMinute: game['big_play_min'],
                                            isEditGame: false,
                                            isDayBefore: game['day_before'],
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(appState.gamePlayExists[game['id']] == true ? 'Play More' : 'Play'),
                                ),

                        if (game['pause'] != true && !game['off_day'] && (!game['day_before'] && !isTimeOver && !isBeforeOpenTime && (game['game_result'] == null || game['game_result'] == '') && appState.gamePlayExists[game['id']] == true && appState.editMinutes != -1 && !isEditTimeOver)
                        || (game['day_before'] && !isTimeOver2 && !isBeforeOpenTime2 && (game['game_result'] == null || game['game_result'] == '') && appState.gamePlayExists[game['id']] == true && appState.editMinutes != -1 && !isEditTimeOver2)) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              bool slotDataExists = await _doesSlotDataExist(game['id']);
                              if (slotDataExists) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlayPage(
                                      gameId: game['id'],
                                      infoId: game['info_id'],
                                      fullGameName: game['full_game_name'],
                                      gameDate: game['game_date'],
                                      openTime: openTime,
                                      onlyOpenTime: game['open_time'],
                                      closeTime: closeTime,
                                      closeTimeMin: game['close_time_min'],
                                      lastBigPlayTime: lastBigPlayTime,
                                      lastBigPlayMinute: game['big_play_min'],
                                      isEditGame: true,
                                      isDayBefore: game['day_before'],
                                    ),
                                  ),
                                );
                              } else {
                                // Handle the case where no slot_amount was found
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Refunded or No numbers found for this game.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                await AppState().checkGamePlayExistence();
                              }
                            },
                            child: const Text('Edit'),
                          ),
                        ],

                        if (!game['off_day'] && (!game['day_before'] && appState.gamePlayExists[game['id']] == true && !isBeforeOpenTime)
                        || (game['day_before'] && appState.gamePlayExists[game['id']] == true && !isBeforeOpenTime2)) ...[
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              await _fetchAndShowSlotAmount(context, game['id'], game['full_game_name']);
                            },
                            child: const Text('View'),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      _showGameDetails(context, game, status, openTime, closeTime);
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showGameDetails(BuildContext context, Map<String, dynamic> game, String status, DateTime openTime, DateTime closeTime) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Game Name
                Text(
                  game['full_game_name'] ?? 'Unknown Game',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Game Date
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      AppState().formatGameDate(game['game_date']),
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Status: $status',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Open Time
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Open Time: ${formatTimeTo12Hour(game['open_time'])}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Close Time
                Row(
                  children: [
                    const Icon(Icons.lock_clock, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Close Time: ${formatTimeTo12Hour(closeTime.toIso8601String().substring(11))}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CLOSE'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _fetchAndShowSlotAmount(BuildContext context, int gameId, String gameName) async {
    // Show progress indicator while the data is being fetched
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog by tapping outside
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(), // Show a circular progress indicator
        );
      },
    );

    int kpId = AppState().kpId;
    // Fetch the existing slot_amount from the game_play table
    final existingEntryResponse = await supabase
        .from('game_play')
        .select('slot_amount')
        .eq('kp_id', kpId)
        .eq('game_id', gameId);

    if (existingEntryResponse.isNotEmpty) {
      // Extract the slot_amount from the response
      final slotAmount = existingEntryResponse[0]['slot_amount'];
      int totalInvested = 0;

      totalInvested = _parseAndCombineSlotAmount(slotAmount, totalInvested);  // Parse and combine slot amounts, update total


      Navigator.pop(context);
      // Show the dialog with the fetched slot amount
      _showSlotAmountDialog(context, slotAmount, gameName, totalInvested);
    } else {
      Navigator.pop(context);
      // Handle the case where no slot_amount was found
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refunded or No numbers found for this game.'),
          backgroundColor: Colors.red,
        ),
      );
      await AppState().checkGamePlayExistence();
    }
  }
  // Function to parse and combine slot_amount for multiple rows
  int _parseAndCombineSlotAmount(String slotAmountStr, int totalInvested) {
    List<String> pairs = slotAmountStr.split(' / ');

    for (String pair in pairs) {
      List<String> parts = pair.split('=');
      if (parts.length == 2) {
        int value = int.parse(parts[1]);
        totalInvested += value;  // Accumulate the total invested
      }
    }
    return totalInvested;  // Return the updated total
  }

  Future<bool> _doesSlotDataExist(int gameId) async {
    try {
      int kpId = AppState().kpId; // Get current user kpId

      // Fetch the existing slot_amount from the game_play table
      final response = await supabase
          .from('game_play')
          .select('id')
          .eq('kp_id', kpId)
          .eq('game_id', gameId);

      // Return true if slot data exists, otherwise return false
      return response.isNotEmpty;
    } catch (e) {
      // print('Error checking slot data existence: $e');
      return false; // Return false in case of an error
    }
  }


// Function to parse and format slot_amount
  String _formatSlotAmount(String slotAmount) {
    // Split the slot_amount string by ' / ' to get each 'key=value' pair
    final pairs = slotAmount.split(' / ');

    // Iterate through the pairs and format them
    final formattedPairs = pairs.map((pair) {
      final keyValue = pair.split('='); // Split each pair by '='
      if (keyValue.length == 2) {
        final key = keyValue[0];
        final value = keyValue[1];
        return '$key, ( $value )';  // Format it as 'key, ( value )'
      }
      return pair;  // Return the original pair if splitting failed
    }).join('\n');  // Join all formatted pairs with a newline

    return formattedPairs;  // Return the formatted string
  }

// Function to show slot_amount in a dialog
  void _showSlotAmountDialog(BuildContext context, String slotAmount, String gameName, int totalInvested) {
    final formattedSlotAmount = _formatSlotAmount(slotAmount);  // Format the slot_amount string

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(gameName),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formattedSlotAmount), // Show the formatted slot_amount
                const SizedBox(height: 16), // Add some space before showing the total
                Text('Total: $totalInvested', style: const TextStyle(fontWeight: FontWeight.bold)),  // Show the total invested amount
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String formatTimeTo12Hour(String time) {
    try {
      // Parse the 'HH:mm:ss' time string into a DateTime object
      DateTime parsedTime = DateFormat('HH:mm:ss').parse(time);

      // Format the parsed time into 'hh:mm a' format (12-hour time with AM/PM)
      return DateFormat('hh:mm a').format(parsedTime);
    } catch (e) {
      return time;
    }

  }


  @override
  void dispose() {
    // Cancel the timer when the widget is disposed to avoid memory leaks
    _timer.cancel();
    super.dispose();
  }

}

import 'dart:io';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:masterplay/pages/profile_page.dart';
import 'package:masterplay/pages/wallet_page.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/app_state.dart';
import 'khaiwal_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  List<dynamic> searchResults = [];

  @override
  void initState() {
    super.initState();
    if(!AppState().initialized){
      initializeAppState();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> initializeAppState() async {
    await AppState().initialize();
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _refreshGameResults() async {
    if (!(AppState().isSuper || AppState().isPremium)) {
      return; // Exit early if neither is true
    }
    setState(() {
      isLoading = true; // Set loading to true before fetching data
    });

    await context.read<AppState>().fetchGameResultsForCurrentDayAndYesterday();
    await context.read<AppState>().checkGamePlayExistence();

    setState(() {
      isLoading = false; // Set loading to false after fetching data
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        elevation: 0.0, // Remove default shadow
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blueAccent.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Consumer<AppState>(
            builder: (context, appState, child) {
              return Row(
                children: [
                  InkWell(
                    onTap: () {
                      // Navigate to the WalletPage when the row is pressed
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const WalletPage()),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet), // Wallet icon
                        const SizedBox(width: 4),
                        Text(
                          '${appState.balance}', // Display the wallet value
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16), // Spacing between the wallet value and the notification icon
                ],
              );
            },
          ),
        ],
      ),

        drawer: Consumer<AppState>(
          builder: (context, appState, child) {
            return Drawer(
              child: ListView(
                children: [
                  UserAccountsDrawerHeader(
                    accountName: Text(
                      appState.currentUserFullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    accountEmail: Text(appState.currentUserEmailId),
                    currentAccountPicture: GestureDetector(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: (appState.avatarUrl.isNotEmpty)
                            ? NetworkImage(appState.avatarUrl)
                            : null,
                        child: (appState.avatarUrl.isEmpty)
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.manage_accounts, color: Colors.blueGrey),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => ProfilePage()),
                      );
                    },
                  ),
                  if (appState.khaiwalId.isNotEmpty)
                    Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.link_sharp, color: Colors.blueGrey),
                          title: const Text('Host'),
                          subtitle: Text('Name: ${appState.khaiwalName}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (String result) async {
                              if (result == 'Disconnect') {
                                bool? confirmDisconnect = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Confirm Disconnect'),
                                      content: const Text('Are you sure you want to disconnect from host?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(false);
                                          },
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(true);
                                          },
                                          child: const Text('Disconnect'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (confirmDisconnect == true) {
                                  final isMismatch = await appState.checkDeviceMismatch(context);
                                  if (isMismatch) return; // Halt if there's a mismatch
                                  await appState.resetState();
                                }
                              } else if (result == 'View Profile') {
                                await _viewHostProfile();
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem(
                                value: 'View Profile',
                                child: Text('View Profile'),
                              ),
                              const PopupMenuItem(
                                value: 'Disconnect',
                                child: Text('Disconnect'),
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.calendar_month, color: Colors.blueGrey),
                          title: const Text('View Months'),
                          onTap: () {
                            Navigator.of(context).pop();
                            _showSelectMonthDialog();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.contact_phone, color: Colors.blueGrey),
                          title: const Text('Contact Host'),
                          onTap: () async {
                            await _contactHost();
                          },
                        ),
                      ],
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.search, color: Colors.blueGrey),
                      title: const Text('Find Host'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const KhaiwalPage(),
                          ),
                        );
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.blueGrey),
                    title: const Text('Sign Out'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showSignOutDialog();
                    },
                  ),
                ],
              ),
            );
          },
        ),

        body: Consumer<AppState>(
          builder: (context, appState, child) {
            return isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _refreshGameResults,
              child: appState.gameNames.isEmpty
                  ? ListView(
                children: const [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 200), // Adjust as needed
                      child: Text(
                        'No games found for the current month',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ) : DataTable2(
                border: TableBorder.all(color: Colors.grey.shade300),
                headingRowColor: WidgetStateProperty.all(Colors.blue.shade100),
                columnSpacing: 0,
                horizontalMargin: 4,
                minWidth: _calculateMinWidth(appState.gameNames.length),
                fixedLeftColumns: 1, // Fix the first column (Date)
                columns: [
                  const DataColumn2(
                    label: Center(
                      child: Text(
                        'Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center, // Ensures the alignment inside the Text
                      ),
                    ),
                    fixedWidth: 100,
                  ),
                  ...appState.gameNames.map(
                        (name) => DataColumn2(
                      label: Center(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // fixedWidth: 70,
                    ),
                  ),
                ],
                rows: _generateDataRows(appState),
              ),
            );
          },
        )
    );
  }

  double _calculateMinWidth(int length) {
    if (length <= 2) {
      return 400;
    } else if (length == 3) {
      return 450;
    } else if (length == 4) {
      return 500;
    } else if (length == 5) {
      return 550;
    } else {
      return 550 + ((length - 5) * 80); // Add 80 for each additional column after 5
    }
  }

  Future<void> _showSelectMonthDialog() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog by tapping outside
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(), // Show a circular progress indicator
        );
      },
    );
    // Fetch the map of months and associated info_ids
    Map<String, List<int>> monthsMap = await fetchUserMonths();

    Navigator.of(context).pop(); // Dismiss loading dialog

    if (monthsMap.isEmpty) {
      context.showSnackBar('No months available to show', isError: true);
      return;
    }

    // Extract the list of months (keys from the map)
    List<String> months = monthsMap.keys.toList();

    final selectedMonth = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Month'),
          content: SingleChildScrollView(
            child: Column(
              children: months.map((month) {
                return ListTile(
                  title: Text(month),
                  onTap: () => Navigator.of(context).pop(month),
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedMonth != null) {
      List<int> selectedMonthInfoIds = monthsMap[selectedMonth] ?? [];

      await _fetchDataForSelectedMonth(selectedMonthInfoIds, selectedMonth);
      context.showSnackBar('Selected month: $selectedMonth');
    }
  }

  Future<Map<String, List<int>>> fetchUserMonths() async {
    try {
      // First query to fetch 'id' from 'game_info'
      final gameInfoResponse = await supabase
          .from('game_info')
          .select('id')
          .eq('khaiwal_id', AppState().khaiwalId);

      if (gameInfoResponse.isEmpty) {
        // context.showSnackBar('Error fetching months', isError: true);
        return {};
      }

      // Collect all info_ids to query games table
      List<int> infoIds = gameInfoResponse.map((info) => info['id'] as int).toList();

      // Build an OR filter string for all the infoIds
      final orFilter = infoIds.map((id) => 'info_id.eq.$id').join(',');

      // Fetch game dates and info_ids
      final response = await supabase
          .from('games')
          .select('info_id, game_date')
          .or(orFilter);

      List<dynamic> data = response as List<dynamic>;

      // Sort the games data by 'game_date' before processing it
      data.sort((a, b) {
        DateTime gameDateA = DateTime.parse(a['game_date']);
        DateTime gameDateB = DateTime.parse(b['game_date']);
        return gameDateA.compareTo(gameDateB); // Ascending order
      });

      // Create a map of months and the corresponding list of info_ids
      Map<String, List<int>> monthToInfoIdsMap = {};

      for (var game in data) {
        DateTime date = DateTime.parse(game['game_date']);
        String month = DateFormat.yMMM().format(date);  // Format date to "Oct 2024"
        int infoId = game['info_id'];

        // Add the info_id to the correct month
        if (monthToInfoIdsMap.containsKey(month)) {
          monthToInfoIdsMap[month]!.add(infoId);
        } else {
          monthToInfoIdsMap[month] = [infoId];
        }
      }

      return monthToInfoIdsMap;
    } catch (error) {
      context.showSnackBar('Error fetching months', isError: true);
      return {};
    }
  }

  Future<void> _fetchDataForSelectedMonth(List<int> infoIds, String selectedMonth) async {
    try {
      setState(() {
        isLoading = true;
      });
      if (AppState().user == null) return;

      final DateFormat format = DateFormat.yMMM();
      final DateTime monthDate = format.parse(selectedMonth);
      final firstDayOfMonth = DateTime.utc(monthDate.year, monthDate.month, 1);
      final lastDayOfMonth = DateTime.utc(monthDate.year, monthDate.month + 1, 0);

      // Build an OR filter string for all the infoIds
      final gameInfoFilter = infoIds.map((id) => 'id.eq.$id').join(',');
      final gamesFilter = infoIds.map((id) => 'info_id.eq.$id').join(',');

      // First query to fetch 'id' and 'short_game_name' from 'game_info'
      final gameInfoResponse = await supabase
          .from('game_info')
          .select('id, short_game_name, sequence')
          .or(gameInfoFilter);

      List<dynamic> gameInfoData = gameInfoResponse as List<dynamic>;

      if (gameInfoData.isEmpty) {
        AppState().gameNames = [];
        // AppState().games = []; because if selected month is null but don't want current days games to empty
        AppState().gameResults = {};
        AppState().notifyListeners();
        return;
      }
      // Sort gameInfoData by 'id' (infoId) to maintain sequence
      gameInfoData.sort((a, b) => a['id'].compareTo(b['id']));

      // Sort gameInfoData by 'sequence', handling null values by assigning them the lowest priority
      gameInfoData.sort((a, b) {
        final sequenceA = a['sequence'] ?? double.infinity; // Null goes to the end
        final sequenceB = b['sequence'] ?? double.infinity;
        return sequenceA.compareTo(sequenceB);
      });

      // Create a map of info_id -> short_game_name
      // Map<int, String> gameInfoMap = {
      //   for (var info in gameInfoData) info['id']: info['short_game_name']
      // }; now direcly using the gameInfoData

      final response = await supabase
          .from('games')
          .select('id, info_id, game_date, game_result')
          .or(gamesFilter)
          .gte('game_date', firstDayOfMonth.toIso8601String())
          .lte('game_date', lastDayOfMonth.toIso8601String());

      if (response.isEmpty) {
        AppState().gameNames = [];
        AppState().gameResults = {};
        AppState().notifyListeners();
        return;
      }

      List<dynamic> gamesData = response as List<dynamic>;
      if (gamesData.isEmpty) {
        AppState().notifyListeners(); // Notify listeners when no data is found
        return;
      }

      // Sort the games data by 'game_date' before processing it
      gamesData.sort((a, b) {
        DateTime gameDateA = DateTime.parse(a['game_date']);
        DateTime gameDateB = DateTime.parse(b['game_date']);
        return gameDateA.compareTo(gameDateB); // Ascending order
      });

      Map<String, List<Map<String, dynamic>>> results = {};
      Set<String> newGameNames = {};

      // for (var game in gamesData) {
      //   int infoId = game['info_id'];
      //   String shortGameName = gameInfoMap[infoId] ?? 'Unknown';
      //
      //   if (!results.containsKey(shortGameName)) {
      //     results[shortGameName] = [];
      //   }
      //   results[shortGameName]?.add(game as Map<String, dynamic>);
      //   newGameNames.add(shortGameName);
      // } // now using the gameInfoData directly

      for (var info in gameInfoData) {
        final infoId = info['id'];
        final shortGameName = info['short_game_name'];

        if (!results.containsKey(shortGameName)) {
          results[shortGameName] = [];
        }

        for (var game in gamesData) {
          if (game['info_id'] == infoId) {
            results[shortGameName]?.add(game as Map<String, dynamic>);
          }
        }

        // Add game names in the sorted sequence of infoId
        newGameNames.add(shortGameName);
      }

      setState(() {
        AppState().gameNames = newGameNames.toList();
        AppState().gameResults = results;
        // selectMonth = monthDate;
      });
      setState(() {
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      context.showSnackBar('Error fetching data for selected month', isError: true);
    }
  }

  List<DataRow> _generateDataRows(AppState appState) {
    Set<String> allDates = appState.gameResults.values
        .expand((results) => results.map((result) => result['game_date'] as String))
        .toSet();

    return allDates.map((date) {
      String formattedDate = appState.formatGameDate(date);
      List<DataCell> cells = [
        DataCell(Center(child: Text(formattedDate))),
        ...appState.gameNames.map((name) {
          final result = appState.gameResults[name]?.firstWhere(
                (result) => result['game_date'] == date,
            orElse: () => {'game_date': date, 'game_result': ''},
          );
          return DataCell(
            GestureDetector(
              // onTap: () => _onGameResultTap(
              //   result?['id'],
              //   result?['info_id'],
              //   name,
              //   date,
              //   result?['game_result'] ?? '',
              // ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: result?['game_result'] != null && result!['game_result'] != ''
                        ? Colors.green.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    result?['game_result'] ?? '  ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green
                    ),
                    // textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }),
      ];
      return DataRow(cells: cells);
    }).toList();
  }

  Future<void> _viewHostProfile() async {
    try {
      final hostProfileResponse = await supabase
          .from('khaiwals')
          .select('full_name, email, username, rate')
          .eq('id', AppState().khaiwalId)
          .maybeSingle();

      if (hostProfileResponse != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Host Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SelectableText('ID: ${AppState().khaiwalId}\n'), not safe to public uuid
                    SelectableText('Name: ${hostProfileResponse['full_name']}\n'),
                    SelectableText('Email: ${hostProfileResponse['email']}\n'),
                    SelectableText('Username: ${hostProfileResponse['username']}\n'),
                    SelectableText('Default Rate: ${hostProfileResponse['rate']}'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      } else {
        // Show a message if the profile is not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Host profile not found.')),
        );
      }
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _contactHost() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent closing the dialog by tapping outside
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(), // Show a circular progress indicator
          );
        },
      );

      final contactResponse = await supabase
          .from('khaiwals')
          .select('phone, message, email')
          .eq('id', AppState().khaiwalId)
          .maybeSingle();

      Navigator.of(context).pop(); // Dismiss loading dialog

      if (contactResponse != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            // Prepare a list of contact options dynamically
            final List<Widget> contactOptions = [];

            // Phone Option
            if (contactResponse['phone'] != null && contactResponse['phone'].toString().isNotEmpty) {
              contactOptions.add(
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone'),
                  subtitle: SelectableText(contactResponse['phone']),
                  onTap: () {
                    launchUrl(Uri.parse('tel:${contactResponse['phone']}'));
                  },
                ),
              );
            }

            // Message Option
            if (contactResponse['message'] != null && contactResponse['message'].toString().isNotEmpty) {
              contactOptions.add(
                ListTile(
                  leading: const Icon(Icons.message),
                  title: const Text('Message'),
                  subtitle: SelectableText(contactResponse['message']),
                  onTap: () {
                    launchUrl(Uri.parse('sms:${contactResponse['message']}'));
                  },
                ),
              );
            }

            // Gmail Option
            if (contactResponse['email'] != null && contactResponse['email'].toString().isNotEmpty) {
              contactOptions.add(
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Gmail'),
                  subtitle: SelectableText(contactResponse['email']),
                  onTap: () {
                    final email = contactResponse['email'];
                    if (email != null) {
                      final Uri emailUri = Uri(
                        scheme: 'mailto',
                        path: email,
                        queryParameters: {
                          'subject': 'MasterPlay',  // Add the subject here
                        },
                      );
                      launchUrl(emailUri);
                    }
                  },
                ),
              );
            }


            return AlertDialog(
              title: const Text('Contact Host'),
              content: contactOptions.isNotEmpty
                  ? Column(
                mainAxisSize: MainAxisSize.min,
                children: contactOptions,
              )
                  : const Text('No contact information available.'), // Show this if all are null or empty
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact details not found.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }






  Future<void> _showSignOutDialog() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      _signOut();
    }
  }

  Future<void> _signOut() async {
    try {
      Navigator.of(context).pop(); // Dismiss the dialog

      await supabase.auth.signOut();
      await Supabase.instance.client.dispose();

      // Sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
      }

      await AppState().resetState();

      // Close the app after successful sign out
      // SystemNavigator.pop();
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      exit(0); // Forcefully terminate the app


    } on AuthException catch (error) {
      context.showSnackBar(error.message, isError: true);
    } catch (error) {
      context.showSnackBar('Unexpected error occurred', isError: true);
    }
  }




}

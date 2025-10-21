import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:ntp/ntp.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../main.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  late String currentUserProfileId = '';
  late String currentUserEmailId = '';
  late String currentUserFullName = '';
  // late DateTime globalDateTime;
  final user = supabase.auth.currentUser;

  String khaiwalId = '';
  String khaiwalName = '';
  String khaiwalUserName = '';
  String khaiwalEmail = '';
  String khaiwalTimezone = '';
  int refreshDifference = 0;

  String deviceId = '';
  String avatarUrl = '';

  late DateTime currentTime;
  late Timer _timer;

  int kpId = 0;
  int kpRate = 0;
  int kpCommission = 0;
  int kpPatti = 0;
  num balance = 0;
  int debtLimit = 0;
  int bigPlayLimit = 0;
  int editMinutes = -1;
  bool? allowed;
  bool? appAccess;

  bool isSuper = false;
  bool isPremium = false;

  int nullActionCount = 0;

  String updateType = '';
  int currentVersion = 0;
  int minVersion = 0;
  int maxVersion = 0;

  // late bool editGames = false;

  List<String> gameNames = [];
  Map<String, List<Map<String, dynamic>>> gameResults = {};
  List<Map<String, dynamic>> games = [];
  Map<int, bool> gamePlayExists = {};

  bool initialized = false;

  Future<void> initialize() async {

    await _checkAppVersion();
    if (updateType.isNotEmpty){
      appAccess = false;
      return;
    }

    await _getCurrentDeviceId();
    await fetchUserProfileId();
    // currentTime = await getAccurateTimeWithTimeZone(); // now inside fetchUserProfileId();

    // Start timer to periodically update accurateCurrentTime
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      currentTime = currentTime.add(const Duration(seconds: 1));
      if (currentTime.hour == 0 && currentTime.minute == 0 && currentTime.second == 0) {
        // await fetchDataForCurrentMonth();
        await fetchGameNamesAndResults();
        await fetchGamesForCurrentDateOrTomorrow();

      }
    });

    // Start another timer to refresh time every minute
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      await refreshTime();
      notifyListeners(); // Notify listeners if you want to update the UI
    });


    await checkGamePlayExistence();
    initialized = true;
    notifyListeners();
  }

  Future<void> _checkAppVersion() async {
    try {
      // Fetch the app's build number (version code)
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersion = int.parse(packageInfo.buildNumber); // e.g., 10

      // Fetch the configuration for the app version from Supabase
      final response = await supabase
          .from('user_app_config')
          .select('min_version, max_version, force_update')
          .eq('id', 1) // Adjust this for iOS if needed
          .maybeSingle();

      if (response != null) {
        minVersion = response['min_version'] ?? 0;
        maxVersion = response['max_version'] ?? 0;
        final maxForceUpdate = response['force_update'] ?? false;

        if (currentVersion < minVersion) {
          // Handle version lower than min_version
          updateType = 'min_version';
          // _showUpdateDialog("App version is too old. Please update the app.");
        } else if (maxForceUpdate && currentVersion < maxVersion) {
          // Handle version higher than max_version (optional check)
          updateType = 'force_update';
          // _showUpdateDialog("Your app version is not supported anymore. Please update.");
        }
      }
    } catch (error) {
      if (kDebugMode) {
        print("Error checking app version: $error");
      }
    }
  }

  // Method to fetch the current device ID
  Future<void> _getCurrentDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id ?? ''; // Unique Android ID
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? ''; // Unique iOS ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  Future<void> fetchUserProfileId() async {
    if (user != null) {
      final playerResponse = await supabase
          .from('profiles')
          .select('id, email, full_name, kp_id, avatar_url, device_id')
          .eq('id', user!.id);

      if (playerResponse.isEmpty) {
        final khaiwalResponse = await supabase
            .from('khaiwals')
            .select('id, email, full_name')
            .eq('id', user!.id);

        if (khaiwalResponse.isNotEmpty) {
          currentUserProfileId = khaiwalResponse[0]['id'] ?? '';
          currentUserFullName = khaiwalResponse[0]['full_name'] ?? '';
          await supabase.from('profiles').insert(khaiwalResponse);
        } else {
          // Insert a new profile if both responses are empty
          await supabase.from('profiles').insert({
            'id': user!.id,
            'email': user!.email!,
            'full_name': user!.userMetadata?['full_name'],
          });

          // Set default values after insertion
          currentUserProfileId = user!.id;
          currentUserFullName = user!.userMetadata?['full_name'] ?? '';
          currentUserEmailId = user!.email!;
        }
      } else {
        currentUserProfileId = playerResponse[0]['id'] ?? '';
        currentUserFullName = playerResponse[0]['full_name'] ?? '';
        avatarUrl = playerResponse[0]['avatar_url'] ?? '';

        if (playerResponse[0]['device_id'] != deviceId){
          await updateDeviceId();
        }

        if (playerResponse[0]['kp_id'] != null){
          kpId = playerResponse[0]['kp_id'] ?? 0;
        }
      }
      if (playerResponse.isNotEmpty && kpId != 0) {
        await fetchKhaiwalPlayerByID(kpId);
        await fetchKhaiwalDetails(khaiwalId);
        await refreshTime();
        // await fetchDataForCurrentMonth();
        await fetchGameNamesAndResults();
        await fetchGamesForCurrentDateOrTomorrow();

      } else if (kpId == 0){
        await refreshTime();
      }
      currentUserEmailId = user!.email!;
    }
  }

  Future<DateTime> getOnlineDateTime() async {
    try {
      DateTime currentTime = await NTP.now();
      return currentTime.toUtc();
    } catch (e) {
      // print('Error fetching time: $e');
      return fetchSupabaseDateTime(); // Fallback to device time in case of an error
    }
  }

  Future<DateTime> fetchSupabaseDateTime() async {
    try {
      // Use Supabase to fetch current time
      final response = await supabase.rpc('get_supabase_time');

      if (response != null) {
        return DateTime.parse(response as String).toUtc();
      } else {
        throw Exception('Failed to fetch time');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching time');
      }
      _terminateApp();
      throw Exception('All time-fetching methods failed');
    }
  }

  // Function to terminate the app
  void _terminateApp() {
    SystemChannels.platform.invokeMethod('SystemNavigator.pop'); // Close the app
    exit(0); // Forcefully terminate the app
  }


  Future<DateTime> fetchHttpDateTime() async {
    final response = await http.get(Uri.parse('http://worldtimeapi.org/api/timezone/Etc/UTC'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return DateTime.parse(data['utc_datetime']);
    } else {
      throw Exception('Failed to load date and time');
    }
  }

  DateTime mergeTimezoneWithUTC(DateTime utcTime, String khaiwalTimezone) {
    // Extract the sign (+ or -), hours, and minutes from khaiwalTimezone string
    final timezonePattern = RegExp(r'UTC ([+-])(\d{2}):(\d{2})');
    final match = timezonePattern.firstMatch(khaiwalTimezone);

    if (match != null) {
      String sign = match.group(1)!; // '+' or '-'
      int hours = int.parse(match.group(2)!); // Hours part
      int minutes = int.parse(match.group(3)!); // Minutes part

      // Convert hours and minutes to a Duration
      Duration offset = Duration(hours: hours, minutes: minutes);

      // Adjust UTC time based on the sign of the timezone
      if (sign == '+') {
        return utcTime.add(offset);
      } else {
        return utcTime.subtract(offset);
      }
    }

    // Return UTC time if parsing fails (fallback)
    return utcTime;
  }

  Future<DateTime> getAccurateTimeWithTimeZone() async {
    // DateTime time = DateTime.now().toUtc();
    // return time.add(const Duration(minutes: 330));
    try {
      // Get the current UTC time from the internet
      DateTime utcTime = await getOnlineDateTime();

      // Merge UTC time with timezone
      return mergeTimezoneWithUTC(utcTime, khaiwalTimezone);
    } catch (e) {
      if (kDebugMode) {
        print('Error merging time with timezone: $e');
      }
      DateTime time = DateTime.now().toUtc();
      return time.add(const Duration(minutes: 330)); // Fallback to device time in case of an error
    }
  }

  Future<void> refreshTime() async {
    currentTime = await getAccurateTimeWithTimeZone();
  }



  Future<void> checkGamePlayExistence() async {

    for (var game in games) {
      final gamePlayResponse = await supabase
          .from('game_play')
          .select('id')
          .eq('kp_id', kpId)
          .eq('game_id', game['id']);

      if (gamePlayResponse.isNotEmpty) {
        gamePlayExists[game['id']] = true;
      } else {
        gamePlayExists[game['id']] = false;
      }
    }

  }

  Future<void> fetchKhaiwalPlayerByID(int kpId) async {
    final khaiwalPlayerResponse = await supabase
        .from('khaiwals_players')
        .select('khaiwal_id, rate, commission, patti, balance, debt_limit, big_play_limit, edit_minutes')
        .eq('id', kpId)
        .single();

    if (khaiwalPlayerResponse.isNotEmpty) {
      khaiwalId = khaiwalPlayerResponse['khaiwal_id'] ?? '';
      kpRate = khaiwalPlayerResponse['rate'] ?? 0;
      kpCommission = khaiwalPlayerResponse['commission'] ?? 0;
      kpPatti = khaiwalPlayerResponse['patti'] ?? 0;
      balance = khaiwalPlayerResponse['balance'] ?? 0;
      debtLimit = khaiwalPlayerResponse['debt_limit'] ?? 0;
      editMinutes = khaiwalPlayerResponse['edit_minutes'] ?? -1;
      bigPlayLimit = khaiwalPlayerResponse['big_play_limit'] ?? 0;

    }
  }


  Future<void> fetchKhaiwalDetails(String khaiwalIds) async {
    final khaiwalResponse = await supabase
        .from('khaiwals')
        .select('id, full_name, username, email, timezone, refresh_diff, is_super, is_premium')
        .eq('id', khaiwalIds)
        .single();

    if (khaiwalResponse.isNotEmpty) {
      khaiwalId = khaiwalResponse['id'];
      khaiwalName = khaiwalResponse['full_name'] ?? '';
      khaiwalUserName = khaiwalResponse['username'] ?? '';
      khaiwalEmail = khaiwalResponse['email'] ?? '';
      khaiwalTimezone = khaiwalResponse['timezone'] ?? 'UTC +05:30';
      refreshDifference = khaiwalResponse['refresh_diff'] ?? 0;
      isSuper = khaiwalResponse['is_super'] ?? false;
      isPremium = khaiwalResponse['is_premium'] ?? false;
      // notifyListeners();
    }
  }

  Future<void> fetchKhaiwalPlayerDetails(String khaiwalId) async {
    final khaiwalPlayerResponse = await supabase
        .from('khaiwals_players')
        .select('id, rate, edit_minutes, big_play_limit, commission, patti')
        .eq('khaiwal_id', khaiwalId)
        .eq('player_id', currentUserProfileId)
        .single();

    if (khaiwalPlayerResponse.isNotEmpty) {
      kpId = khaiwalPlayerResponse['id'];
      kpRate = khaiwalPlayerResponse['rate'];
      kpCommission = khaiwalPlayerResponse['commission'];
      kpPatti = khaiwalPlayerResponse['patti'];
      editMinutes = khaiwalPlayerResponse['edit_minutes'];
      bigPlayLimit = khaiwalPlayerResponse['big_play_limit'];
      // notifyListeners();
    }
  }

  // Future<void> fetchDataForCurrentMonth() async {
  //   try {
  //     if (khaiwalId.isEmpty) return;
  //
  //     DateTime liveTime = refreshDifference != 0
  //         ? currentTime.add(Duration(minutes: refreshDifference))
  //         : currentTime;
  //
  //     final now = liveTime;
  //     final firstDayOfMonth = DateTime.utc(now.year, now.month, 1);
  //     final lastDayOfMonth = DateTime.utc(now.year, now.month + 1, 0);
  //     final currentDate = DateTime.utc(now.year, now.month, now.day);
  //     final tomorrowDate = DateTime.utc(now.year, now.month, now.day + 1);
  //
  //     final response = await supabase
  //         .from('games')
  //         .select('id, game_date, short_game_name, full_game_name, game_result, open_time, close_time_min, last_big_play_min, result_time_min, off_day, day_before')
  //         .eq('khaiwal_id', khaiwalId)
  //         .not('active', 'is', 'false')
  //         .gte('game_date', firstDayOfMonth.toIso8601String())
  //         .lte('game_date', lastDayOfMonth.toIso8601String())
  //         .order('game_date', ascending: true);
  //
  //     if (response.isEmpty){
  //       gameNames = [];
  //       gameResults = {};
  //       games = [];
  //       return;
  //     }
  //
  //     List<dynamic> data = response as List<dynamic>;
  //     if (data.isEmpty) {
  //       notifyListeners(); // Notify listeners when no data is found
  //       return;
  //     }
  //
  //     Map<String, List<Map<String, dynamic>>> results = {};
  //     Set<String> newGameNames = {};
  //     List<Map<String, dynamic>> gamesForCurrentDate = [];
  //
  //     for (var game in data) {
  //       String shortGameName = game['short_game_name'];
  //       DateTime gameDate = DateTime.parse(game['game_date']);
  //       bool dayBefore = game['day_before'] ?? false; // Fetch the day_before value
  //
  //       if (!results.containsKey(shortGameName)) {
  //         results[shortGameName] = [];
  //       }
  //       results[shortGameName]?.add(game as Map<String, dynamic>);
  //       newGameNames.add(shortGameName);
  //       // Check if the game is for the current date or tomorrow based on day_before
  //       DateTime targetDate = dayBefore ? tomorrowDate : currentDate;
  //       if (gameDate.year == targetDate.year &&
  //           gameDate.month == targetDate.month &&
  //           gameDate.day == targetDate.day) {
  //         gamesForCurrentDate.add(game as Map<String, dynamic>);
  //       }
  //     }
  //
  //     // Sort gamesForCurrentDate by 'close_time_min'
  //     gamesForCurrentDate.sort((a, b) {
  //       // Parse close_time_min from both games as integers
  //       int closeTimeMinA = a['close_time_min'];
  //       int closeTimeMinB = b['close_time_min'];
  //
  //       // Compare the close_time_min values
  //       return closeTimeMinA.compareTo(closeTimeMinB);
  //     });
  //
  //
  //     gameNames = newGameNames.toList();
  //     gameResults = results;
  //     games = gamesForCurrentDate; // Assign only the games for the current date
  //
  //     notifyListeners(); // Notify listeners after fetching data
  //   } catch (error) {
  //     // context.showSnackBar('Error fetching data for current month', isError: true);
  //   }
  // }

  Future<void> updateWallet() async {
    final khaiwalPlayerResponse = await supabase
        .from('khaiwals_players')
        .select('balance')
        .eq('id', kpId)
        .maybeSingle();

    if (khaiwalPlayerResponse != null) {
      balance = khaiwalPlayerResponse['balance'];
      // debtLimit = khaiwalPlayerResponse['debt_limit'];
      // editGames = khaiwalPlayerResponse['edit_games'];
      notifyListeners();
    } else {
      balance = 0;
      notifyListeners();
    }
  }

  Future<void> updateNullActionCount() async {
    // Fetch null actions from 'kp_logs'
    final kpResponse = await supabase
        .from('kp_logs')
        .select('action')
        .or('action.is.null')
        .eq('kp_id', kpId);

    // Count the number of records where action is null
    nullActionCount = kpResponse.length;

    if (nullActionCount > 0) {
      notifyListeners();
    }
  }


  Future<void> fetchGameNamesAndResults() async {
    try {
      if (khaiwalId.isEmpty) return;

      final now = getLiveTime();
      final firstDayOfMonth = DateTime.utc(now.year, now.month, 1);
      final lastDayOfMonth = DateTime.utc(now.year, now.month + 1, 0);

      // First query to fetch 'id' and 'short_game_name' from 'game_info'
      final gameInfoResponse = await supabase
          .from('game_info')
          .select('id, short_game_name, sequence')
          .not('is_active', 'is', 'false')
          .eq('khaiwal_id', khaiwalId);

      if (gameInfoResponse.isEmpty) {
        gameNames = [];
        gameResults = {};
        games = [];
        notifyListeners(); // No data found in 'game_info'
        return;
      }

      List<dynamic> gameInfoData = gameInfoResponse as List<dynamic>;

      // Sort gameInfoData by 'id' (infoId) to maintain sequence
      gameInfoData.sort((a, b) => a['id'].compareTo(b['id']));

      // Sort gameInfoData by 'sequence', handling null values by assigning them the lowest priority
      gameInfoData.sort((a, b) {
        final sequenceA = a['sequence'] ?? double.infinity; // Null goes to the end
        final sequenceB = b['sequence'] ?? double.infinity;
        return sequenceA.compareTo(sequenceB);
      });

      // Create a map of info_id -> short_game_name
      Map<int, String> gameInfoMap = {
        for (var info in gameInfoData) info['id']: info['short_game_name']
      };

      // Collect all info_ids to query games table
      List<int> infoIds = gameInfoMap.keys.toList();

      if (infoIds.isEmpty) {
        notifyListeners(); // No info_ids found
        return;
      }

      // Build an OR filter string for all the infoIds
      final orFilter = infoIds.map((id) => 'info_id.eq.$id').join(',');

      // Second query to fetch from 'games' table where info_id matches any of the fetched infoIds
      final gamesResponse = await supabase
          .from('games')
          .select('id, info_id, game_date, game_result, off_day')
          .or(orFilter)
          .gte('game_date', firstDayOfMonth.toIso8601String())
          .lte('game_date', lastDayOfMonth.toIso8601String());


      if (gamesResponse.isEmpty) {
        gameNames = [];
        gameResults = {};
        games = [];
        notifyListeners(); // No games found for the selected info_ids
        return;
      }

      List<dynamic> gamesData = gamesResponse as List<dynamic>;
      if (gamesData.isEmpty) {
        notifyListeners(); // Notify listeners when no data is found
        return;
      }

      // Sort the games data by 'game_date' before processing it
      gamesData.sort((a, b) {
        DateTime gameDateA = DateTime.parse(a['game_date']);
        DateTime gameDateB = DateTime.parse(b['game_date']);
        return gameDateA.compareTo(gameDateB); // Ascending order
      });

      Map<String, List<Map<String, dynamic>>> results = {};
      List<String> newGameNames = [];

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

      gameNames = newGameNames;
      gameResults = results;

      notifyListeners(); // Notify listeners after updating gameNames and gameResults
    } catch (error) {
      // Handle error
      if (kDebugMode) {
        print('Error fetching game names and results: $error');
      }
    }
  }

  Future<void> fetchGamesForCurrentDateOrTomorrow() async {
    try {
      if (!(isSuper || isPremium)) {
        return; // Exit early if neither is true
      }

      if (khaiwalId.isEmpty) return;

      final now = getLiveTime();
      final currentDate = DateTime.utc(now.year, now.month, now.day);
      final tomorrowDate = DateTime.utc(now.year, now.month, now.day + 1);
      final dayAfterTomorrowDate = DateTime.utc(now.year, now.month, now.day + 2); // Day after tomorrow

      // First query to fetch 'id' and 'short_game_name' from 'game_info'
      final gameInfoResponse = await supabase
          .from('game_info')
          .select('id, full_game_name, open_time, big_play_min, close_time_min, result_time_min, day_before, is_active')
          .not('is_active', 'is', 'false')
          .eq('khaiwal_id', khaiwalId);

      if (gameInfoResponse.isEmpty) {
        notifyListeners(); // No data found in 'game_info'
        return;
      }

      List<dynamic> gameInfoData = gameInfoResponse as List<dynamic>;

      // Create a map of info_id -> full_game_name (from game_info)
      Map<int, Map<String, dynamic>> gameInfoMap = {
        for (var info in gameInfoData)
          info['id']: {
            'full_game_name': info['full_game_name'],
            'open_time': info['open_time'],
            'big_play_min': info['big_play_min'],
            'close_time_min': info['close_time_min'],
            'result_time_min': info['result_time_min'],
            'day_before': info['day_before'],
            'is_active': info['is_active'],
          }
      };

      // Collect all info_ids to query games table
      List<int> infoIds = gameInfoMap.keys.toList();

      if (infoIds.isEmpty) {
        notifyListeners(); // No info_ids found
        return;
      }

      // Build an OR filter string for all the infoIds
      final orFilter = infoIds.map((id) => 'info_id.eq.$id').join(',');

      final response = await supabase
          .from('games')
          .select('id, info_id, game_date, game_result, pause, off_day')
          .or(orFilter)
          .gte('game_date', currentDate.toIso8601String())
          .lte('game_date', tomorrowDate.toIso8601String()); // Include games for today and tomorrow

      if (response.isEmpty) {
        games = [];
        return;
      }

      List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        notifyListeners(); // Notify listeners when no data is found
        return;
      }

      List<Map<String, dynamic>> gamesForCurrentDate = [];

      for (var game in data) {
        DateTime gameDate = DateTime.parse(game['game_date']);
        bool dayBefore = gameInfoMap[game['info_id']]?['day_before'] ?? false;

        DateTime targetDate = dayBefore ? tomorrowDate : currentDate;
        if (gameDate.year == targetDate.year &&
            gameDate.month == targetDate.month &&
            gameDate.day == targetDate.day) {
          // Merge game_info details with game data
          gamesForCurrentDate.add({
            'id': game['id'],
            'info_id': game['info_id'],
            'game_date': game['game_date'],
            'game_result': game['game_result'],
            'pause': game['pause'],
            'off_day': game['off_day'],
            'full_game_name': gameInfoMap[game['info_id']]?['full_game_name'],
            'open_time': gameInfoMap[game['info_id']]?['open_time'],
            'big_play_min': gameInfoMap[game['info_id']]?['big_play_min'],
            'close_time_min': gameInfoMap[game['info_id']]?['close_time_min'],
            'result_time_min': gameInfoMap[game['info_id']]?['result_time_min'],
            'day_before': gameInfoMap[game['info_id']]?['day_before'],
            'is_active': gameInfoMap[game['info_id']]?['is_active'],
          });
        }
      }
      // Check the refreshDifference != 0 condition
      if (refreshDifference != 0) {
        // Check games from tomorrow
        for (var game in data) {
          // Combine gameDate and open_time to create a full DateTime
          DateTime gameDate = DateTime.parse(game['game_date']);

          // Fetch the game info for this game using info_id
          var gameInfo = gameInfoMap[game['info_id']];
          if (gameInfo == null) continue; // Skip if no matching game_info found

          List<String> timeParts = (gameInfo['open_time'] as String).split(':');
          DateTime openTime = DateTime.utc(
            gameDate.year,
            gameDate.month,
            gameDate.day,
            int.parse(timeParts[0]), // hours
            int.parse(timeParts[1]), // minutes
            int.parse(timeParts[2]), // seconds
          );

          // If the gameDate is tomorrow and the open_time is between midnight and now
          if (gameDate.year == tomorrowDate.year &&
              gameDate.month == tomorrowDate.month &&
              gameDate.day == tomorrowDate.day) {

            // Check if the open time falls between midnight and now for today
            if (openTime.isAfter(DateTime.utc(currentDate.year, currentDate.month, currentDate.day, 0, 0, 0)) &&
                openTime.isBefore(currentTime)) {

              // If the game is not set to 'day_before'
              if (gameInfo['day_before'] != true) {
                // Remove existing games that match the full_game_name and game_date
                gamesForCurrentDate.removeWhere((existingGame) =>
                existingGame['full_game_name'] == gameInfo['full_game_name'] &&
                    DateTime.parse(existingGame['game_date']).year == currentDate.year &&
                    DateTime.parse(existingGame['game_date']).month == currentDate.month &&
                    DateTime.parse(existingGame['game_date']).day == currentDate.day
                );

                // Merge gameInfo data with the game and add to the list
                gamesForCurrentDate.add({
                  'id': game['id'],
                  'info_id': game['info_id'],
                  'game_date': game['game_date'],
                  'game_result': game['game_result'],
                  'pause': game['pause'],
                  'off_day': game['off_day'],
                  'full_game_name': gameInfo['full_game_name'],
                  'open_time': gameInfo['open_time'],
                  'big_play_min': gameInfo['big_play_min'],
                  'close_time_min': gameInfo['close_time_min'],
                  'result_time_min': gameInfo['result_time_min'],
                  'day_before': gameInfo['day_before'],
                  'is_active': gameInfo['is_active'],
                });
              } else {
                // If the game is set to 'day_before', fetch games for the day after tomorrow
                final responseDayAfterTomorrow = await supabase
                    .from('games')
                    .select('id, info_id, game_date, game_result, pause, off_day')
                    .eq('info_id', game['info_id'])
                    .eq('game_date', dayAfterTomorrowDate.toIso8601String());

                if (responseDayAfterTomorrow.isNotEmpty) {
                  var gameDayAfterTomorrow = responseDayAfterTomorrow[0];
                  // Remove existing games that match the full_game_name and game_date for tomorrow
                  gamesForCurrentDate.removeWhere((existingGame) =>
                  existingGame['full_game_name'] == gameInfo['full_game_name'] &&
                      DateTime.parse(existingGame['game_date']).year == tomorrowDate.year &&
                      DateTime.parse(existingGame['game_date']).month == tomorrowDate.month &&
                      DateTime.parse(existingGame['game_date']).day == tomorrowDate.day
                  );

                  // Merge gameInfo data with game from day after tomorrow and add it to the list
                  gamesForCurrentDate.add({
                    'id': gameDayAfterTomorrow['id'],
                    'info_id': gameDayAfterTomorrow['info_id'],
                    'game_date': gameDayAfterTomorrow['game_date'],
                    'game_result': gameDayAfterTomorrow['game_result'],
                    'pause': gameDayAfterTomorrow['pause'],
                    'off_day': gameDayAfterTomorrow['off_day'],
                    'full_game_name': gameInfo['full_game_name'],
                    'open_time': gameInfo['open_time'],
                    'big_play_min': gameInfo['big_play_min'],
                    'close_time_min': gameInfo['close_time_min'],
                    'result_time_min': gameInfo['result_time_min'],
                    'day_before': gameInfo['day_before'],
                    'is_active': gameInfo['is_active'],
                  });
                }
              }
            }
          }
        }
      }

      // Sort games by 'game_date' and 'close_time_min'
      gamesForCurrentDate.sort((a, b) {
        DateTime gameDateA = DateTime.parse(a['game_date']);
        DateTime gameDateB = DateTime.parse(b['game_date']);

        // Compare 'game_date' first
        int dateComparison = gameDateA.compareTo(gameDateB);
        if (dateComparison != 0) {
          return dateComparison;
        }

        // If 'game_date' is the same, compare 'close_time_min'
        int closeTimeMinA = a['close_time_min'];
        int closeTimeMinB = b['close_time_min'];
        return closeTimeMinA.compareTo(closeTimeMinB);
      });

      games = gamesForCurrentDate;

      notifyListeners(); // Notify listeners after updating games
    } catch (error) {
      // Handle error
    }
  }



  Future<void> fetchGameResultsForCurrentDayAndYesterday() async {
    try {
      if (!(isSuper || isPremium)) {
        return; // Exit early if neither is true
      }

      if (khaiwalId.isEmpty) return;

      final now = getLiveTime();
      final currentDate = DateTime.utc(now.year, now.month, now.day);

      // Calculate yesterday's date
      DateTime yesterday = currentDate.subtract(const Duration(days: 1));

      // First query to fetch 'id' and 'short_game_name' from 'game_info'
      final gameInfoResponse = await supabase
          .from('game_info')
          .select('id, short_game_name, full_game_name, open_time, big_play_min, close_time_min, result_time_min, day_before, is_active')
          .not('is_active', 'is', 'false')
          .eq('khaiwal_id', khaiwalId);

      if (gameInfoResponse.isEmpty) {
        notifyListeners(); // No data found in 'game_info'
        return;
      }

      List<dynamic> gameInfoData = gameInfoResponse as List<dynamic>;

      // Create a map of info_id -> full_game_name (from game_info)
      Map<int, Map<String, dynamic>> gameInfoMap = {
        for (var info in gameInfoData)
          info['id']: {
            'short_game_name': info['short_game_name'],
            'full_game_name': info['full_game_name'],
            'open_time': info['open_time'],
            'big_play_min': info['big_play_min'],
            'close_time_min': info['close_time_min'],
            'result_time_min': info['result_time_min'],
            'day_before': info['day_before'],
            'is_active': info['is_active'],
          }
      };

      // Collect all info_ids to query games table
      List<int> infoIds = gameInfoMap.keys.toList();
      // Build an OR filter string for all the infoIds
      final orFilter = infoIds.map((id) => 'info_id.eq.$id').join(',');

      // Fetch fresh game_results for the current day
      final responseToday = await supabase
          .from('games')
          .select('id, info_id, game_date, game_result, pause, off_day')
          .or(orFilter)
          .eq('game_date', currentDate.toIso8601String());

      // Check if all responseToday['id'] exist in gameResults (for the current date)
      bool allIdsExistInGameResults = true;
      for (var game in responseToday) {
        String gameId = game['id'].toString();
        bool gameExists = gameResults.values.any((gameList) =>
            gameList.any((existingGame) => existingGame['id'].toString() == gameId));
        if (!gameExists) {
          allIdsExistInGameResults = false;
          break;
        }
      }

      // Check if all gameResults['id'] (for the current date only) exist in responseToday['id']
      bool allIdsExistInResponseToday = true;
      for (var gameList in gameResults.values) {
        for (var game in gameList) {
          DateTime gameDate = DateTime.parse(game['game_date']);
          if (gameDate.year == currentDate.year &&
              gameDate.month == currentDate.month &&
              gameDate.day == currentDate.day) {
            String gameId = game['id'].toString();
            bool gameExistsInResponseToday = responseToday.any(
                    (todayGame) => todayGame['id'].toString() == gameId);
            if (!gameExistsInResponseToday) {
              allIdsExistInResponseToday = false;
              break;
            }
          }
        }
        if (!allIdsExistInResponseToday) break;
      }

      // If any ID does not exist in either direction, fetch data for the entire month and return
      if (!allIdsExistInGameResults || !allIdsExistInResponseToday) {
        if (kDebugMode) {
          print('returned with main methods');
        }
        // await fetchDataForCurrentMonth();
        await fetchGameNamesAndResults();
        await fetchGamesForCurrentDateOrTomorrow();

        return;
      }

      // Fetch game_results for yesterday if it's not the first day of the month
      List<dynamic> responseYesterday = [];
      if (currentDate.day != 1) {
        responseYesterday = await supabase
            .from('games')
            .select('id, info_id, game_date, game_result, off_day')
            .or(orFilter)
            .eq('game_date', yesterday.toIso8601String());
      }

      // If both responses are empty, return
      if (responseToday.isEmpty && responseYesterday.isEmpty) return;

      // Process today's data
      List<dynamic> freshDataToday = responseToday as List<dynamic>;
      Map<String, List<Map<String, dynamic>>> freshResultsForToday = {};
      for (var game in freshDataToday) {
        String shortGameName = gameInfoMap[game['info_id']]?['short_game_name'];
        if (!freshResultsForToday.containsKey(shortGameName)) {
          freshResultsForToday[shortGameName] = [];
        }
        freshResultsForToday[shortGameName]?.add({
          'id': game['id'],
          'game_date': game['game_date'],
          'game_result': game['game_result'],
          'short_game_name': gameInfoMap[game['info_id']]?['short_game_name'],
          'off_day': game['off_day'],
        });
      }

      // Process yesterday's data if available
      Map<String, List<Map<String, dynamic>>> freshResultsForYesterday = {};
      if (responseYesterday.isNotEmpty) {
        List<dynamic> freshDataYesterday = responseYesterday;
        for (var game in freshDataYesterday) {
          String shortGameName = gameInfoMap[game['info_id']]?['short_game_name'];
          if (!freshResultsForYesterday.containsKey(shortGameName)) {
            freshResultsForYesterday[shortGameName] = [];
          }
          freshResultsForYesterday[shortGameName]?.add({
            'id': game['id'],
            'game_date': game['game_date'],
            'game_result': game['game_result'],
            'pause': game['pause'],
            'off_day': game['off_day'],
            'short_game_name': gameInfoMap[game['info_id']]?['short_game_name'],
            'full_game_name': gameInfoMap[game['info_id']]?['full_game_name'],
            'open_time': gameInfoMap[game['info_id']]?['open_time'],
            'big_play_min': gameInfoMap[game['info_id']]?['big_play_min'],
            'close_time_min': gameInfoMap[game['info_id']]?['close_time_min'],
            'result_time_min': gameInfoMap[game['info_id']]?['result_time_min'],
            'day_before': gameInfoMap[game['info_id']]?['day_before'],
            'is_active': gameInfoMap[game['info_id']]?['is_active'],
          });
        }
      }

      // Update the current day and yesterday's game results in gameResults
      for (var gameName in freshResultsForToday.keys) {
        if (gameResults.containsKey(gameName)) {
          List<Map<String, dynamic>> updatedResults = gameResults[gameName]!
              .where((result) {
            final gameDate = DateTime.parse(result['game_date']);
            return !(gameDate.year == currentDate.year &&
                gameDate.month == currentDate.month &&
                gameDate.day == currentDate.day);
          }).toList(); // Keep previous days' data except current day

          updatedResults.addAll(freshResultsForToday[gameName]!); // Add fresh current day results

          // Sort by 'game_date'
          updatedResults.sort((a, b) {
            DateTime gameDateA = DateTime.parse(a['game_date']);
            DateTime gameDateB = DateTime.parse(b['game_date']);
            return gameDateA.compareTo(gameDateB);
          });

          gameResults[gameName] = updatedResults;
        } else {
          gameResults[gameName] = freshResultsForToday[gameName]!;
        }
      }

      // Similarly update yesterday's game results
      for (var gameName in freshResultsForYesterday.keys) {
        if (gameResults.containsKey(gameName)) {
          List<Map<String, dynamic>> updatedResults = gameResults[gameName]!
              .where((result) {
            final gameDate = DateTime.parse(result['game_date']);
            return !(gameDate.year == yesterday.year &&
                gameDate.month == yesterday.month &&
                gameDate.day == yesterday.day);
          }).toList(); // Keep previous days' data except yesterday

          updatedResults.addAll(freshResultsForYesterday[gameName]!); // Add fresh yesterday results

          // Sort by 'game_date'
          updatedResults.sort((a, b) {
            DateTime gameDateA = DateTime.parse(a['game_date']);
            DateTime gameDateB = DateTime.parse(b['game_date']);
            return gameDateA.compareTo(gameDateB);
          });

          gameResults[gameName] = updatedResults;
        } else {
          gameResults[gameName] = freshResultsForYesterday[gameName]!;
        }
      }

      List<Map<String, dynamic>> todayData = [];

      for (var game in responseToday) {
        var info = gameInfoMap[game['info_id']];
        if (info != null) {
          todayData.add({
            'id': game['id'],
            'info_id': game['info_id'],
            'game_date': game['game_date'],
            'game_result': game['game_result'],
            'pause': game['pause'],
            'off_day': game['off_day'],
            'full_game_name': info['full_game_name'],
            'open_time': info['open_time'],
            'big_play_min': info['big_play_min'],
            'close_time_min': info['close_time_min'],
            'result_time_min': info['result_time_min'],
            'day_before': info['day_before'],
            'is_active': info['is_active'],
          });
        }
      }


      await mergeCurrentTomorrowData(todayData);

      // notifyListeners(); // Notify listeners after updating the results
    } catch (error) {
      // Handle error, e.g., show a snackbar with the error message
    }
  }

  // Helper method to calculate live time
  DateTime getLiveTime() {
    return refreshDifference != 0
        ? currentTime.add(Duration(minutes: refreshDifference))
        : currentTime;
  }

  Future<void> mergeCurrentTomorrowData(List<dynamic> responseToday) async {
    if (kDebugMode) {
      print('In the merge');
    }
    try {
      if (khaiwalId.isEmpty) return;

      final now = getLiveTime();
      final currentDate = DateTime.utc(now.year, now.month, now.day);
      final tomorrowDate = DateTime.utc(now.year, now.month, now.day + 1);
      final dayAfterTomorrowDate = DateTime.utc(now.year, now.month, now.day + 2); // Day after tomorrow

      // First query to fetch 'id' and 'short_game_name' from 'game_info'
      final gameInfoResponse = await supabase
          .from('game_info')
          .select('id, full_game_name, open_time, big_play_min, close_time_min, result_time_min, day_before, is_active')
      // .not('is_active', 'is', 'false')
          .eq('khaiwal_id', khaiwalId);

      if (gameInfoResponse.isEmpty) {
        notifyListeners(); // No data found in 'game_info'
        return;
      }

      List<dynamic> gameInfoData = gameInfoResponse as List<dynamic>;

      // Create a map of info_id -> full_game_name (from game_info)
      Map<int, Map<String, dynamic>> gameInfoMap = {
        for (var info in gameInfoData)
          info['id']: {
            'full_game_name': info['full_game_name'],
            'open_time': info['open_time'],
            'big_play_min': info['big_play_min'],
            'close_time_min': info['close_time_min'],
            'result_time_min': info['result_time_min'],
            'day_before': info['day_before'],
            'is_active': info['is_active'],
          }
      };

      // Collect all info_ids to query games table
      List<int> infoIds = gameInfoMap.keys.toList();
      // Build an OR filter string for all the infoIds
      final orFilter = infoIds.map((id) => 'info_id.eq.$id').join(',');


      // Fetch games for tomorrow only
      final responseTomorrow = await supabase
          .from('games')
          .select('id, info_id, game_date, game_result, pause, off_day')
          .or(orFilter)
          .eq('game_date', tomorrowDate.toIso8601String());

      // If no data is found, return
      if (responseToday.isEmpty && responseTomorrow.isEmpty) {
        games = [];
        notifyListeners();
        return;
      }
      List<Map<String, dynamic>> tomorrowData = [];

      for (var game in responseTomorrow) {
        var info = gameInfoMap[game['info_id']];
        if (info != null) {
          tomorrowData.add({
            'id': game['id'],
            'info_id': game['info_id'],
            'game_date': game['game_date'],
            'game_result': game['game_result'],
            'pause': game['pause'],
            'off_day': game['off_day'],
            'full_game_name': info['full_game_name'],
            'open_time': info['open_time'],
            'big_play_min': info['big_play_min'],
            'close_time_min': info['close_time_min'],
            'result_time_min': info['result_time_min'],
            'day_before': info['day_before'],
            'is_active': info['is_active'],
          });
        }
      }

      // Merge responseToday and responseTomorrow
      List<dynamic> mergedData = responseToday + tomorrowData;

      // Process and sort the merged data
      List<Map<String, dynamic>> gamesForCurrentAndTomorrow = [];

      for (var game in mergedData) {
        DateTime gameDate = DateTime.parse(game['game_date']);
        bool dayBefore = game['day_before'] ?? false;

        DateTime targetDate = dayBefore ? tomorrowDate : currentDate;
        if (gameDate.year == targetDate.year &&
            gameDate.month == targetDate.month &&
            gameDate.day == targetDate.day) {
          gamesForCurrentAndTomorrow.add(game as Map<String, dynamic>);
        }
        // optionally added below code in this loop to avoid the loop the again
        if (refreshDifference != 0 && gameDate.year == tomorrowDate.year &&
            gameDate.month == tomorrowDate.month &&
            gameDate.day == tomorrowDate.day){

          List<String> timeParts = game['open_time'].split(':');
          DateTime openTime = DateTime.utc(
            gameDate.year,
            gameDate.month,
            gameDate.day,
            int.parse(timeParts[0]), // hours
            int.parse(timeParts[1]), // minutes
            int.parse(timeParts[2]), // seconds
          );

          // If the open_time of the game falls between midnight and now for today, add it
          if (openTime.isAfter(DateTime.utc(currentDate.year, currentDate.month, currentDate.day, 0, 0, 0)) &&
              openTime.isBefore(currentTime)) {

            if (game['day_before'] != true) {
              // Check if the game already exists by comparing full_game_name and game_date
              gamesForCurrentAndTomorrow.removeWhere((existingGame) =>
              existingGame['info_id'] == game['info_id'] &&
                  DateTime.parse(existingGame['game_date']).year == currentDate.year &&
                  DateTime.parse(existingGame['game_date']).month == currentDate.month &&
                  DateTime.parse(existingGame['game_date']).day == currentDate.day);

              gamesForCurrentAndTomorrow.add(game as Map<String, dynamic>);
            } else {
              // Fetch games for tomorrow only
              final responseDayAfterTomorrow = await supabase
                  .from('games')
                  .select('id, info_id, game_date, game_result, pause, off_day')
                  .eq('info_id', game['info_id'])
                  .eq('game_date', dayAfterTomorrowDate.toIso8601String());

              // Check if the game already exists by comparing full_game_name and game_date
              gamesForCurrentAndTomorrow.removeWhere((existingGame) =>
              existingGame['info_id'] == game['info_id'] &&
                  DateTime.parse(existingGame['game_date']).year == tomorrowDate.year &&
                  DateTime.parse(existingGame['game_date']).month == tomorrowDate.month &&
                  DateTime.parse(existingGame['game_date']).day == tomorrowDate.day);

              // If a game is found, add it to gamesForCurrentAndTomorrow
              if (responseDayAfterTomorrow.isNotEmpty) {
                for (var game in responseDayAfterTomorrow) {
                  var info = gameInfoMap[game['info_id']];
                  if (info != null) {
                    gamesForCurrentAndTomorrow.add({
                      'id': game['id'],
                      'info_id': game['info_id'],
                      'game_date': game['game_date'],
                      'game_result': game['game_result'],
                      'pause': game['pause'],
                      'off_day': game['off_day'],
                      'full_game_name': info['full_game_name'],
                      'open_time': info['open_time'],
                      'big_play_min': info['big_play_min'],
                      'close_time_min': info['close_time_min'],
                      'result_time_min': info['result_time_min'],
                      'day_before': info['day_before'],
                      'is_active': info['is_active'],
                    });
                  }
                }
              }
            }
          }
        }
      }

      // Check the refreshDifference != 0 condition
      // if (refreshDifference != 0) {
      //   // Check games from tomorrow
      //   for (var game in responseTomorrow) {
      //
      //     // Combine gameDate and open_time to create a full DateTime
      //     DateTime gameDate = DateTime.parse(game['game_date']);
      //     List<String> timeParts = game['open_time'].split(':');
      //     DateTime openTime = DateTime.utc(
      //       gameDate.year,
      //       gameDate.month,
      //       gameDate.day,
      //       int.parse(timeParts[0]), // hours
      //       int.parse(timeParts[1]), // minutes
      //       int.parse(timeParts[2]), // seconds
      //     );
      //
      //     // If the open_time of the game falls between midnight and now for today, add it
      //     if (openTime.isAfter(DateTime.utc(currentDate.year, currentDate.month, currentDate.day, 0, 0, 0)) &&
      //         openTime.isBefore(currentTime)) {
      //
      //       if (game['day_before'] != true) {
      //         // Check if the game already exists by comparing full_game_name and game_date
      //         gamesForCurrentAndTomorrow.removeWhere((existingGame) =>
      //         existingGame['full_game_name'] == game['full_game_name'] &&
      //             DateTime.parse(existingGame['game_date']).year == currentDate.year &&
      //             DateTime.parse(existingGame['game_date']).month == currentDate.month &&
      //             DateTime.parse(existingGame['game_date']).day == currentDate.day);
      //
      //         gamesForCurrentAndTomorrow.add(game as Map<String, dynamic>);
      //       } else {
      //         final responseDayAfterTomorrow = await supabase
      //             .from('games')
      //             .select('id, game_date, full_game_name, game_result, open_time, close_time_min, last_big_play_min, result_time_min, off_day, day_before')
      //             .eq('full_game_name', game['full_game_name'])
      //             .eq('khaiwal_id', khaiwalId)
      //             .not('active', 'is', 'false')
      //             .eq('game_date', dayAfterTomorrowDate.toIso8601String());
      //
      //         // Check if the game already exists by comparing full_game_name and game_date
      //         gamesForCurrentAndTomorrow.removeWhere((existingGame) =>
      //         existingGame['full_game_name'] == game['full_game_name'] &&
      //             DateTime.parse(existingGame['game_date']).year == tomorrowDate.year &&
      //             DateTime.parse(existingGame['game_date']).month == tomorrowDate.month &&
      //             DateTime.parse(existingGame['game_date']).day == tomorrowDate.day);
      //
      //         // If a game is found, add it to gamesForCurrentAndTomorrow
      //         if (responseDayAfterTomorrow.isNotEmpty) {
      //           gamesForCurrentAndTomorrow.add(responseDayAfterTomorrow[0] as Map<String, dynamic>);
      //         }
      //       }
      //
      //     }
      //   }
      // }


      // Sort games by 'game_date' and 'close_time_min'
      gamesForCurrentAndTomorrow.sort((a, b) {
        DateTime gameDateA = DateTime.parse(a['game_date']);
        DateTime gameDateB = DateTime.parse(b['game_date']);

        // Compare 'game_date' first
        int dateComparison = gameDateA.compareTo(gameDateB);
        if (dateComparison != 0) {
          return dateComparison;
        }

        // If 'game_date' is the same, compare 'close_time_min'
        int closeTimeMinA = a['close_time_min'];
        int closeTimeMinB = b['close_time_min'];
        return closeTimeMinA.compareTo(closeTimeMinB);
      });


      games = gamesForCurrentAndTomorrow;

      notifyListeners(); // Notify listeners after updating games
    } catch (error) {
      if (kDebugMode) {
        print('in the catch $error');
      }
      // Handle error
    }
  }

  String formatGameDate(String gameDate) {
    DateTime parsedDate = DateTime.parse(gameDate);
    return DateFormat('dd-MM-yyyy').format(parsedDate);
  }

  String formatTimestamp(String timestamp) {
    // Parse the timestamp string to DateTime object
    DateTime parsedTimestamp = DateTime.parse(timestamp);
    // Format the DateTime to the desired format
    return DateFormat('d MMMM, yyyy \'at\' hh:mm a').format(parsedTimestamp);
  }

  Future<void> fetchUserSettings() async {
    final khaiwalPlayerResponse = await supabase
        .from('khaiwals_players')
        .select('rate, commission, debt_limit, big_play_limit, edit_minutes, allowed')
        .eq('id', kpId)
        .maybeSingle();

    if (khaiwalPlayerResponse != null) {
      kpRate =  khaiwalPlayerResponse['rate'] ?? 0;
      kpCommission = khaiwalPlayerResponse['commission'] ?? 0;
      debtLimit = khaiwalPlayerResponse['debt_limit'] ?? 0;
      bigPlayLimit = khaiwalPlayerResponse['big_play_limit'] ?? 0;
      editMinutes = khaiwalPlayerResponse['edit_minutes'] ?? -1;
      allowed = khaiwalPlayerResponse['allowed'];

      notifyListeners();
    }
  }


  Future<bool> checkDeviceMismatch(BuildContext context) async {
    try {
      // Fetch the device ID from the 'khaiwals' table
      final response = await supabase
          .from('profiles')
          .select('device_id')
          .eq('id', currentUserProfileId)
          .maybeSingle();

      print('printing deviceId: $deviceId');
      print('printing response: $response');
      print('printing online device_id: ${response?['device_id']}');

      if (response == null || response['device_id'] != deviceId) {
        // Close any progress indicator if open
        Navigator.of(context).popUntil((route) => route.isFirst);

        // Show mismatch dialog
        await showDialog<bool>(
          context: context,
          // barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Device Mismatch'),
              content: const Text(
                  'This is not your default device. Would you like to make this device default for MasterPlay?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // User declined
                  },
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await updateDeviceId(); // Update the device ID
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Device updated successfully.')),
                      );
                    } catch (error) {
                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to update device')),
                      );
                    }
                    Navigator.of(context).pop(true); // User accepted
                  },
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );

        // Regardless of Yes or No, stop further execution
        return true; // Indicate that a mismatch was handled
      }

      return false; // No mismatch
    } catch (error) {
      // Close any progress indicator if open
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error checking device mismatch')),
      );
      return true; // Indicate mismatch to halt operations
    }
  }

  // Update the device ID in the 'khaiwals' table
  Future<void> updateDeviceId() async {
    try {
      // Update the device_id column in the 'khaiwals' table
      final response = await supabase.from('profiles').update({
        'device_id': deviceId, // Set the current device ID
      }).eq('id', currentUserProfileId);

      if (response != null) {
        throw Exception('Failed to update device ID: $response');
      }

      notifyListeners(); // Notify listeners about the change
    } catch (error) {
      throw Exception('Error updating device ID');
    }
  }



  Future<void> resetState() async {
    // Update the `kp_id` in the `players` table to null
    if (currentUserProfileId.isNotEmpty) {
      await supabase
          .from('profiles')
          .update({'kp_id': null})
          .eq('id', currentUserProfileId);
    }

    // Reset local variables
    khaiwalId = '';
    khaiwalName = '';
    khaiwalUserName = '';
    khaiwalEmail = '';
    khaiwalTimezone = '';
    refreshDifference = -360;
    isSuper = false;
    isPremium = false;


    kpId = 0;
    kpRate = 0;
    kpCommission = 0;
    kpPatti = 0;
    balance = 0;
    debtLimit = 0;
    bigPlayLimit = -1;
    editMinutes = -1;
    allowed = null;
    nullActionCount = 0;


    gameNames.clear();
    gameResults.clear();
    games.clear();
    gamePlayExists.clear();

    _timer.cancel();

    notifyListeners();
  }


  @override
  void dispose() {
    _timer.cancel();  // Cancel the timer when the object is disposed
    super.dispose();
  }


}

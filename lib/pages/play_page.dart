import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masterplay/models/app_state.dart';
import 'package:provider/provider.dart';

import '../main.dart';


class PlayPage extends StatefulWidget {
  final int gameId;
  final int infoId;
  final String fullGameName;
  final String gameDate;
  final DateTime openTime;
  final String onlyOpenTime;
  final DateTime closeTime;
  final int closeTimeMin;
  final DateTime lastBigPlayTime;
  final int lastBigPlayMinute;
  final bool isEditGame;
  final bool isDayBefore;

  const PlayPage({
    super.key,
    required this.gameId,
    required this.infoId,
    required this.fullGameName,
    required this.gameDate,
    required this.openTime,
    required this.onlyOpenTime,
    required this.closeTime,
    required this.closeTimeMin,
    required this.lastBigPlayTime,
    required this.lastBigPlayMinute,
    required this.isEditGame,
    required this.isDayBefore
  });


  @override
  _PlayPageState createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {

  final TextEditingController _numberInputController = TextEditingController();
  final TextEditingController _crossingInputController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _inputAController = TextEditingController();
  final TextEditingController _inputBController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _multiCodeController = TextEditingController();
  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();
  final FocusNode _amountFocusNode = FocusNode();

  Map<int, TextEditingController> editTextControllers = {};

  final ValueNotifier<int> _totalAmount = ValueNotifier<int>(0);

  bool isReverseChecked = false;
  bool isWithoutPairChecked  = false;
  bool exceededBigPlayLimit = false;

  late int existingId;
  late int playTxnId;
  late String existingSlotAmount;

  Timer? _closeTimeChecker;
  Timer? _lastBigPlayTimeChecker;
  Timer? _lastEditTimeChecker;

  late DateTime gameCloseTime;
  late DateTime lastBigPlayTime;
  late DateTime lastEditTime;
  // late DateTime lastBigPlayMinute;

  final ValueNotifier<Duration> remainingCloseTime = ValueNotifier<Duration>(const Duration());
  // Duration remainingCloseTime = const Duration();

  final ValueNotifier<Duration> remainingLastBigPlayTime = ValueNotifier<Duration>(const Duration());
  // Duration remainingLastBigPlayTime = const Duration();


  final ValueNotifier<String> countdownCloseTimeText = ValueNotifier<String>("");
  // String countdownCloseTimeText = "";

  final ValueNotifier<String> countdownLastBigPlayTimeText = ValueNotifier<String>("");
  // String countdownLastBigPlayTimeText = "";

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _setStatusBarColor(Colors.purple); // Set your desired status bar color
    _initializeTextControllers(); // Initialize the controllers
    setupNumberInputListener();
    setupFocusSwitching();
    _refresh();
    // Parse the closeTime and lastBigPlayTime passed from the widget
    _parseCloseTime();
    _parseLastBigPlayTime();

    // Start real-time checks for both countdowns
    _startCloseTimeCheck();
    _startLastBigPlayTimeCheck();
    if (widget.isEditGame){
      _loadExistingGamePlay();
      if (AppState().editMinutes != -1) {
        _parseLastEditTime();
        _startLastEditTimeCheck();
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      loading = true;
    });
    await _refreshTime();
    setState(() {
      loading = false;
    });
  }

  Future<void> _refreshTime() async {
    await AppState().refreshTime();
  }

  void _parseCloseTime() {
    // print('printing opneTime: ${widget.openTime}');
    // print('printing closeTime: ${widget.closeTime}');
    // print('printing lastBigPlayTime: ${widget.lastBigPlayTime}');
    // print('printing lastBigPlayMin: ${widget.lastBigPlayMinute}');
    // Assuming the closeTime is in "HH:mm:ss" format
    try {
      // final closeTimeParts = widget.closeTime.split(':');
      // final now = AppState().currentTime;
      // closeTime = DateTime.utc(
      //   now.year,
      //   now.month,
      //   now.day,
      //   int.parse(closeTimeParts[0]),
      //   int.parse(closeTimeParts[1]),
      //   int.parse(closeTimeParts[2]),
      // );
      // Subtract 5 seconds
      gameCloseTime = widget.closeTime;
      gameCloseTime = gameCloseTime.subtract(const Duration(seconds: 10));
      if (widget.isDayBefore) {
        gameCloseTime = gameCloseTime.subtract(const Duration(minutes: 1440));
      }

      // print('Parsed close time: $gameCloseTime');
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing close time: $e');
      }
    }
  }
  // Parse last big play time
  void _parseLastBigPlayTime() {
    try {
      // final lastBigPlayTimeParts = widget.closeTime.split(':');
      // final now = AppState().currentTime;
      // lastBigPlayTime = DateTime.utc(
      //   now.year,
      //   now.month,
      //   now.day,
      //   int.parse(lastBigPlayTimeParts[0]),
      //   int.parse(lastBigPlayTimeParts[1]),
      //   int.parse(lastBigPlayTimeParts[2]),
      // );
      // Check widget.lastBigPlayTime and subtract accordingly
      if (widget.lastBigPlayMinute != -1 && widget.lastBigPlayMinute != 0 && !widget.lastBigPlayTime.isAfter(widget.closeTime)) {
        lastBigPlayTime = widget.lastBigPlayTime;
        // Subtract the editMinutes from lastEditTime
        lastBigPlayTime = lastBigPlayTime.subtract(const Duration(seconds: 10));
      } else {
        lastBigPlayTime = widget.closeTime;
        // If editMinutes is -1 or 0, subtract 5 seconds
        lastBigPlayTime = lastBigPlayTime.subtract(const Duration(seconds: 10));
      }
      if (widget.isDayBefore){
        lastBigPlayTime = lastBigPlayTime.subtract(const Duration(minutes: 1440));
      }
      // print('Parsed last big play time: $lastBigPlayTime');
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing last big play time: $e');
      }
    }
  }

  void _parseLastEditTime() {
    try {
      // final lastEditTimeParts = widget.closeTime.split(':');
      // final now = AppState().currentTime;
      // lastEditTime = DateTime.utc(
      //   now.year,
      //   now.month,
      //   now.day,
      //   int.parse(lastEditTimeParts[0]),
      //   int.parse(lastEditTimeParts[1]),
      //   int.parse(lastEditTimeParts[2]),
      // );
      lastEditTime = widget.closeTime;
      // Check AppState().editMinutes and subtract accordingly
      if (AppState().editMinutes != -1 && AppState().editMinutes != 0) {
        // Subtract the editMinutes from lastEditTime
        lastEditTime = lastEditTime.subtract(Duration(minutes: AppState().editMinutes, seconds: 5));
      } else {
        // If editMinutes is -1 or 0, subtract 5 seconds
        lastEditTime = lastEditTime.subtract(const Duration(seconds: 5));
      }
      if (widget.isDayBefore){
        lastEditTime = lastEditTime.subtract(const Duration(minutes: 1440));
      }

      // print('Parsed last edit time: $lastEditTime');
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing last edit time: $e');
      }
    }

  }

  // Countdown for close time
  void _startCloseTimeCheck() {
    _closeTimeChecker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = AppState().currentTime; // Use the current time from AppState
      if (now.isAfter(gameCloseTime)) {
        timer.cancel(); // Stop the timer when the close time is over
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Game Time is over")));
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Duration timeRemaining = gameCloseTime.difference(now);
        remainingCloseTime.value = timeRemaining;
        countdownCloseTimeText.value = _formatDuration(timeRemaining);
        // setState(() {
        //   remainingCloseTime = gameCloseTime.difference(now);
        //   countdownCloseTimeText = _formatDuration(remainingCloseTime);
        // });
      }
    });
  }

  // Countdown for last big play time
  void _startLastBigPlayTimeCheck() {
    if (widget.lastBigPlayMinute == -1){
      return;
    }
    _lastBigPlayTimeChecker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = AppState().currentTime; // Use the current time from AppState
      if (now.isAfter(lastBigPlayTime)) {
        timer.cancel(); // Stop the timer when the last big play time is over
        exceededBigPlayLimit = true;
        setState(() {
          countdownLastBigPlayTimeText.value = 'Time Over';
        });
      } else {
        Duration timeRemaining = lastBigPlayTime.difference(now);
        remainingLastBigPlayTime.value = timeRemaining;
        countdownLastBigPlayTimeText.value = _formatDuration(timeRemaining);

        // setState(() {
        //   remainingLastBigPlayTime = lastBigPlayTime.difference(now);
        //   countdownLastBigPlayTimeText = _formatDuration(remainingLastBigPlayTime);
        // });
      }
    });
  }

  // Countdown for last edit time
  void _startLastEditTimeCheck() {
    _lastEditTimeChecker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = AppState().currentTime; // Use the current time from AppState
      if (now.isAfter(lastEditTime)) {
        timer.cancel(); // Stop the timer when the close time is over
        // _showPopDialog('Edit Time Over', 'The game edit time has ended.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("The game edit time has ended.")));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }


  // Format duration to HH:mm:ss
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _showPopDialog(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog by clicking outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst); // Close all dialogs and go back to the first page
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    AppState().fetchGameResultsForCurrentDayAndYesterday();
  }

  void _popDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // void _showTimeOverDialog() {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false, // Prevent closing the dialog by clicking outside
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Time Over'),
  //         content: const Text('The game time has ended.'),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).popUntil((route) => route.isFirst); // Close all dialogs and go back to the first page
  //             },
  //             child: const Text('OK'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  // void _showEditTimeOverDialog() {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false, // Prevent closing the dialog by clicking outside
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Edit Time Over'),
  //         content: const Text('The game edit time has ended.'),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).popUntil((route) => route.isFirst); // Close all dialogs and go back to the first page
  //             },
  //             child: const Text('OK'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  void _setStatusBarColor(Color color) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: color, // Set the status bar color
    ));
  }

  void _initializeTextControllers() {
    for (int i = 0; i <= 99; i++) {
      editTextControllers[i] = TextEditingController();
      // 2. Add listener to each controller to update total when text changes
      editTextControllers[i]!.addListener(_calculateTotalAmount);
    }
  }

  void setupNumberInputListener() {
    _numberInputController.addListener(() {
      String text = _numberInputController.text.replaceAll(' ', '');

      String formattedText = '';
      for (int i = 0; i < text.length; i++) {
        if (i % 2 == 0 && i != 0) {
          formattedText += ' ';
        }
        formattedText += text[i];
      }

      // Prevents an infinite loop of listener triggering itself
      if (_numberInputController.text != formattedText) {
        _numberInputController.value = _numberInputController.value.copyWith(
          text: formattedText,
          selection: TextSelection.collapsed(offset: formattedText.length),
        );
      }
    });
  }

  void setupFocusSwitching() {
    _fromController.addListener(() {
      if (_fromController.text.length == 2 && _toController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_toFocusNode);
      } else if (_fromController.text.length == 2 && _toController.text.isNotEmpty) {
        FocusScope.of(context).requestFocus(_amountFocusNode);
      }
    });

    _toController.addListener(() {
      if (_toController.text.length == 2 && _fromController.text.isEmpty) {
        FocusScope.of(context).requestFocus(_fromFocusNode);
      } else if (_toController.text.length == 2 && _fromController.text.isNotEmpty) {
        FocusScope.of(context).requestFocus(_amountFocusNode);
      }
    });
  }



  void _calculateTotalAmount() {
    int total = 0;
    for (int i = 0; i <= 99; i++) {
      final text = editTextControllers[i]?.text ?? '';
      if (text.isNotEmpty) {
        total += int.tryParse(text) ?? 0;
      }
    }
    // 3. Update the total amount
    _totalAmount.value = total;
  }

  void _loadExistingGamePlay() async {
    int kpId = AppState().kpId;
    int gameId = widget.gameId;

    // Fetch the existing slot_amount from the game_play table
    final existingEntryResponse = await supabase
        .from('game_play')
        .select('id, play_txn_id, slot_amount')
        .eq('kp_id', kpId)
        .eq('game_id', gameId)
        .single();  // Assuming there is only one record

    if (existingEntryResponse.isNotEmpty) {
      existingId = existingEntryResponse['id'];
      playTxnId = existingEntryResponse['play_txn_id'];
      existingSlotAmount = existingEntryResponse['slot_amount'];
      _parseAndSetSlotAmount(existingSlotAmount);
    }
  }

  void _parseAndSetSlotAmount(String slotAmountStr) {
    List<String> pairs = slotAmountStr.split(' / ');
    for (String pair in pairs) {
      List<String> parts = pair.split('=');
      if (parts.length == 2) {
        String slot = parts[0]; // Slot number
        int amount = int.parse(parts[1]); // Slot amount

        // Set the corresponding TextEditingController for the slot
        int slotNumber = int.parse(slot);
        editTextControllers[slotNumber]?.text = amount.toString();
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Detect taps outside of focused widgets
      onTap: () {
        FocusScope.of(context).unfocus(); // Remove focus from any text field
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.teal.shade100,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Aligns text to the start
              children: [
                Text(
                  widget.fullGameName,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  AppState().formatGameDate(widget.gameDate),
                  style: const TextStyle(fontSize: 14, color: Colors.blueGrey), // Subtitle style
                ),
              ],
            ),
          actions: [
            // Display the countdown timers
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Center the text vertically
                  children: [
                    // Use ValueListenableBuilder to listen to countdownCloseTimeText changes
                    ValueListenableBuilder<String>(
                      valueListenable: countdownCloseTimeText,
                      builder: (context, text, child) {
                        return Text(
                          text.isNotEmpty ? "Close: $text" : "Time Over",
                          style: const TextStyle(fontSize: 13),
                        );
                      },
                    ),
                    // Conditionally show the Last Big Play timer if lastBigPlayMinute != -1
                    if (widget.lastBigPlayMinute != -1 && AppState().bigPlayLimit >= 0)
                      ValueListenableBuilder<String>(
                        valueListenable: countdownLastBigPlayTimeText,
                        builder: (context, text, child) {
                          return Text(
                            text.isNotEmpty ? "Big Play: $text" : "Big Play Time Over",
                            style: const TextStyle(fontSize: 11),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(), // Ensure scrollability even when content is smaller
            child: Column(
              children: [
                const SizedBox(height: 8.0),
                Column(
                  children: _buildNumberInputs(),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _buildAdditionalComponents(), // Add additional components here
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  List<Widget> _buildNumberInputs() {
    List<Widget> rows = [];
    for (int i = 0; i < 10; i++) {
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5), // Reduce vertical padding
          child: Row(
            children: _buildRow(i),
          ),
        ),
      );
    }
    return rows;
  }

  List<Widget> _buildRow(int start) {
    List<Widget> row = [];
    for (int i = 0; i < 10; i++) {
      int number = start + i * 10;
      row.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(1.0), // Reduce padding
            child: TextField(
                controller: editTextControllers[number],
                decoration: InputDecoration(
                  labelText: number.toString().padLeft(2, '0'),
                  labelStyle: const TextStyle(fontSize: 16, color: Colors.blue,), // Reduce label text size
                  contentPadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0.0), // Reduce content padding
                  border: const OutlineInputBorder(),
                  isDense: true, // Make the input field more compact
                  floatingLabelBehavior: FloatingLabelBehavior.always, // Ensure label is always visible
                  floatingLabelAlignment: FloatingLabelAlignment.center,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Allow only digits
                  LengthLimitingTextInputFormatter(9), // Limit input to 9 digits
                ],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                ) // Text color changes based on theme), // Reduce font size
            ),
          ),
        ),
      );
    }
    return row;
  }


  Widget _buildAdditionalComponents() {
    return Column(
      // crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 4. Use ValueListenableBuilder to listen to changes in total amount
            ValueListenableBuilder<int>(
              valueListenable: _totalAmount,
              builder: (context, total, child) {
                return Text('Total: $total');
              },
            ),
            Consumer<AppState>(
              builder: (context, appState, child) {
                return Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.grey,), // Wallet icon
                    const SizedBox(width: 4),
                    Text(
                      '${appState.balance}',  // Replace with actual balance from AppState
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: appState.balance > 0
                            ? Colors.green
                            : (appState.balance < 0 ? Colors.red : Colors.black), // Black for 0, green for > 0, red for < 0
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10.0),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6, // 60% width for the inputs
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _numberInputController,
                            keyboardType: TextInputType.number,
                            maxLines: null,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              labelText: 'Enter Numbers',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0), // Adjust padding
                            ),
                            style: const TextStyle(fontSize: 14), // Adjust font size
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isReverseChecked,
                                  visualDensity: VisualDensity.compact, // Reduces checkbox padding
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Smaller tap area
                                  onChanged: (value) {
                                    setState(() {
                                      isReverseChecked = value ?? false;
                                    });
                                  },
                                ),

                                GestureDetector(
                                  onTap: () {
                                    _reverseNumbers(context);
                                  },
                                  child: const Icon(Icons.sync),
                                ),


                              ],
                            ),

                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  isReverseChecked = !isReverseChecked;
                                });
                              },
                              child: Text(
                                isReverseChecked ? '+Reverse' : 'Reverse',
                                style: const TextStyle(fontSize: 12), // Small font for compactness
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),

                    const SizedBox(height: 8.0), // Reduce spacing between fields

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _crossingInputController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            decoration: const InputDecoration(
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              labelText: 'Crossing',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isWithoutPairChecked = !isWithoutPairChecked;
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                visualDensity: VisualDensity.compact, // Compact checkbox
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                value: isWithoutPairChecked,
                                onChanged: (value) {
                                  setState(() {
                                    isWithoutPairChecked = value ?? false;
                                  });
                                },
                              ),
                              const Text(
                                // isWithoutPairChecked ?' Without\n  Pair' : ' Without\n  Pair',
                                ' Without\n  Pair',
                                style: TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20.0),
                      ],
                    ),

                    const SizedBox(height: 8.0), // Reduce spacing between fields

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputAController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              labelText: 'A inside no.',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: TextField(
                            controller: _inputBController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              labelText: 'B outside no.',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 55.0),
                      ],
                    ),

                    const SizedBox(height: 8.0), // Reduce spacing between fields

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fromController,
                            focusNode: _fromFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              labelText: 'From',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: TextField(
                            controller: _toController,
                            focusNode: _toFocusNode,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              labelText: 'To',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 55.0),
                      ],
                    ),
                  ],
                )
            ),

            const Spacer(),

            Expanded(
              flex: 2,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            focusNode: _amountFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(signed: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9), // Limit to 9 characters
                            ],
                            decoration: const InputDecoration(
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              labelText: 'Amount',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0), // Compact padding
                            ),
                            style: const TextStyle(fontSize: 14), // Adjust font size
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6.0), // Reduce space between rows

                    ElevatedButton(
                      onPressed: () {
                        processButton();
                      }, // Add your button press action here
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero, // Removes extra padding
                        // minimumSize: const Size(50, 30), // Adjust button size as needed
                      ),

                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Set'),
                          SizedBox(width: 5),
                          Icon(Icons.upload, size: 18), // You can change the icon and size as per your need
                        ],
                      ),
                    ),
                  ],
                ),
            ),
          ],
        ),

        const SizedBox(height: 8.0),

        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _multiCodeController,
                maxLines: null,
                decoration: const InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  labelText: 'Paste Multi Code',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0), // Adjust padding
                ),
                style: const TextStyle(fontSize: 14), // Adjust font size
              ),
            ),

            // const SizedBox(width: 20.0),

            const Spacer(),

            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  onSetCodeButtonPressed();
                }, // Add your button press action here
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero, // Removes extra padding
                  // minimumSize: const Size(50, 30), // Adjust button size as needed
                ),

                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Multi Code'),
                    SizedBox(width: 5),
                    Icon(Icons.upload, size: 18), // You can change the icon and size as per your need
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10.0),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [

            if (widget.isEditGame == true)
              Flexible(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _confirmDeleteGame(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.delete_forever, color: Colors.white,),
                  label: const Text('Delete Game', style: TextStyle(color: Colors.white),),
                  // child: const Text('Delete Game'),
                ),
              ),

            Flexible(
              child: ElevatedButton.icon(
                onPressed: () {
                  _showClearConfirmationDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                ),
                icon: const Icon(Icons.clear, color: Colors.red),
                label: const Text('Clear Game'),
                // child: const Text('Clear Game'),
              ),
            ),
            widget.isEditGame
                ? Flexible(
              child: ElevatedButton.icon(
                onPressed: () {
                  updateGame();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade100,
                ),
                icon: const Icon(Icons.send, color: Colors.green),
                label: const Text('Update Game'),
                // child: const Text('Update Game'),
              ),
            )
                : Flexible(
              child: ElevatedButton.icon(
                onPressed: () {
                  submitGame();

                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade100,
                ),
                icon: const Icon(Icons.send, color: Colors.green),
                label: const Text('Submit Game'),
                // child: const Text('Submit Game'),
              ),
            ),

          ],
        ),
      ],
    );
  }

  void processButton() {
    String input = _numberInputController.text.replaceAll(" ", "");
    String crossingInput = _crossingInputController.text;
    String amountText = _amountController.text;
    String inputA = _inputAController.text;
    String inputB = _inputBController.text;
    String fromText = _fromController.text;
    String toText = _toController.text;

    // Check if amountText is empty or below 1
    if (amountText.isEmpty || int.tryParse(amountText) == null || int.parse(amountText) < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid amount")));
      return;
    }

    if (input.isEmpty && crossingInput.isEmpty && inputA.isEmpty && inputB.isEmpty && (fromText.isEmpty || toText.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter Numbers To Set")));
      return;
    }

    int amount = int.parse(amountText);

    processEditTextNumberInput(input, amount);
    processEditTextNumberCrossing(crossingInput, amount);
    processEditTextNumberAB(amount);

    // Process the range between from and to
    if (fromText.isNotEmpty && toText.isNotEmpty) {
      int from = int.parse(fromText);
      int to = int.parse(toText);
      processEditTextNumberFromTo(from, to, amount);
    }

    _amountController.clear();
    _numberInputController.clear();

    // Check if the CheckBox is checked and reverse the input accordingly
    if (isReverseChecked) {
      String reversedInput = reverseNumbers(input);
      processEditTextNumberInput(reversedInput, amount);

      // Uncheck the CheckBox after processing
      setState(() {
        isReverseChecked = false;
      });
    }
    // Optional: Add vibration
    // Vibrate
  }

  String reverseNumbers(String input) {
    StringBuffer reversedInput = StringBuffer();

    for (int i = 0; i < input.length; i += 2) {
      if (i + 1 < input.length) {
        // Reverse the pair of digits
        reversedInput.write(input[i + 1]);
        reversedInput.write(input[i]);
      } else {
        // If there's only one digit left, append it as is
        reversedInput.write(input[i]);
      }
    }

    // If the length is odd, add "0" at the end
    if (input.length % 2 != 0) {
      reversedInput.write("0");
    }

    return reversedInput.toString();
  }


  void processEditTextNumberInput(String input, int amount) {
    Map<String, int> countMap = {};

    // Process input
    for (int i = 0; i < input.length - 1; i += 2) {
      String twoDigitNumber = input.substring(i, i + 2);
      countMap[twoDigitNumber] = (countMap[twoDigitNumber] ?? 0) + 1;
    }

    if (input.length % 2 != 0) {
      String lastTwoDigits = "0${input[input.length - 1]}";
      countMap[lastTwoDigits] = (countMap[lastTwoDigits] ?? 0) + 1;
    }

    // Iterate over the digit pairs and update the corresponding TextFields
    countMap.forEach((digitPair, count) {
      int digit = int.parse(digitPair);
      if (editTextControllers.containsKey(digit)) {
        int currentValue = int.tryParse(editTextControllers[digit]!.text) ?? 0;
        int sum = currentValue + (amount * count);
        // Check if the sum is 0 or below, then set the text to blank
        if (sum <= 0) {
          editTextControllers[digit]!.clear();
        } else {
          editTextControllers[digit]!.text = sum.toString();
        }
      }
    });

  }

  void processEditTextNumberCrossing(String crossingInput, int amount) {
    // Remove duplicate single digits from input, keep one occurrence
    Set<String> uniqueDigitsSet = {};
    StringBuffer uniqueDigitsBuffer = StringBuffer();

    for (int i = 0; i < crossingInput.length; i++) {
      String digit = crossingInput[i];
      if (!uniqueDigitsSet.contains(digit)) {
        uniqueDigitsSet.add(digit);
        uniqueDigitsBuffer.write(digit);
      }
    }

    String uniqueDigits = uniqueDigitsBuffer.toString();

    StringBuffer allTwoDigitNumbersBuffer = StringBuffer();
    for (int i = 0; i < uniqueDigits.length; i++) {
      for (int j = 0; j < uniqueDigits.length; j++) {
        allTwoDigitNumbersBuffer.write('${uniqueDigits[i]}${uniqueDigits[j]}');
      }
    }

    String allTwoDigitNumbers = allTwoDigitNumbersBuffer.toString();

    Map<String, int> countMap = {};

    // Process the counts of two-digit numbers for editTextNumberCrossing
    for (int i = 0; i < allTwoDigitNumbers.length; i += 2) {
      String twoDigitNumber = allTwoDigitNumbers.substring(i, i + 2);
      countMap[twoDigitNumber] = (countMap[twoDigitNumber] ?? 0) + 1;
    }

    countMap.forEach((twoDigitNumber, count) {
      // Check if the CheckBox is checked and if the twoDigitNumber is in the exclusion list
      if (isWithoutPairChecked && ([
        '00', '11', '22', '33', '44',
        '55', '66', '77', '88', '99'
      ].contains(twoDigitNumber))) {
        return; // Skip to the next iteration
      }

      int result = count * amount;

      if (editTextControllers.containsKey(int.parse(twoDigitNumber))) {
        int currentValue = int.tryParse(editTextControllers[int.parse(twoDigitNumber)]!.text) ?? 0;
        int sum = currentValue + result;

        // Check if the sum is 0 or negative, then set the text to blank
        if (sum <= 0) {
          editTextControllers[int.parse(twoDigitNumber)]!.clear();
        } else {
          editTextControllers[int.parse(twoDigitNumber)]!.text = sum.toString();
        }
      }
    });

    // Clear the input and uncheck the checkbox
    _crossingInputController.clear();
    setState(() {
      isWithoutPairChecked = false;
    });
  }

  void processEditTextNumberAB(int amount) {
    String inputA = _inputAController.text;
    String inputB = _inputBController.text;

    StringBuffer allTwoDigitNumbersA = StringBuffer();
    for (int i = 0; i < inputA.length; i++) {
      String digit = inputA[i];
      if (digit == '0') {
        allTwoDigitNumbersA.write('00010203040506070809');
      } else if (int.tryParse(digit)! >= 1 && int.tryParse(digit)! <= 9) {
        int start = (int.tryParse(digit)!) * 10;
        for (int j = 0; j < 10; j++) {
          allTwoDigitNumbersA.write((start + j).toString().padLeft(2, '0'));
        }
      }
    }

    StringBuffer allTwoDigitNumbersB = StringBuffer();
    for (int i = 0; i < inputB.length; i++) {
      String digit = inputB[i];
      if (int.tryParse(digit)! >= 0 && int.tryParse(digit)! <= 9) {
        int endDigit = int.tryParse(digit)!;
        for (int j = 0; j < 100; j += 10) {
          int number = j + endDigit;
          allTwoDigitNumbersB.write(number.toString().padLeft(2, '0'));
        }
      }
    }

    // Process the counts of two-digit numbers for inputA
    Map<String, int> countMapA = {};
    for (int i = 0; i < allTwoDigitNumbersA.length; i += 2) {
      String twoDigitNumber = allTwoDigitNumbersA.toString().substring(i, i + 2);
      countMapA[twoDigitNumber] = (countMapA[twoDigitNumber] ?? 0) + 1;
    }
    countMapA.forEach((twoDigitNumber, count) {
      int result = count * amount;

      if (editTextControllers.containsKey(int.parse(twoDigitNumber))) {
        int currentValue = int.tryParse(editTextControllers[int.parse(twoDigitNumber)]!.text) ?? 0;
        int sum = currentValue + result;

        // Check if the sum is 0 or negative, then set the text to blank
        if (sum <= 0) {
          editTextControllers[int.parse(twoDigitNumber)]!.clear();
        } else {
          editTextControllers[int.parse(twoDigitNumber)]!.text = sum.toString();
        }
      }
    });

    // Process the counts of two-digit numbers for inputB
    Map<String, int> countMapB = {};
    for (int i = 0; i < allTwoDigitNumbersB.length; i += 2) {
      String twoDigitNumber = allTwoDigitNumbersB.toString().substring(i, i + 2);
      countMapB[twoDigitNumber] = (countMapB[twoDigitNumber] ?? 0) + 1;
    }
    countMapB.forEach((twoDigitNumber, count) {
      int result = count * amount;

      if (editTextControllers.containsKey(int.parse(twoDigitNumber))) {
        int currentValue = int.tryParse(editTextControllers[int.parse(twoDigitNumber)]!.text) ?? 0;
        int sum = currentValue + result;

        // Check if the sum is 0 or negative, then set the text to blank
        if (sum <= 0) {
          editTextControllers[int.parse(twoDigitNumber)]!.clear();
        } else {
          editTextControllers[int.parse(twoDigitNumber)]!.text = sum.toString();
        }
      }
    });

    // Clear input fields
    _inputAController.clear();
    _inputBController.clear();
  }

  void processEditTextNumberFromTo(int from, int to, int amount) {
    StringBuffer allTwoDigitNumbers = StringBuffer();

    // Generate all 2-digit numbers between from and to
    if (from <= to) {
      for (int i = from; i <= to; i++) {
        if (i >= 0 && i <= 9) {
          allTwoDigitNumbers.write('0');
        }
        allTwoDigitNumbers.write(i);
      }
    } else {
      for (int i = from; i >= to; i--) {
        if (i >= 0 && i <= 9) {
          allTwoDigitNumbers.write('0');
        }
        allTwoDigitNumbers.write(i);
      }
    }

    Map<String, int> countMap = {};

    // Process the counts of two-digit numbers
    for (int i = 0; i < allTwoDigitNumbers.length; i += 2) {
      String twoDigitNumber = allTwoDigitNumbers.toString().substring(i, i + 2);
      countMap[twoDigitNumber] = (countMap[twoDigitNumber] ?? 0) + 1;
    }

    countMap.forEach((twoDigitNumber, count) {
      int result = count * amount;

      if (editTextControllers.containsKey(int.parse(twoDigitNumber))) {
        int currentValue = int.tryParse(editTextControllers[int.parse(twoDigitNumber)]!.text) ?? 0;
        int sum = currentValue + result;

        // Check if the sum is 0 or negative, then set the text to blank
        if (sum <= 0) {
          editTextControllers[int.parse(twoDigitNumber)]!.clear();
        } else {
          editTextControllers[int.parse(twoDigitNumber)]!.text = sum.toString();
        }
      }
    });

    // Clear input fields
    _fromController.clear();
    _toController.clear();
  }

  // bool isValidTextCode(String textCode) { // in this getting problem if in the last text has new value it changes the return value from false to true
  //   textCode = textCode.replaceAll(" ", "");
  //   List<String> pairs = textCode.split(RegExp(r'/|\n|#')); // Split by '/', '\n', or '#'
  //
  //   for (String pair in pairs) {
  //     if (!RegExp(r'^\d{2}(=\d{1,19}|,\s*\(\s*\d+\s*\)|=\d{1,19})$').hasMatch(pair)) {
  //       return false; // Invalid format for a pair
  //     }
  //   }
  //   return true; // All pairs have valid format
  // }

  bool isValidTextCode(String textCode) {
    // Split by '/', '\n', or '#', then trim each pair individually.
    List<String> pairs = textCode.split(RegExp(r'/|\n|#')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    for (String pair in pairs) {
      // Validate each pair using regex.
      if (!RegExp(r'^\d{2}(=\d{1,19}|,\(\d+\))$').hasMatch(pair)) {
        return false; // Invalid format for a pair
      }
    }

    return true; // All pairs have a valid format.
  }


  void onSetCodeButtonPressed() {

    String textCode = _multiCodeController.text;

    if (textCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter multi code")),
      );
    } else if (isValidTextCode(textCode)) {
      if (kDebugMode) {
        print('isVaidCode');
      }
      setGeneratedCodes(textCode);
    } else {
      if (kDebugMode) {
        print('in the else');
      }
      // Remove newline characters, English characters (a to z), and spaces from textCode  ,-./#*+=()
      textCode = textCode.replaceAll(RegExp(r"[\sA-Za-z\n`~!@$%^&;:'><?|_]"), "");

      // Split the input into individual patterns
      List<String> patterns = textCode.split(')');
      for (String pattern in patterns) {
        if (pattern.isNotEmpty) {
          // Process each pattern
          setGeneratedCodes2('$pattern)');
        }
      }
    }
  }



  void setGeneratedCodes(String textCode) {
    textCode = textCode.replaceAll(' ', '');
    List<String> pairs = textCode.split(RegExp(r'/|\n|#')); // Split by '/', '\n', or '#'

    for (String pair in pairs) {
      List<String> keyValue = pair.split(RegExp(r'=|,\s*\(\s*|\s*\)')); // Split by '=', ', ( ', ' )'
      int key = int.parse(keyValue[0]);
      int value = 0;

      if (keyValue.length == 2) {
        value = int.parse(keyValue[1].substring(0, keyValue[1].length.clamp(0, 10)));
      } else if (keyValue.length == 4) {
        value = int.parse(keyValue[3].substring(0, keyValue[3].length.clamp(0, 10)));
      }

      if (key >= 0 && key <= 99 && value >= 0) {
        TextEditingController? controller = editTextControllers[key];
        if (controller != null) {
          String existingValueString = controller.text;
          int existingValue = existingValueString.isEmpty ? 0 : int.parse(existingValueString);
          int sum = existingValue + value;
          if (sum <= 0) {
            controller.clear();
          } else {
            controller.text = sum.toString();
          }
        }
      }
    }
    _multiCodeController.clear();
  }

  // this one is not working well like java method need to resolve it later
  void setGeneratedCodes2(String textCode) {
    // Extract the number and the count from the textCode
    final pattern = RegExp(r'([0-9,\-./#*+=()]+)\((\d+)\)');
    final match = pattern.firstMatch(textCode);

    // Check if a valid match is found
    if (match != null) {
      String numbers = match.group(1)!.replaceAll(RegExp(r'[^0-9]'), ''); // Remove non-numeric characters
      String count = match.group(2)!;

      // Process the counts of two-digit numbers for editTextNumberInput
      int countValue = int.parse(count.substring(0, count.length.clamp(0, 10)));

      for (int i = 0; i < numbers.length; i += 2) {
        // Extract two digits from the number
        String twoDigitNumber = numbers.substring(i, i + 2);

        // Add a '0' prefix if the number is a single digit
        if (twoDigitNumber.length == 1) {
          twoDigitNumber = '0$twoDigitNumber';
        }

        int key = int.parse(twoDigitNumber);
        TextEditingController? controller = editTextControllers[key];

        if (controller != null) {
          String existingValue = controller.text;
          int existingNumber = existingValue.isNotEmpty ? int.parse(existingValue) : 0;
          int sum = existingNumber + countValue;

          // Check if the sum is 0 or negative, then set the text to blank
          if (sum <= 0) {
            controller.clear();
          } else {
            controller.text = sum.toString();
          }
        }
      }
      _multiCodeController.clear();
    }
  }

  void _showClearConfirmationDialog(BuildContext context) {
    if (isDataFilled()) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text("Clear All Values"),
            content: const Text("Are you sure you want to clear all values?"),
            actions: <Widget>[
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
              ),
              TextButton(
                child: const Text("Clear"),
                onPressed: () {
                  _clearValues(); // Call the method to clear values
                  Navigator.of(context).pop(); // Close the dialog
                },
              ),
            ],
          );
        },
      );
    } else {
      // Show "No data to clear" message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data to clear")),
      );
    }
  }

  bool isDataFilled() {
    for (int i = 0; i <= 99; i++) {
      String value = editTextControllers[i]?.text ?? '';

      // Try to parse the value to an integer
      int? numericValue = int.tryParse(value);

      // Check if the value is valid and greater than or equal to 1
      if (numericValue != null && numericValue >= 1) {
        return true;
      }
    }
    return false;
  }


  void _clearValues() {
    for (int i = 0; i <= 99; i++) {
      editTextControllers[i]?.clear();
    }
  }

  String generateSlotAmount() {
    StringBuffer textCode = StringBuffer();

    for (int i = 0; i <= 99; i++) {
      String value = editTextControllers[i]?.text ?? '';
      // Try to parse the value to an integer
      int? numericValue = int.tryParse(value);

      // Check if the value is valid and greater than or equal to 1
      if (numericValue != null && numericValue >= 1) {
        textCode.write('${i.toString().padLeft(2, '0')}=${numericValue.toString()} / ');
      }
    }

    String result = textCode.toString();
    if (result.isNotEmpty) {
      // Remove the trailing " / "
      result = result.substring(0, result.length - 3);
    }

    return result;
  }



  void submitGame() async {
    if (!isDataFilled()) {
      // Show a message if no data is filled
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to submit')),
      );
      return;
    }
    bool isConfirmed = await _showConfirmationDialog(
        'Confirm Submit',
        'Are you sure you want to submit the game?'
    );

    if (!isConfirmed) return; // Stop if the user cancels

    // Show the loading dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog by tapping outside
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(), // Show a circular progress indicator
        );
      },
    );

    try {
      await _refreshTime();

      if (AppState().currentTime.isAfter(gameCloseTime)){
        return;
      }

      int gameId = widget.gameId;
      int kpId = AppState().kpId;
      // Run all Supabase queries in parallel
      final results = await Future.wait([
        // Query 1: Check disputes
        supabase
            .from('kp_logs')
            .select('id')
            .eq('kp_id', kpId)
            .or('user_dispute.eq.true,khaiwal_dispute.eq.true')
            .limit(1)
            .maybeSingle(), // Query 1: Check disputes

        // Query 2: Fetch player details
        supabase
            .from('khaiwals_players')
            .select('allowed, balance, debt_limit, big_play_limit')
            .eq('id', kpId)
            .maybeSingle(),

        // Query 3: Fetch game pause/off day/result status
        supabase
            .from('games')
            .select('game_result, off_day, pause')
            .eq('id', gameId)
            .maybeSingle(),

        // Query 4: Fetch game info
        supabase
            .from('game_info')
            .select('id, full_game_name, open_time, big_play_min, close_time_min, day_before, is_active')
            .eq('id', widget.infoId)
            .maybeSingle(),
      ]);

      // Process results
      final disputeCheckResponse = results[0]; // Query 1 result
      final allowedResponse = results[1]; // Query 2 result
      final pauseResponse = results[2]; // Query 3 result
      final infoResponse = results[3]; // Query 4 result

      // Check for disputes
      if (disputeCheckResponse != null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('There is unresolved dispute. Resolve it before proceeding.')),
        );
        return;
      }

      // Check allowed response
      if (allowedResponse == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player record not found')),
        );
        return;
      }
      AppState().allowed = allowedResponse['allowed'];
      AppState().balance = allowedResponse['balance'];
      AppState().debtLimit = allowedResponse['debt_limit'];
      AppState().bigPlayLimit = allowedResponse['big_play_limit'];
      AppState().notifyListeners();

      if (AppState().allowed == null) {
        Navigator.of(context).pop();
        _popDialog('Status', 'Connection status with host is pending');
        return;
      } else if (AppState().allowed == false) {
        Navigator.of(context).pop();
        _popDialog('Status', 'Connection status with host is blocked');
        return;
      }

      // Check game pause/off day/result status
      if (pauseResponse == null) {
        Navigator.of(context).pop();
        _showPopDialog('Deleted', 'Game has been deleted by host');
        return;
      } else if (pauseResponse['pause'] == true) {
        Navigator.of(context).pop();
        _popDialog('Game Status', 'Game is currently paused by host');
        return;
      } else if (pauseResponse['off_day'] == true) {
        Navigator.of(context).pop();
        _showPopDialog('Day Off', 'Game is now Off for today');
        return;
      } else if (pauseResponse['game_result'] != null) {
        Navigator.of(context).pop();
        _showPopDialog('Result Declared', 'Game Result has been declared');
        return;
      }

      // Check game info
      if (infoResponse == null) {
        Navigator.of(context).pop();
        _showPopDialog('Deleted', 'Game has been deleted by host');
        return;
      } else if (infoResponse['is_active'] == false) {
        Navigator.of(context).pop();
        _showPopDialog('Deactivated', 'Game is not Active');
        return;
      } else if (infoResponse['full_game_name'] != widget.fullGameName ||
          infoResponse['open_time'] != widget.onlyOpenTime ||
          infoResponse['big_play_min'] != widget.lastBigPlayMinute ||
          infoResponse['close_time_min'] < widget.closeTimeMin ||
          infoResponse['day_before'] != widget.isDayBefore) {
        Navigator.of(context).pop();
        _showPopDialog('Settings Changed', 'Game Settings has been changed, Reopen the game to play');
        return;
      }

      // Check for existing disputes
      // final disputeCheckResponse = await supabase
      //     .from('kp_logs')
      //     .select('id')
      //     .eq('kp_id', AppState().kpId)
      //     .or('user_dispute.eq.true,khaiwal_dispute.eq.true')
      //     .limit(1)
      //     .maybeSingle();
      //
      //
      // if (disputeCheckResponse != null) {
      //   Navigator.of(context).pop(); // Close the dialog
      //   // Handle the case where no record is found (shouldn't happen if kpId is valid)
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('There is unresolved dispute. Resolve it before proceeding.')),
      //   );
      //   return; // Halt further execution
      // }
      //
      // final allowedResponse = await supabase
      //     .from('khaiwals_players')
      //     .select('allowed, balance, debt_limit, big_play_limit')
      //     .eq('id', AppState().kpId);
      //
      // if (allowedResponse.isEmpty) {
      //   Navigator.of(context).pop(); // Close the dialog
      //   // Handle the case where no record is found (shouldn't happen if kpId is valid)
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Player record not found')),
      //   );
      //   return;
      // }
      // AppState().allowed = allowedResponse[0]['allowed'];
      //
      // // Check the value of 'allowed'
      // if (AppState().allowed == null) {
      //   Navigator.of(context).pop(); // Close the dialog
      //   // If 'allowed' is null, show approval pending message
      //   _popDialog('Status', 'Connection status with host is pending');
      //   return;
      // } else if (AppState().allowed == false) {
      //   Navigator.of(context).pop(); // Close the dialog
      //   // If 'allowed' is false, show not allowed message
      //   _popDialog('Status', 'Connection status with host is blocked');
      //   return;
      // }
      //
      // AppState().balance = allowedResponse[0]['balance'];
      // AppState().debtLimit = allowedResponse[0]['debt_limit'];
      // AppState().bigPlayLimit = allowedResponse[0]['big_play_limit'];
      // AppState().notifyListeners();
      //
      // int gameId = widget.gameId;
      // // Fetch the 'pause' status from the 'games' table for the current gameId
      // final pauseResponse = await supabase
      //     .from('games')
      //     .select('game_result, off_day, pause')
      //     .eq('id', gameId);
      // // .single(); // Ensure you're only fetching one row
      //
      // if (pauseResponse.isEmpty) {
      //   Navigator.of(context).pop(); // Close the dialog
      //   _showPopDialog('Deleted', 'Game has been deleted by host');
      //   return;
      // } else if (pauseResponse[0]['pause'] == true) {
      //   Navigator.of(context).pop(); // Close the dialog
      //   // If the game is paused, show a message and return
      //   _popDialog('Game Status', 'Game is currently paused by host');
      //   return;
      // } else if (pauseResponse[0]['off_day'] == true) {
      //   Navigator.of(context).pop(); // Close the dialog
      //   _showPopDialog('Day Off', 'Game is now Off for today');
      //   return;
      // }  else if (pauseResponse[0]['game_result'] != null){
      //   Navigator.of(context).pop(); // Close the dialog
      //   _showPopDialog('Result Declared', 'Game Result has been declared');
      //   return;
      // }
      //
      // // Fetch the 'info' status from the 'game_info' table for the current gameId
      // final infoResponse = await supabase
      //     .from('game_info')
      //     .select('id, full_game_name, open_time, big_play_min, close_time_min, day_before, is_active')
      //     .eq('id', widget.infoId);
      //
      // if (infoResponse.isEmpty){
      //   Navigator.of(context).pop(); // Close the dialog
      //   _showPopDialog('Deleted', 'Game has been deleted by host');
      //   return;
      // } else if (infoResponse[0]['is_active'] == false){
      //   Navigator.of(context).pop(); // Close the dialog
      //   _showPopDialog('Deactivated', 'Game is not Active');
      //   return;
      // } else if (infoResponse[0]['full_game_name'] != widget.fullGameName || infoResponse[0]['open_time'] != widget.onlyOpenTime || infoResponse[0]['big_play_min'] != widget.lastBigPlayMinute
      //     || infoResponse[0]['close_time_min'] < widget.closeTimeMin || infoResponse[0]['day_before'] != widget.isDayBefore) {
      //   Navigator.of(context).pop(); // Close the dialog
      //   _showPopDialog('Settings Changed', 'Game Settings has been changed, Reopen the game to play');
      //   return;
      // }


      String slotAmount = generateSlotAmount();
      int totalInvested = 0;

      // Check if a record with the same kp_id and game_id already exists
      final existingEntryResponse = await supabase
          .from('game_play')
          .select('id, play_txn_id, slot_amount')
          .eq('kp_id', kpId)
          .eq('game_id', gameId);

      // updating the game when already exist
      if (existingEntryResponse.isNotEmpty) {

        int existingId = existingEntryResponse[0]['id'];
        int playTxnId = existingEntryResponse[0]['play_txn_id'];
        String existingSlotAmount = existingEntryResponse[0]['slot_amount'];

        // Parse the existing and new slot amounts
        Map<String, int> combinedSlots = {};

        void parseSlotAmount(String slotAmountStr) {
          List<String> pairs = slotAmountStr.split(' / ');
          for (String pair in pairs) {
            List<String> parts = pair.split('=');
            if (parts.length == 2) {
              String key = parts[0];
              int value = int.parse(parts[1]);
              totalInvested += value;
              combinedSlots[key] = (combinedSlots[key] ?? 0) + value;
            }
          }
        }

        parseSlotAmount(existingSlotAmount);
        parseSlotAmount(slotAmount);

        if (exceededBigPlayLimit && AppState().bigPlayLimit != -1) {
          if (AppState().bigPlayLimit == 0) {
            Navigator.pop(context);
            _popDialog(
              'Big Play Time',
              'Game play after big play time is disabled by host',
            );
            return;
          }
          // Check if any slot value exceeds bigPlayLimit
          for (var entry in combinedSlots.entries) {
            String key = entry.key;
            int value = entry.value;
            if (value > AppState().bigPlayLimit) {
              Navigator.of(context).pop(); // Close the dialog
              _popDialog(
                'Big Play Time',
                'Time is over for big play\n\n$key=$value exceeds the limit of big play (${AppState().bigPlayLimit}) that has been set by host',
              );
              return; // This exits the entire method
            }
          }
        }



        // Sort the combined slots by the slot numbers (keys)
        List<MapEntry<String, int>> sortedEntries = combinedSlots.entries.toList()
          ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

        // Generate the combined slot amount string
        String combinedSlotAmount = sortedEntries
            .map((entry) => '${entry.key}=${entry.value}')
            .join(' / ');

        num updatedWallet = AppState().balance - _totalAmount.value;

        if (updatedWallet < 0 && AppState().debtLimit == 0) {
          Navigator.of(context).pop(); // Close the dialog
          _popDialog('Balance', 'Current balance is insufficient');
          return;

        } else if (updatedWallet < AppState().debtLimit && AppState().debtLimit != 0) {
          Navigator.of(context).pop(); // Close the dialog
          _popDialog('Balance', 'Current balance is insufficient & do not have enough Loan limit to play');
          return;
        }
        // Check for device mismatch
        final isMismatch = await AppState().checkDeviceMismatch(context);
        if (isMismatch) return; // Halt if there's a mismatch

        // Call the RPC function
        final response = await supabase.rpc(
          'play_update',
          params: {
            '_kp_id': kpId,
            '_game_play_id': existingId,
            '_play_txn_id': playTxnId,
            '_slot_amount': combinedSlotAmount,
            '_total_amount': _totalAmount.value,
            '_total_invested': totalInvested,
            '_timestamp': AppState().currentTime.toIso8601String(),
          },
        );

        if (response != null) {
          Navigator.of(context).pop(); // Close the dialog
          // Handle the error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit data: $response')),
          );
        } else {
          Navigator.of(context).pop(); // Close the dialog
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Game submitted successfully in ${widget.fullGameName}'),
              backgroundColor: Colors.green,
            ),
          );

          AppState().balance = updatedWallet;
          AppState().gamePlayExists[gameId] = true;
          AppState().notifyListeners();

          Navigator.of(context).popUntil((route) => route.isFirst); // Close all dialogs and go back to the first page
        }

        return;
      }

      num updatedWallet = AppState().balance - _totalAmount.value;

      if (updatedWallet < 0 && AppState().debtLimit == 0) {
        Navigator.of(context).pop(); // Close the dialog
        _popDialog('Balance', 'Current balance is insufficient');
        return;

      } else if (updatedWallet < AppState().debtLimit && AppState().debtLimit != 0) {
        Navigator.of(context).pop(); // Close the dialog
        _popDialog('Balance', 'Current balance is insufficient & do not have enough Loan limit to play');
        return;
      }

      if (exceededBigPlayLimit && AppState().bigPlayLimit != -1) {
        if (AppState().bigPlayLimit == 0) {
          Navigator.pop(context);
          _popDialog(
            'Big Play Time',
            'Game play after big play time is disabled by host',
          );
          return;
        }
        List<String> pairs = slotAmount.split(' / ');
        for (String pair in pairs) {
          List<String> parts = pair.split('=');
          if (parts.length == 2) {
            int value = int.parse(parts[1]);
            if (value > AppState().bigPlayLimit) {
              Navigator.of(context).pop(); // Close the dialog
              _popDialog('Big Play Time', 'Time is over for big play\n\n$pair exceeds the limit of big play (${AppState().bigPlayLimit}) that has been set by host');
              return;
            }
          }
        }
      }

      // Check for device mismatch
      final isMismatch = await AppState().checkDeviceMismatch(context);
      if (isMismatch) return; // Halt if there's a mismatch

      // Call the RPC function
      final response = await supabase.rpc(
        'play_insert',
        params: {
          '_kp_id': kpId,
          '_game_id': gameId,
          '_slot_amount': slotAmount,
          '_total_amount': _totalAmount.value,
          '_timestamp': AppState().currentTime.toIso8601String(),
        },
      );


      if (response != null) {
        Navigator.of(context).pop(); // Close the dialog
        // Handle the error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit data game')),
        );
      } else {
        Navigator.of(context).pop(); // Close the dialog
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Game submitted successfully in ${widget.fullGameName}'),
            backgroundColor: Colors.green,
          ),
        );

        AppState().balance = updatedWallet;
        AppState().gamePlayExists[gameId] = true;
        AppState().notifyListeners();

        Navigator.of(context).popUntil((route) => route.isFirst); // Close all dialogs and go back to the first page
      }
    }catch (e) {
      Navigator.of(context).pop(); // Close the dialog if an error occurs
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred')),
      );
    }

  }


  void updateGame() async {
    if (!isDataFilled()) {
      // Show a message if no data is filled
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to update')),
      );
      return;
    }

    bool isConfirmed = await _showConfirmationDialog(
        'Confirm Update',
        'Are you sure you want to update the game?'
    );

    if (!isConfirmed) return; // Stop if the user cancels

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      await _refreshTime();

      if (AppState().currentTime.isAfter(gameCloseTime)) {
        return;
      }

      if (AppState().editMinutes != -1 && AppState().currentTime.isAfter(lastEditTime)) {
        Navigator.pop(context); // Close the loading dialog
        // Show a message edit time is over
        // _showPopDialog('Edit Time Over', 'The game edit time has ended.');
        return;
      }
      int gameId = widget.gameId;
      int kpId = AppState().kpId;

      // Run all Supabase queries in parallel
      final results = await Future.wait([
        // Query 1: Check disputes
        supabase
            .from('kp_logs')
            .select('id')
            .eq('kp_id', kpId)
            .or('user_dispute.eq.true,khaiwal_dispute.eq.true')
            .limit(1)
            .maybeSingle(),

        // Query 2: Fetch game pause/off day/result status
        supabase
            .from('games')
            .select('game_result, off_day, pause')
            .eq('id', gameId)
            .maybeSingle(),

        // Query 3: Fetch game info
        supabase
            .from('game_info')
            .select(
            'id, full_game_name, open_time, big_play_min, close_time_min, day_before, is_active')
            .eq('id', widget.infoId)
            .maybeSingle(),

        // Query 4: Fetch player details
        supabase
            .from('khaiwals_players')
            .select('allowed, balance, debt_limit, big_play_limit, edit_minutes')
            .eq('id', kpId)
            .maybeSingle(),
      ]);

      // Process results
      final disputeCheckResponse = results[0];
      final pauseResponse = results[1];
      final infoResponse = results[2];
      final allowedResponse = results[3];

      if (kDebugMode) {
        print('allowedResponse: $allowedResponse');
      }

      // Check for disputes
      if (disputeCheckResponse != null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Error: There is unresolved dispute. Resolve it before cancelling.'),
              backgroundColor: Colors.red),
        );
        return;
      }

      // Check game pause/off day/result status
      if (pauseResponse == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game has been deleted')),
        );
        return;
      } else if (pauseResponse['pause'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game is currently paused')),
        );
        return;
      } else if (pauseResponse['off_day'] == true) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game is now Off for today')),
        );
        return;
      } else if (pauseResponse['game_result'] != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game Result has been declared')),
        );
        return;
      }

      // Check game info
      if (infoResponse == null) {
        Navigator.pop(context);
        _showPopDialog('Deleted', 'Game has been deleted by host');
        return;
      } else if (infoResponse['is_active'] == false) {
        Navigator.pop(context);
        _showPopDialog('Deactivated', 'Game is not Active');
        return;
      } else if (infoResponse['full_game_name'] != widget.fullGameName ||
          infoResponse['open_time'] != widget.onlyOpenTime ||
          infoResponse['big_play_min'] != widget.lastBigPlayMinute ||
          infoResponse['close_time_min'] < widget.closeTimeMin ||
          infoResponse['day_before'] != widget.isDayBefore) {
        Navigator.pop(context);
        _showPopDialog(
            'Setting Changed', 'Game Setting is changed, Reopen the game to update');
        return;
      }

      // Check allowed response
      if (allowedResponse == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player record not found')),
        );
        return;
      }

      // Update AppState with fetched player details
      if (AppState().editMinutes != allowedResponse['edit_minutes']) {
        Navigator.pop(context);
        _showPopDialog('Edit Time Changed',
            'Edit time has been changed by host, reopen the app');
        return;
      }

      AppState().balance = allowedResponse['balance'];
      AppState().debtLimit = allowedResponse['debt_limit'];
      AppState().bigPlayLimit = allowedResponse['big_play_limit'];
      AppState().allowed = allowedResponse['allowed'];

      if (AppState().allowed == null) {
        Navigator.pop(context);
        _popDialog('Connection Status', 'Connection status with host is pending');
        return;
      } else if (AppState().allowed == false) {
        Navigator.pop(context);
        _popDialog('Connection Status', 'Connection status with host is blocked');
        return;
      }

      // Check for existing disputes
      // final disputeCheckResponse = await supabase
      //     .from('kp_logs')
      //     .select('id')
      //     .eq('kp_id', kpId)
      //     .or('user_dispute.eq.true,khaiwal_dispute.eq.true')
      //     .limit(1)
      //     .maybeSingle();
      //
      // if (disputeCheckResponse != null) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //       content: Text('Error: There is unresolved dispute. Resolve it before cancelling.'),
      //       backgroundColor: Colors.red,
      //     ),
      //   );
      //   Navigator.of(context).pop();
      //   return; // Halt further execution
      // }
      //
      // // Fetch the 'pause' status from the 'games' table for the current gameId
      // final pauseResponse = await supabase
      //     .from('games')
      //     .select('game_result, off_day, pause')
      //     .eq('id', gameId);
      // // .single(); // Ensure you're only fetching one row
      //
      // if (pauseResponse.isEmpty) {
      //   Navigator.pop(context); // Close the loading dialog
      //   // If the game is paused, show a message and return
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Game has been deleted')),
      //   );
      //   return;
      // } else if (pauseResponse[0]['pause'] == true) {
      //   Navigator.pop(context); // Close the loading dialog
      //   // If the game is paused, show a message and return
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Game is currently paused')),
      //   );
      //   return;
      // } else if (pauseResponse[0]['off_day'] == true) {
      //   Navigator.pop(context); // Close the loading dialog
      //   // If the game is paused, show a message and return
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Game is now Off for today')),
      //   );
      //   return;
      // } else if (pauseResponse[0]['game_result'] != null){
      //   Navigator.pop(context); // Close the loading dialog
      //   // If the game is paused, show a message and return
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Game Result has been declared')),
      //   );
      //   return;
      // }
      //
      // // Fetch the 'info' status from the 'game_info' table for the current gameId
      // final infoResponse = await supabase
      //     .from('game_info')
      //     .select('id, full_game_name, open_time, big_play_min, close_time_min, day_before, is_active')
      //     .eq('id', widget.infoId);
      //
      // if (infoResponse.isEmpty){
      //   Navigator.pop(context); // Close the loading dialog
      //   _showPopDialog('Deleted', 'Game has been deleted by host');
      //   return;
      // } else if (infoResponse[0]['is_active'] == false){
      //
      //   Navigator.pop(context); // Close the loading dialog
      //   _showPopDialog('Deactivated', 'Game is not Active');
      //   return;
      // } else if (infoResponse[0]['full_game_name'] != widget.fullGameName || infoResponse[0]['open_time'] != widget.onlyOpenTime || infoResponse[0]['big_play_min'] != widget.lastBigPlayMinute
      //     || infoResponse[0]['close_time_min'] < widget.closeTimeMin || infoResponse[0]['day_before'] != widget.isDayBefore) {
      //
      //   Navigator.pop(context); // Close the loading dialog
      //   _showPopDialog('Setting Changed', 'Game Setting is changed, Reopen the game to update');
      //   return;
      // }
      //
      // final allowedResponse = await supabase
      //     .from('khaiwals_players')
      //     .select('allowed, balance, debt_limit, big_play_limit, edit_minutes')
      //     .eq('id', kpId);
      //
      // if (allowedResponse.isEmpty) {
      //   Navigator.pop(context); // Close the loading dialog
      //   // Handle the case where no record is found (shouldn't happen if kpId is valid)
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Player record not found')),
      //   );
      //   return;
      // }
      // if (AppState().editMinutes != allowedResponse[0]['edit_minutes']){
      //   _showPopDialog('Edit Time Changed', 'Edit time has been changed by host, reopen the app');
      //   return;
      // }
      //
      // AppState().balance = allowedResponse[0]['balance'];
      // AppState().debtLimit = allowedResponse[0]['debt_limit'];
      // AppState().bigPlayLimit = allowedResponse[0]['big_play_limit'];
      // AppState().allowed = allowedResponse[0]['allowed'];
      //
      // // Check the value of 'allowed'
      // if (AppState().allowed == null) {
      //   Navigator.pop(context); // Close the loading dialog
      //   // If 'allowed' is null, show approval pending message
      //   _popDialog('Connection Status', 'Connection status with host is pending');
      //   return;
      // } else if (AppState().allowed == false) {
      //   Navigator.pop(context); // Close the loading dialog
      //   // If 'allowed' is false, show not allowed message
      //   _popDialog('Connection Status', 'Connection status with host is blocked');
      //   return;
      // }


      String slotAmount = generateSlotAmount();
      int totalInvested = 0;

      if (exceededBigPlayLimit && AppState().bigPlayLimit != -1) {
        if (AppState().bigPlayLimit == 0) {
          Navigator.pop(context);
          _popDialog(
            'Big Play Time',
            'Game play after big play time is disabled by host',
          );
          return;
        }
        List<String> pairs = slotAmount.split(' / ');
        for (String pair in pairs) {
          List<String> parts = pair.split('=');
          if (parts.length == 2) {
            int value = int.parse(parts[1]);
            if (value > AppState().bigPlayLimit) {
              Navigator.pop(context); // Close the loading dialog
              _popDialog('Big Play Time', 'Time is over for big play\n\n$pair exceeds the limit of big play (${AppState().bigPlayLimit}) that has been set by host');
              return;
            }
          }
        }
      }

      if (existingSlotAmount.isNotEmpty) {

        void parseSlotAmount(String slotAmountStr) {
          List<String> pairs = slotAmountStr.split(' / ');
          for (String pair in pairs) {
            List<String> parts = pair.split('=');
            if (parts.length == 2) {
              int value = int.parse(parts[1]);
              totalInvested += value;
            }
          }
        }
        parseSlotAmount(existingSlotAmount);


        int difference = totalInvested - _totalAmount.value;

        num updatedWallet = allowedResponse['balance'] + difference;

        if (updatedWallet < 0 && AppState().debtLimit == 0) {
          Navigator.pop(context); // Close the loading dialog
          _popDialog('Balance', 'Current balance is insufficient');
          return;
        } else if (updatedWallet < AppState().debtLimit && AppState().debtLimit != 0) {
          Navigator.pop(context); // Close the loading dialog
          _popDialog('Balance', 'Current balance is insufficient & do not have enough Loan limit to play');
          return;
        }

        // Check for device mismatch
        final isMismatch = await AppState().checkDeviceMismatch(context);
        if (isMismatch) return; // Halt if there's a mismatch

        // Call the RPC function
        final response = await supabase.rpc(
          'play_edit',
          params: {
            '_kp_id': kpId,
            '_game_play_id': existingId,
            '_play_txn_id': playTxnId,
            '_slot_amount': slotAmount,
            '_total_amount': _totalAmount.value,
            '_difference': difference,
            '_timestamp': AppState().currentTime.toIso8601String(),
          },
        );

        if (response != null) {
          Navigator.pop(context); // Close the loading dialog
          // Handle the error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to submit data: $response')),
          );
        } else {
          Navigator.pop(context); // Close the loading dialog
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Game updated successfully in ${widget.fullGameName}'),
              backgroundColor: Colors.green,
            ),
          );

          AppState().balance = updatedWallet;
          AppState().notifyListeners();

          Navigator.of(context).popUntil((route) => route.isFirst); // Close all dialogs and go back to the first page
        }

        // final updateResponse = await supabase
        //     .from('game_play')
        //     .update({'slot_amount': slotAmount})
        //     .eq('id', existingId);
        //
        // // Update the wallet entry
        // final walletUpdateResponse = await supabase
        //     .from('wallet')
        //     .update({'amount': _totalAmount.value, 'timestamp': AppState().currentTime.toIso8601String()})
        //     .eq('id', playTxnId);
        //
        // if (updateResponse == null && walletUpdateResponse == null) {
        //
        //   final kpResponse = await supabase
        //       .from('khaiwals_players')
        //       .update({'balance': updatedWallet})
        //       .eq('id', kpId);
        //
        //   if (kpResponse == null) {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       SnackBar(content: Text('Game edited successfully in ${widget.fullGameName}'),
        //         backgroundColor: Colors.green,
        //       ),
        //     );
        //     // setState(() {
        //     //   // AppState().wallet += difference;
        //     //   // existingSlotAmount = slotAmount; //commented because closing after edited
        //     //
        //     // });
        //     AppState().balance = updatedWallet;
        //     AppState().notifyListeners();
        //     // Navigator.pop(context);
        //     Navigator.of(context).popUntil((route) => route.isFirst); // Close all dialogs and go back to the first page
        //   }
        //
        //   // _clearValues();
        // } else {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text('Failed to update data: ${updateResponse.error?.message ?? walletUpdateResponse.error?.message}')),
        //   );
        // }
      }

    }catch (e) {
      Navigator.pop(context); // Close the loading dialog in case of error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred while updating game')),
      );
    }


  }

  Future<void> _confirmDeleteGame(BuildContext context) async {
    // Show a confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this game? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // User pressed Cancel
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // User pressed Delete
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    // If the user confirmed deletion, proceed
    if (shouldDelete == true) {
      await _deleteGame(context); // Call the delete function
    }
  }


  Future<void> _deleteGame(BuildContext context) async {
    // Show the loading spinner
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog by tapping outside
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(), // Show a circular progress indicator
        );
      },
    );

    try {
      await _refreshTime();

      if (AppState().currentTime.isAfter(gameCloseTime)) {
        return;
      }

      int gameId = widget.gameId;
      // Fetch the 'pause' status from the 'games' table for the current gameId
      final pauseResponse = await supabase
          .from('games')
          .select('game_result, off_day, pause')
          .eq('id', gameId);
      // .single(); // Ensure you're only fetching one row

      if (pauseResponse.isEmpty) {
        Navigator.of(context).pop();
        // If the game is paused, show a message and return
        _showPopDialog('Deleted', 'Game has been deleted by host');
        return;
      } else if (pauseResponse[0]['pause'] == true) {
        Navigator.of(context).pop();
        // If the game is paused, show a message and return
        _popDialog('Paused', 'Game is currently paused by host');
        return;
      } else if (pauseResponse[0]['off_day'] == true) {
        Navigator.of(context).pop();
        // If the game is paused, show a message and return
        _showPopDialog('Day Off', 'Game is now Off for today');
        return;
      } else if (pauseResponse[0]['game_result'] != null){
        Navigator.of(context).pop();
        // If the game is paused, show a message and return
        _showPopDialog('Result Declared', 'Game Result has been declared');
        return;
      }
      // Fetch the 'info' status from the 'game_info' table for the current gameId
      final infoResponse = await supabase
          .from('game_info')
          .select('id, full_game_name, open_time, big_play_min, close_time_min, day_before, is_active')
          .eq('id', widget.infoId);

      if (infoResponse.isEmpty){
        Navigator.of(context).pop();
        _showPopDialog('Deleted', 'Game has been deleted by host');
        return;

      } else if (infoResponse[0]['is_active'] == false){
        Navigator.of(context).pop();
        _showPopDialog('Deactivated', 'Game is not Active');
        return;

      } else if (infoResponse[0]['full_game_name'] != widget.fullGameName || infoResponse[0]['open_time'] != widget.onlyOpenTime || infoResponse[0]['big_play_min'] != widget.lastBigPlayMinute
          || infoResponse[0]['close_time_min'] < widget.closeTimeMin || infoResponse[0]['day_before'] != widget.isDayBefore) {
        Navigator.of(context).pop();
        _showPopDialog('Setting Changed', 'Game Setting is changed, Reopen the game to delete');
        return;
      }

      final allowedResponse = await supabase
          .from('khaiwals_players')
          .select('allowed, balance')
          .eq('id', AppState().kpId);

      if (allowedResponse.isEmpty) {
        Navigator.of(context).pop();
        // Handle the case where no record is found (shouldn't happen if kpId is valid)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Player record not found')),
        );
        return;
      }

      AppState().balance = allowedResponse[0]['balance'];
      AppState().allowed = allowedResponse[0]['allowed'];

      // Check the value of 'allowed'
      if (AppState().allowed == null) {
        Navigator.of(context).pop();
        // If 'allowed' is null, show approval pending message
        _popDialog('Connection Status', 'Connection status with host is pending');
        return;
      } else if (AppState().allowed == false) {
        Navigator.of(context).pop();
        // If 'allowed' is false, show not allowed message
        _popDialog('Connection Status', 'Connection status with host is blocked');
        return;
      }

      if (AppState().editMinutes != -1 && AppState().currentTime.isAfter(lastEditTime)) {
        // Show a message edit time is over
        // _showPopDialog('Edit Time Over', 'The game edit time has been ended.');
        return;
      }

      int kpId = AppState().kpId;
      int totalInvested = 0;

      void parseSlotAmount(String slotAmountStr) {
        List<String> pairs = slotAmountStr.split(' / ');
        for (String pair in pairs) {
          List<String> parts = pair.split('=');
          if (parts.length == 2) {
            int value = int.parse(parts[1]);
            totalInvested += value;
          }
        }
      }

      parseSlotAmount(existingSlotAmount);
      num updatedWallet = allowedResponse[0]['balance'] + totalInvested;

      // Check for device mismatch
      final isMismatch = await AppState().checkDeviceMismatch(context);
      if (isMismatch) return; // Halt if there's a mismatch

      // Call the RPC
      final result = await supabase.rpc(
        'play_delete',
        params: {
          '_kp_id': kpId,
          '_game_play_id': existingId,
          '_play_txn_id': playTxnId,
        },
      );

      if (result == 'DELETE_SUCCESS') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delete processed successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        AppState().balance = updatedWallet;
        AppState().gamePlayExists[gameId] = false;
        AppState().notifyListeners();

        Navigator.of(context).popUntil((route) => route.isFirst); // Close all dialogs and go back to the first page
      } else if (result == 'ERROR_NO_DATA_FOUND') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data found to delete.')),
        );
      } else if (result == 'ERROR_RESULT_DECLARED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delete is not allowed. Game result has been declared.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error processing refund.')),
        );
      }
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred')),
      );
      Navigator.of(context).pop();
    }

  }


  void _reverseNumbers(BuildContext context) {
    String originalText = _numberInputController.text.replaceAll(" ", "");

    if (originalText.length > 1) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: const Text("Are you sure you want to reverse the numbers?"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog without action
                },
                child: const Text("No"),
              ),
              TextButton(
                onPressed: () {
                  // Perform the reversal
                  StringBuffer reversedInput = StringBuffer();
                  for (int i = 0; i < originalText.length; i += 2) {
                    if (i + 1 < originalText.length) {
                      // Reverse the two digits
                      reversedInput.write(originalText[i + 1]);
                      reversedInput.write(originalText[i]);
                    } else {
                      // Append the last digit if it's alone
                      reversedInput.write(originalText[i]);
                    }
                  }

                  // Update the text in the controller
                  _numberInputController.text = reversedInput.toString();
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: const Text("Yes"),
              ),
            ],
          );
        },
      );
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Return false if canceled
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Return true if confirmed
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false); // Ensure it returns false if null
  }





  @override
  void dispose() {
    _numberInputController.dispose();
    _crossingInputController.dispose();
    _amountController.dispose();
    _inputAController.dispose();
    _inputBController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    _amountFocusNode.dispose();
    for (int i = 0; i <= 99; i++) {
      editTextControllers[i]?.removeListener(_calculateTotalAmount);
      editTextControllers[i]?.dispose();
    }
    _totalAmount.dispose();

    // Reset the status bar color when the widget is disposed
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    _closeTimeChecker?.cancel();
    remainingCloseTime.dispose();
    countdownCloseTimeText.dispose();

    _lastBigPlayTimeChecker?.cancel();
    remainingLastBigPlayTime.dispose();
    countdownLastBigPlayTimeText.dispose();

    _lastEditTimeChecker?.cancel();
    super.dispose();
  }
}

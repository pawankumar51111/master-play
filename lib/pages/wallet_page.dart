import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:masterplay/pages/transaction_page.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/app_state.dart';
import 'game_page_history.dart';
import 'kplogs_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  _WalletPageState createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // Map<String, dynamic> userSettings = {};
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }


  Future<void> _fetchUserData() async {
    setState(() {
      loading = true;
    });

    await AppState().updateWallet();
    await AppState().updateNullActionCount();

    setState(() {
      loading = false;
    });

  }

  // Future<void> fetchUserSettings(int kpId) async {
  //   final khaiwalPlayerResponse = await supabase
  //       .from('khaiwals_players')
  //       .select('rate, commission, debt_limit, big_play_limit, edit_minutes, allowed')
  //       .eq('id', kpId)
  //       .maybeSingle();
  //
  //   if (khaiwalPlayerResponse != null) {
  //     AppState().kpRate =  khaiwalPlayerResponse['rate'] ?? 0;
  //     AppState().kpCommission = khaiwalPlayerResponse['commission'] ?? 0;
  //     AppState().debtLimit = khaiwalPlayerResponse['debt_limit'] ?? 0;
  //     AppState().bigPlayLimit = khaiwalPlayerResponse['big_play_limit'] ?? 0;
  //     AppState().editMinutes = khaiwalPlayerResponse['edit_minutes'] ?? -1;
  //     AppState().allowed = khaiwalPlayerResponse['allowed'];
  //
  //     AppState().notifyListeners();
  //   }
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balance'),
        backgroundColor: Colors.transparent,
        elevation: 0.0, // Remove default shadow
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.lightGreen.shade400, Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
        onRefresh: _fetchUserData,
          child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Consumer<AppState>(
              builder: (context, appState, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${appState.balance}',  // Replace with actual balance from AppState
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: appState.balance > 0
                                    ? Colors.green
                                    : (appState.balance < 0 ? Colors.red : Colors.black), // Black for 0, green for > 0, red for < 0
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Total balance',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),

                        if (appState.kpId == 0)
                          const Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Not Connected With Host',
                                    style: TextStyle(fontSize: 16, color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.green),
                              title: const Text('Deposit'),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  if (appState.kpId == 0) {
                                    // Show message if not connected to host
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please connect with a host first to deposit.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  } else {
                                    _showRechargeOptions(context); // Proceed if connected
                                  }
                                },
                                child: const Text('Recharge'),
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.emoji_events_outlined, color: Colors.blue),
                              title: const Text('Withdraw'),
                              subtitle: Text('${appState.balance < 0 ? 0 : appState.balance}'),  // Show 0 if wallet is negative
                              trailing: ElevatedButton(
                                onPressed: () {
                                  if (appState.kpId == 0) {
                                    // Show message if not connected to host
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please connect with a host first to withdraw.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  } else {
                                    _showWithdrawOptions(context); // Proceed if connected
                                  }
                                },
                                child: const Text('Withdraw'),
                              ),
                            ),

                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Quick actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.history, color: Colors.green), // Icon for Game History
                            title: const Text('Game History'),
                            subtitle: const Text('For all played game records'), // Subtitle for Game History
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16), // Trailing arrow
                            onTap: () {
                              // Navigate to Game History
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GameHistoryPage(),
                                ),
                              );
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.history, color: Colors.blue),
                            title: const Text('Transaction History'),
                            subtitle: const Text('For all balance debits & credits'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              // Handle transaction history action
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TransactionPage()),
                              );
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.history, color: Colors.grey),
                            title: Row(
                              children: [
                                const Text('Request History'),
                                if (appState.nullActionCount > 0)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 20.0),
                                    child: Icon(
                                      Icons.pending_actions,
                                      color: Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                if (appState.nullActionCount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      '${appState.nullActionCount}',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],),
                            subtitle: const Text('For all requests records'),  // Replace with actual KYC verification date from AppState
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              // Handle KYC verification action
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const KplogsPage()),
                              );

                            },
                          ),

                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (AppState().kpId != 0)
                    Card(
                      child: ExpansionTile(
                        title: const Text(
                          'Settings by Host',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onExpansionChanged: (isExpanded) async {
                          if (isExpanded) {
                            // Fetch user settings when the ExpansionTile is expanded
                            await AppState().fetchUserSettings();
                          }
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                _buildEditableField('Connection Status', 'allowed', AppState().allowed),
                                const Divider(),
                                _buildEditableField('Rate  (1 X ?)', 'rate', AppState().kpRate),
                                const Divider(),
                                if (AppState().kpCommission != 0 ) _buildEditableField('Commission %', 'commission', AppState().kpCommission),
                                if (AppState().kpCommission != 0) const Divider(),
                                if (AppState().debtLimit != 0) _buildEditableField('Loan Limit', 'debt_limit', AppState().debtLimit),
                                if (AppState().debtLimit != 0) const Divider(),
                                if (AppState().editMinutes != 0 && AppState().editMinutes != -1) _buildEditableField('Edit close', 'edit_minutes', AppState().editMinutes),
                                if (AppState().editMinutes != 0 && AppState().editMinutes != -1) const Divider(),
                                if (AppState().bigPlayLimit != -1) _buildEditableField('Limit after big play time', 'big_play_limit', AppState().bigPlayLimit),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )

                  ],
                );
              },
            ),
          ),
                ),
        ),
    );
  }


  Widget _buildEditableField(String title, String field, dynamic value) {
    String displayValue;

    // Customize the display based on the field and value
    if (field == 'edit_minutes') {
      if (value == -1) {
        displayValue = 'Disabled';
      } else if (value == 0) {
        displayValue = 'Till Close Time';
      } else {
        displayValue = '$value minutes';
      }
    } else if (field == 'debt_limit') {
      displayValue = '$value'; // Format loan limit with currency symbol
    } else if (field == 'big_play_limit') {
      if (value == -1) {
        displayValue = 'No Limit';
      } else if (value == 0) {
        displayValue = 'Disable Play';
      } else {
        displayValue = '$value';
      }
    } else if (field == 'allowed') {
      displayValue = value == true ? 'Connected' : value == false ? 'Blocked' : 'Pending'; // Format big play limit with currency symbol
    } else {
      displayValue = value != null ? value.toString() : 'Not Set';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(title),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                onPressed: () {
                  _showInfoDialog(field); // Show a dialog with field info
                },
              ),
            ],
          ),
          Row(
            children: [
              Text(displayValue),
            ],
          ),
        ],
      ),
    );
  }

  void _showRechargeOptions(BuildContext context) {
    TextEditingController rechargeController = TextEditingController();
    TextEditingController noteController = TextEditingController();

    String? errorMessage; // Local error message variable

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            // Reset the error message when the text changes
            void resetErrorMessage() {
              if (errorMessage != null) {
                setState(() {
                  errorMessage = null;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16.0,
                right: 16.0,
                top: 16.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recharge',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    const Text('Recharge Amount'),
                    TextField(
                      controller: rechargeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(7),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Enter amount',
                      ),
                      onChanged: (_) => resetErrorMessage(),  // Reset error on change
                    ),
                    const SizedBox(height: 20),
                    const Text('Note (Optional)'),
                    TextField(
                      controller: noteController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        hintText: 'Enter note',
                        border: OutlineInputBorder(),
                      ),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(100),
                      ],
                      onChanged: (_) => resetErrorMessage(),  // Reset error on change
                    ),
                    const SizedBox(height: 20),

                    // Display error message if present
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    ElevatedButton(
                      onPressed: () async {
                        int rechargeAmount = int.tryParse(rechargeController.text) ?? 0;
                        String playerNote = noteController.text;

                        if (rechargeAmount <= 0) {
                          setState(() {
                            errorMessage = 'Please enter a valid recharge amount greater than 0.';
                          });
                          return;
                        }

                        // final allowedResponse = await supabase
                        //     .from('khaiwals_players')
                        //     .select('allowed, balance')
                        //     .eq('id', AppState().kpId);
                        //
                        // if (allowedResponse.isEmpty) {
                        //   setState(() {
                        //     errorMessage = 'Player record not found.';
                        //   });
                        //   return;
                        // }
                        //
                        // final bool? allowed = allowedResponse[0]['allowed'];
                        // AppState().balance = allowedResponse[0]['balance'];
                        // AppState().notifyListeners();
                        //
                        // if (allowed == null) {
                        //   setState(() {
                        //     errorMessage = 'Connection status is pending with the host.';
                        //   });
                        //   return;
                        // } else if (allowed == false) {
                        //   setState(() {
                        //     errorMessage = 'You are not allowed to recharge.';
                        //   });
                        //   return;
                        // }

                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return const Center(child: CircularProgressIndicator());
                          },
                        );

                        try {
                          final results = await Future.wait([
                            // First query: `khaiwals_players` check
                            supabase
                                .from('khaiwals_players')
                                .select('allowed, balance')
                                .eq('id', AppState().kpId)
                                .maybeSingle(),

                            // Second query: Check if a recharge request is in progress
                            supabase
                                .from('kp_logs')
                                .select('recharge_amt')
                                .eq('kp_id', AppState().kpId)
                                .or('action.is.null')
                                .not('recharge_amt', 'is', 'null')
                                .limit(1)
                                .maybeSingle(),

                            // Third query: Check for unresolved disputes
                            supabase
                                .from('kp_logs')
                                .select('id')
                                .eq('kp_id', AppState().kpId)
                                .or('user_dispute.eq.true,khaiwal_dispute.eq.true')
                                .limit(1)
                                .maybeSingle(),
                          ]);

                          final khaiwalResponse = results[0];
                          final rechargeResponse = results[1];
                          final disputeResponse = results[2];

                          // Handle `khaiwals_players` check
                          if (khaiwalResponse == null) {
                            setState(() {
                              errorMessage = 'Player record not found.';
                            });
                            return;
                          }

                          final bool? allowed = khaiwalResponse['allowed'];
                          AppState().balance = khaiwalResponse['balance'];
                          AppState().notifyListeners();

                          if (allowed == null) {
                            setState(() {
                              errorMessage =
                              'Connection status is pending with the host.';
                            });
                            return;
                          } else if (allowed == false) {
                            setState(() {
                              errorMessage =
                              'You are not allowed to recharge.';
                            });
                            return;
                          }

                          // Handle recharge request in progress
                          if (rechargeResponse != null) {
                            setState(() {
                              errorMessage =
                              'A recharge request is already in progress.';
                            });
                            return;
                          }

                          // Handle unresolved disputes
                          if (disputeResponse != null) {
                            setState(() {
                              errorMessage =
                              'There is an unresolved dispute. Resolve it before proceeding.';
                            });
                            return;
                          }

                          setState(() {
                            errorMessage = null;  // Clear error if everything is valid
                          });

                          // Check for device mismatch
                          final isMismatch = await AppState().checkDeviceMismatch(context);
                          if (isMismatch) return; // Halt if there's a mismatch

                          final logResponse = await supabase
                              .from('kp_logs')
                              .insert({
                            'kp_id': AppState().kpId,
                            'recharge_amt': rechargeAmount,
                            'timestamp': AppState().currentTime.toString(),
                            if (playerNote.isNotEmpty) 'player_note': playerNote,
                          });

                          if (logResponse == null) {
                            AppState().updateNullActionCount();
                            Navigator.pop(context);  // Close the modal on success
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Recharge request sent successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            setState(() {
                              errorMessage = 'Error sending recharge request.';
                            });
                          }
                        } catch(e) {
                          setState(() {
                            errorMessage = 'An error occurred. Please try again.';
                          });
                        } finally {
                          // Close the loading dialog
                          Navigator.pop(context);
                        }
                      },
                      child: const Center(child: Text('Send Request')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }




  Future<void> _showWithdrawOptions(BuildContext context) async {
    if (AppState().balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient coins to withdraw'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      // await AppState().updateWallet();
      TextEditingController withdrawController = TextEditingController();
      TextEditingController noteController = TextEditingController();
      String? errorMessage;

      showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              void resetErrorMessage() {
                if (errorMessage != null) {
                  setState(() {
                    errorMessage = null;
                  });
                }
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Withdraw',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      const Text('Withdraw Amount'),
                      TextField(
                        controller: withdrawController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(7),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Enter amount',
                        ),
                        onChanged: (_) => resetErrorMessage(),
                      ),
                      const SizedBox(height: 20),
                      const Text('Note (Optional)'),
                      TextField(
                        controller: noteController,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          hintText: 'Enter note',
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(100),
                        ],
                        onChanged: (_) => resetErrorMessage(),
                      ),
                      const SizedBox(height: 20),

                      if (errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),

                      ElevatedButton(
                        onPressed: () async {
                          int withdrawAmount = int.tryParse(withdrawController.text) ?? 0;
                          String playerNote = noteController.text;
                          // int pendingWithdrawAmount = 0;

                          if (withdrawAmount <= 0) {
                            setState(() {
                              errorMessage = 'Please enter a valid amount greater than 0.';
                            });
                            return;
                          }

                          // Show loading dialog
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const Center(child: CircularProgressIndicator());
                            },
                          );

                          try {
                            final results = await Future.wait([
                              // First query: `khaiwals_players` check
                              supabase
                                  .from('khaiwals_players')
                                  .select('allowed, balance')
                                  .eq('id', AppState().kpId)
                                  .maybeSingle(),

                              // Second query: Check if a recharge request is in progress
                              supabase
                                  .from('kp_logs')
                                  .select('withdraw_amt')
                                  .eq('kp_id', AppState().kpId)
                                  .or('action.is.null')
                                  .not('withdraw_amt', 'is', 'null')
                                  .limit(1)
                                  .maybeSingle(),

                              // Third query: Check for unresolved disputes
                              supabase
                                  .from('kp_logs')
                                  .select('id')
                                  .eq('kp_id', AppState().kpId)
                                  .or('user_dispute.eq.true,khaiwal_dispute.eq.true')
                                  .limit(1)
                                  .maybeSingle(),
                            ]);

                            final khaiwalResponse = results[0];
                            final rechargeResponse = results[1];
                            final disputeResponse = results[2];

                            // Handle `khaiwals_players` check
                            if (khaiwalResponse == null) {
                              setState(() {
                                errorMessage = 'Player record not found.';
                              });
                              return;
                            }

                            final bool? allowed = khaiwalResponse['allowed'];
                            AppState().balance = khaiwalResponse['balance'];
                            AppState().notifyListeners();

                            if (allowed == null) {
                              setState(() {
                                errorMessage = 'Connection status is pending with the host.';
                              });
                              return;
                            } else if (allowed == false) {
                              setState(() {
                                errorMessage = 'You are not allowed to withdraw.';
                              });
                              return;
                            }

                            // Handle recharge request in progress
                            if (rechargeResponse != null) {
                              setState(() {
                                errorMessage = 'A withdraw request is already in progress.';
                              });
                              return;
                            }

                            // Handle unresolved disputes
                            if (disputeResponse != null) {
                              setState(() {
                                errorMessage = 'There is an unresolved dispute. Resolve it before proceeding.';
                              });
                              return;
                            }

                            // final allowedResponse = await supabase
                            //     .from('khaiwals_players')
                            //     .select('allowed, balance')
                            //     .eq('id', AppState().kpId);
                            //
                            // if (allowedResponse.isEmpty) {
                            //   setState(() {
                            //     errorMessage = 'Player record not found.';
                            //   });
                            //   return;
                            // } else {
                            //   AppState().balance = allowedResponse[0]['balance'];
                            //   AppState().notifyListeners();
                            // }
                            //
                            // final bool? allowed = allowedResponse[0]['allowed'];
                            // if (allowed == null) {
                            //   setState(() {
                            //     errorMessage = 'Approval pending to withdraw.';
                            //   });
                            //   return;
                            // } else if (allowed == false) {
                            //   setState(() {
                            //     errorMessage = 'You are not allowed to withdraw.';
                            //   });
                            //   return;
                            // }
                            //
                            // final pendingWithdrawalsResponse = await supabase
                            //     .from('kp_logs')
                            //     .select('withdraw_amt')
                            //     .eq('kp_id', AppState().kpId)
                            //     .or('action.is.null')
                            //     .not('withdraw_amt', 'is', 'null')
                            //     .limit(1);
                            //
                            // if (pendingWithdrawalsResponse.isNotEmpty) {
                            //   setState(() {
                            //     errorMessage = 'A withdraw request is already in progress.';
                            //   });
                            //   return;
                            // }
                            //
                            //
                            // // Check for existing disputes
                            // final disputeCheckResponse = await supabase
                            //     .from('kp_logs')
                            //     .select('id')
                            //     .eq('kp_id', AppState().kpId)
                            //     .or('user_dispute.eq.true,khaiwal_dispute.eq.true')
                            //     .limit(1)
                            //     .maybeSingle();
                            //
                            // if (disputeCheckResponse != null) {
                            //   setState(() {
                            //     errorMessage = 'There is unresolved dispute. Resolve it before proceeding.';
                            //   });
                            //   return; // Halt further execution
                            // }

                            setState(() {
                              errorMessage = null;  // Clear error if everything is valid
                            });

                            // Check for device mismatch
                            final isMismatch = await AppState().checkDeviceMismatch(context);
                            if (isMismatch) return; // Halt if there's a mismatch

                            final response = await supabase
                                .from('kp_logs')
                                .insert({
                              'kp_id': AppState().kpId,
                              'withdraw_amt': withdrawAmount,
                              'timestamp': AppState().currentTime.toIso8601String(),
                              if (playerNote.isNotEmpty) 'player_note': playerNote,
                            });

                            if (response == null) {
                              AppState().updateNullActionCount();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Withdraw request sent successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              setState(() {
                                errorMessage = 'Error sending withdraw request.';
                              });
                            }
                          } catch (e) {
                            setState(() {
                              errorMessage = 'An error occurred. Please try again.';
                            });
                          } finally {
                            // Close the loading dialog
                            Navigator.pop(context);
                          }
                        },
                        child: const Center(child: Text('Send Request')),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }


  void _showInfoDialog(String field) {
    String infoText;

    // Add detailed information for each field
    switch (field) {
      case 'rate':
        infoText = 'Rate refers to the multiplier for a win. For example, if the rate is 90, the winning payout will be 90 times the played amount. If a user wins on any lucky number from 00 to 99, the payout will be calculated as follows: Winning Payout = Played Amount * Rate. For example, if a user plays 100 and the rate is 90, and they win on a lucky number, their winning payout will be 100 * 90 = 9000.';
        break;
      case 'commission':
        infoText = 'Commission is a percentage of the total amount played in a game. It is deducted from the total amount played, regardless of whether the user wins or loses. For example, if the commission is 10%, the user will receive 10% of their total played, regardless of the outcome of the game.';
        break;
      case 'patti':
        infoText = 'Patti refers to the card value in the game, used for specific game calculations.';
        break;
      case 'debt_limit':
        infoText = 'Loan Limit sets the maximum amount a user can borrow or play in advance. If the Loan Limit is not set or is 0 then the user must have a positive wallet balance to play games, If the Loan Limit is set to a value (e.g., -100), the user can play games until their wallet balance reaches the Loan Limit. Negative wallet balances represent advance or loans.';
        break;
      case 'edit_minutes':
        infoText = 'Close Edit specifies the time window when user no longer able to edit their played games in the last minutes (set by host) before game ends.';
        break;
      case 'big_play_limit':
        infoText = 'Big Play Limit sets the maximum amount a user can play on a single number during the last few minutes of a game. For example, if the Big Play Limit is set to 200, the user cannot play more than 200 on any single number when the game is nearing its closing time.';
        break;
      case 'allowed':
        infoText = 'Connection Status defines whether the user is currently permitted to participate in games or not.';
        break;
      default:
        infoText = 'No information available for this field.';
    }

    // Show a dialog with the information
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Field Information'),
          content: Text(infoText),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }


}
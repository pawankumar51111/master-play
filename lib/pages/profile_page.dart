import 'package:flutter/material.dart';
import 'package:masterplay/main.dart';
import 'package:masterplay/models/app_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  Map<String, dynamic> profileSettings = {};
  // Map to store the information for each field
  final Map<String, String> fieldInfo = {
    'full_name': 'Enter the user\'s full name. This will be displayed as the user\'s name.',
    'username': 'Enter the username of the user. This is used for login and identification.',
  };

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
    final response = await supabase
        .from('profiles')
        .select('full_name, username, avatar_url, phone, whatsapp')
        .eq('id', AppState().currentUserProfileId)
        .maybeSingle();

    if (response != null) {
      setState(() {
        profileSettings = {
          'full_name': response['full_name'] ?? '',
          'username': response['username'] ?? '',
          'avatar_url': response['avatar_url'],
          'phone': response['phone'],
          'whatsapp': response['whatsapp'],
          // 'rate': response['rate'] ?? 0,
          // 'refresh_diff': response['refresh_diff'] ?? 0,
          // 'refund_days': response['refund_days'] ?? 0,
        };
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to fetch user data.")));
    }
    setState(() {
      loading = false;
    });
  }
  // Method to update user data in Supabase
  Future<void> _updateUserSetting(String field, dynamic value) async {
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

    // Check for device mismatch
    final isMismatch = await AppState().checkDeviceMismatch(context);
    if (isMismatch) return; // Halt if there's a mismatch

    if (field == 'username') {
      // Handle the cooldown logic for username changes
      final response = await supabase
          .from('profiles')
          .select('last_username_change')
          .eq('id', AppState().currentUserProfileId)
          .maybeSingle();

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch cooldown information.")),
        );
        Navigator.of(context).pop(); // Dismiss loading dialog
        return;
      }
      String? lastChange = response['last_username_change'];
      final currentTime = AppState().currentTime;

      // Cooldown validation
      if (lastChange != null) {
        final lastChangeTime = DateTime.parse(lastChange);
        final differenceInDays = currentTime.difference(lastChangeTime).inDays;

        if (differenceInDays <= 30) {
          final daysLeft = 30 - differenceInDays; // Calculate days left for cooldown
          Navigator.of(context).pop(); // Dismiss loading dialog
          _showInfoDialog('Username update', 'Cool down period of 30 days is not over yet. Please wait $daysLeft day(s) to update your username again.');
          return;
        }
      }
      // Update username
      await _updateUsername(value, currentTime);
      AppState().notifyListeners();
      Navigator.of(context).pop(); // Dismiss loading dialog
      return;
    }
    final updateResponse = await supabase
        .from('profiles')
        .update({field: value, 'updated_at': AppState().currentTime.toIso8601String()})
        .eq('id', AppState().currentUserProfileId);

    if (updateResponse == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully!")));
      setState(() {
        profileSettings[field] = value;
      });
      if (field == 'full_name') {
        AppState().currentUserFullName = value;
      }
      AppState().notifyListeners();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update failed! Please try again.")));
    }
    Navigator.of(context).pop(); // Dismiss loading dialog
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
      ),
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Display
              Center(
                child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: (profileSettings['avatar_url'] != null && profileSettings['avatar_url'].isNotEmpty)
                            ? NetworkImage(profileSettings['avatar_url'])
                            : null,
                        backgroundColor: (profileSettings['avatar_url'] == null || profileSettings['avatar_url'].isEmpty)
                            ? (profileSettings['full_name'] != null && profileSettings['full_name']!.isNotEmpty)
                            ? _isNumeric(profileSettings['full_name']!)
                            ? Colors.blueGrey // Background for numeric-only names
                            : getColorForLetter(getFirstValidLetter(profileSettings['full_name'])?.toUpperCase() ?? '')
                            : Colors.grey // For null or empty names
                            : Colors.transparent,
                        child: (profileSettings['avatar_url'] == null || profileSettings['avatar_url'].isEmpty)
                            ? (getFirstValidLetter(profileSettings['full_name']) != null
                            ? Text(
                          getFirstValidLetter(profileSettings['full_name'])!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.normal,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        ))
                            : null,
                      ),
                      // Mini Button: Delete or Edit
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: () async {
                            if (profileSettings['avatar_url'] != null &&
                                profileSettings['avatar_url']!.isNotEmpty) {
                              // Delete Confirmation
                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Profile Picture'),
                                  content: const Text(
                                      'Are you sure you want to delete your profile picture?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldDelete == true) {
                                // Set avatar_url to null in Supabase
                                await _updateAvatarUrl(null);
                              }
                            } else {
                              // Edit Avatar
                              _pickNewAvatar(); // Add your image picker logic here
                            }
                          },
                          child: CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.redAccent,
                            child: Icon(
                              profileSettings['avatar_url'] != null &&
                                  profileSettings['avatar_url']!.isNotEmpty
                                  ? Icons.delete // Delete button
                                  : Icons.edit, // Edit button
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ]
                ),
              ),
              const SizedBox(height: 20),

              // Profile Information Section
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          _buildEditableField(context, 'Full Name', 'full_name', profileSettings['full_name'], isText: true),
                          const Divider(),
                          _buildEditableField(context, 'Username', 'username', profileSettings['username'], isText: true),

                          // const SizedBox(height: 20),
                          // const Text(
                          //   'Contact Information',
                          //   style: TextStyle(
                          //     fontSize: 18,
                          //     fontWeight: FontWeight.bold,
                          //   ),
                          // ),
                          // const SizedBox(height: 5),
                          // // const Divider(),
                          // _buildEditableField(context, 'Phone', 'phone', profileSettings['phone'], isText: true),
                          // const Divider(),
                          // // _buildDurationEditableField(context, 'Next Day Game Delay Hours', 'refresh_diff', profileSettings['refresh_diff'] ?? 0),
                          // // const Divider(),
                          // _buildEditableField(context, 'Message', 'whatsapp', profileSettings['whatsapp'], isText: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateAvatarUrl(String? newUrl) async {
    try {
      final response = await supabase
          .from('profiles')
          .update({'avatar_url': newUrl})
          .eq('id', AppState().currentUserProfileId);

      if (response == null) {
        setState(() {
          profileSettings['avatar_url'] = newUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newUrl == null ? "Profile picture deleted!" : "Profile picture updated!")),
        );
      } else {
        throw Exception("Update failed");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update profile picture! Please try again.")),
      );
    }
  }

  void _pickNewAvatar() async {
    final avatarUrl = AppState().user?.userMetadata?['avatar_url'];
    // Confirmation to use default image
    if (avatarUrl != null) {
      final useDefaultImage = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Use Default Image'),
          content: const Text(
              'Your profile picture is empty. Do you want to use the default image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Use Default'),
            ),
          ],
        ),
      );

      if (useDefaultImage == true) {
        await _updateAvatarUrl(avatarUrl);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No Default Image available to update")),
      );
    }

  }


  Future<void> _updateUsername(String username, DateTime currentTime) async {
    try{
      // Update the username
      final updateResponse = await supabase
          .from('profiles')
          .update({
        'username': username.trim(),
      }).eq('id', AppState().currentUserProfileId);

      if (updateResponse == null) {
        await supabase
            .from('profiles')
            .update({
          'last_username_change': currentTime.toIso8601String(),
        }).eq('id', AppState().currentUserProfileId);

        setState(() {
          profileSettings['username'] = username;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username updated successfully!")),
        );
      }
    } catch (e){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username is already taken by someone, Choose another username")),
      );
    }
  }

  // Widget _buildDurationEditableField(
  //     BuildContext context,
  //     String title,
  //     String field,
  //     int value,
  //     ) {
  //   // Convert stored negative minutes into positive hours and minutes for display
  //   String displayValue = value != null
  //       ? '${-value ~/ 60}h ${(-value % 60)}m'
  //       : 'Not Set';
  //
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 8.0),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //       children: [
  //         Row(
  //           children: [
  //             Text(title),
  //             IconButton(
  //               icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
  //               onPressed: () {
  //                 _showInfoDialog('Delay', 'If your any games close in next day then set dalay hours till your game ends in next day.'); // Show a dialog with field info
  //               },
  //             ),
  //           ],
  //         ),
  //         Row(
  //           children: [
  //             Text(displayValue),
  //             IconButton(
  //               icon: const Icon(Icons.edit),
  //               onPressed: () async {
  //                 int? newValue = await _showHourPickerDialog(context, field, value, -720, 0);
  //                 if (newValue != null) {
  //                   await _updateUserSetting(field, newValue);
  //                 }
  //               },
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Future<dynamic> _showHourPickerDialog(
  //     BuildContext context,
  //     String field,
  //     int currentValue,
  //     int min,
  //     int max,
  //     ) async {
  //   int pickerValue = currentValue;
  //
  //   // Function to format the picker value into hours and minutes
  //   String formatTime(int value) {
  //     int hours = value ~/ 60; // Get hours
  //     int minutes = value % 60; // Get minutes
  //     return '${hours}h ${minutes}m';
  //   }
  //
  //   return showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: const Text('Edit Delay'),
  //         content: StatefulBuilder(
  //           builder: (BuildContext context, StateSetter setState) {
  //             return Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 NumberPicker(
  //                   value: pickerValue,
  //                   minValue: min,
  //                   maxValue: max,
  //                   step: 30, // Step size of 30 minutes (half-hour intervals)
  //                   axis: Axis.vertical,
  //                   onChanged: (value) {
  //                     setState(() {
  //                       pickerValue = value;
  //                     });
  //                   },
  //                   decoration: BoxDecoration(
  //                     borderRadius: BorderRadius.circular(16),
  //                     border: Border.all(color: Colors.blue, width: 2),
  //                   ),
  //                 ),
  //                 // Display the selected time in the formatted 'Xh Ym' format
  //                 Text('Selected Delay: ${formatTime(pickerValue.abs())}'),
  //               ],
  //             );
  //           },
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.pop(context); // Close dialog without saving
  //             },
  //             child: const Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               Navigator.pop(context, pickerValue); // Return the selected value
  //             },
  //             child: const Text('Save'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }


  Widget _buildEditableField(
      BuildContext context,
      String title,
      String field,
      dynamic value, {
        bool isText = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // For better alignment if text wraps
        children: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
            onPressed: () {
              String infoText = fieldInfo[field] ?? 'No information available.';
              _showInfoDialog(title, infoText);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  value != null ? value.toString() : 'Not Set',
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis, // Truncate long text
                  maxLines: 1, // Optional to limit lines if needed
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              if (field == 'username') {
                final shouldProceed = await _showUsernameConfirmationDialog(context);
                if (!shouldProceed) return;
              }

              dynamic newValue;

              if (isText) {
                newValue = await _showEditDialog(context, field, value, TextInputType.text);
              }

              // Handle phone and message fields separately
              // if (field == 'phone' || field == 'message') {
              //   newValue = await _showNumberEditDialog(context, field, value?.toString() ?? '');
              // }
              // // Existing logic for text fields
              // else if (isText) {
              //   newValue = await _showEditDialog(context, field, value, TextInputType.text);
              // }
              // // Existing logic for numeric pickers
              // else if (min != null && max != null) {
              //   newValue = await _showNumberPickerDialog(context, field, value, min, max);
              // }

              // Update user setting only if a new value was provided
              if (newValue != null) {
                if (newValue == '') {
                  await _updateUserSetting(field, null);
                } else {
                  await _updateUserSetting(field, newValue);
                }
              }
            },
          )
        ],
      ),
    );
  }

  Future<bool> _showUsernameConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Username Change Confirmation'),
          content: const Text(
            'You can change your username only once every 30 days. Are you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Cancel
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // Proceed
              },
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    ) ??
        false; // Default to false if dialog is dismissed
  }


  // Future<dynamic> _showNumberPickerDialog(BuildContext context, String field, int currentValue, int min, int max) async {
  //   int pickerValue = currentValue;
  //
  //   return showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: Text('Edit ${field == 'rate' ? 'Rate' : 'Refund Days'}'),
  //         content: StatefulBuilder(
  //           builder: (BuildContext context, StateSetter setState) {
  //             return Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 NumberPicker(
  //                   value: pickerValue,
  //                   minValue: min,
  //                   maxValue: max,
  //                   step: 1,
  //                   axis: Axis.vertical,
  //                   onChanged: (value) {
  //                     setState(() {
  //                       pickerValue = value;
  //                     });
  //                   },
  //                   decoration: BoxDecoration(
  //                     borderRadius: BorderRadius.circular(16),
  //                     border: Border.all(color: Colors.blue, width: 2),
  //                   ),
  //                 ),
  //                 Text('Selected Value: $pickerValue'),
  //               ],
  //             );
  //           },
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.pop(context); // Close without saving
  //             },
  //             child: const Text('Cancel'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               Navigator.pop(context, pickerValue); // Return the selected value
  //             },
  //             child: const Text('Save'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  Future<dynamic> _showEditDialog(BuildContext context, String field, String currentValue, TextInputType inputType) async {
    TextEditingController controller = TextEditingController(text: currentValue);
    String? errorText;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Use StatefulBuilder to manage the state of error text dynamically
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit ${field == 'username' ? 'Username' : 'Name'}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: inputType,
                    maxLength: 35,
                    decoration: InputDecoration(
                      hintText: 'Enter $field',
                      errorText: errorText, // Show validation error
                    ),
                    onChanged: (value) {
                      // Clear error text as user types
                      setState(() {
                        errorText = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (field == 'username') // Show guidelines only for username
                    const Text(
                      "Guidelines for Username:\n"
                          "- Must be at least 3 characters long.\n"
                          "- Must not contain spaces.\n"
                          "- Must be in lowercase.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close without saving
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    String enteredText = controller.text.trim();

                    if (field == 'username') {
                      // Validation for username
                      if (enteredText.length < 3) {
                        setState(() {
                          errorText = 'Must be at least 3 characters long.';
                        });
                        return;
                      }
                      if (enteredText.contains(' ')) {
                        setState(() {
                          errorText = 'Username cannot contain spaces.';
                        });
                        return;
                      }
                      if (enteredText != enteredText.toLowerCase()) {
                        setState(() {
                          errorText = 'Username must be in lowercase.';
                        });
                        return;
                      }
                    }

                    Navigator.pop(context, enteredText); // Return entered text if valid
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Method to show info dialog
  void _showInfoDialog(String field, String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$field Info'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Function to get background color based on the first letter
  Color getColorForLetter(String letter) {
    if (letter.isEmpty) return Colors.grey; // Default color if letter is empty

    switch (letter.toUpperCase()) {
      case 'A':
      case 'B':
      case 'C':
        return Colors.blue.shade400;
      case 'D':
      case 'E':
      case 'F':
        return Colors.orange.shade400;
      case 'G':
      case 'H':
      case 'I':
        return Colors.green.shade400;
      case 'J':
      case 'K':
      case 'L':
        return Colors.brown.shade300;
      case 'M':
      case 'N':
      case 'O':
        return Colors.teal.shade300;
      case 'P':
      case 'Q':
      case 'R':
        return Colors.red.shade400;
      case 'S':
      case 'T':
      case 'U':
        return Colors.yellow.shade700;
      case 'V':
      case 'W':
      case 'X':
        return Colors.purple.shade300;
      case 'Y':
      case 'Z':
        return Colors.pink.shade300; // 'Rose' color
      default:
        return Colors.blueGrey; // Default color for unexpected input
    }
  }

  // Helper function to get the first valid letter
  String? getFirstValidLetter(String? input) {
    if (input == null || input.isEmpty) return null;

    for (int i = 0; i < input.length; i++) {
      if (RegExp(r'[A-Za-z]').hasMatch(input[i])) {
        return input[i].toUpperCase();
      }
    }
    return null; // Return null if no valid letter is found
  }

  bool _isNumeric(String input) {
    final numericRegex = RegExp(r'^[0-9]+$');
    return numericRegex.hasMatch(input);
  }



  @override
  void dispose() {

    super.dispose();
  }
}

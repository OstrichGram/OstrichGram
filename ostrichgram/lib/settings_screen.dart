import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'og_hive_interface.dart';

// Class for config settings screen

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedWallpaper = 'BLUE';
  String _selectedTimezone = 'GMT+0';
  bool _selectedVerifySignatures = true;
  int _selectedEventsPerQuery = 1000;

  Future<void> _initData() async {
    Map<String, dynamic> configSettings = await OG_HiveInterface.getData_ConfigSettings();
    if (configSettings.containsKey('wallpaper')) {
      _selectedWallpaper = configSettings['wallpaper'];
    }
    if (configSettings.containsKey('timezone')) {
      _selectedTimezone = configSettings['timezone'];
    }
    if (configSettings.containsKey('verify_signatures')) {
      _selectedVerifySignatures = configSettings['verify_signatures'];
    }
    if (configSettings.containsKey('events_per_query')) {
      _selectedEventsPerQuery = configSettings['events_per_query'];
    }
  }

  @override
  void initState() {
    super.initState();
    _initData().then((_) {
      setState(() {
        // Any additional setup that needs to happen after _initData()
      });
    });
  }

  Future<void> _updateDb() async {
    // Update the database with the selected wallpaper, timezone, verify signatures, and events per query
    await OG_HiveInterface.addData_UpdateConfigSettings(
      wallpaper: _selectedWallpaper,
      timezone: _selectedTimezone,
      verify_signatures: _selectedVerifySignatures,
      events_per_query: _selectedEventsPerQuery,
    );
  }

  @override
  Widget build(BuildContext context) {
    // (existing code)

    List<String> wallpapers = [
      'BLUE',
      'DEEP-NIGHT',
      'DARK-GALAXY',
      'PURPLE-SKY',
      'OCEAN',
      'SWIRLS',
      'WOOD'
    ];

    List<String> timezones = List.generate(24, (i) => 'GMT${i >= 12 ? '-' : '+'}${i % 12}');

    double containerWidth = MediaQuery.of(context).size.width * 0.6;
    containerWidth = containerWidth > 500 ? 500 : containerWidth;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF9D58FF),
        title: Text('Settings'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.popUntil(context, ModalRoute.withName('/'));
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Configuration Settings: \n (Restart app after changing)',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Container(
                width: containerWidth,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text('Wallpaper'),
                      trailing: DropdownButton<String>(
                        dropdownColor: Colors.white,
                        value: _selectedWallpaper,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedWallpaper = newValue!;
                            _updateDb();
                          });
                        },
                        items: wallpapers.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                    ListTile(
                      title: Text('Timezone'),
                      trailing: DropdownButton<String>(
                        dropdownColor: Colors.white,
                        value: _selectedTimezone,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedTimezone = newValue!;
                            _updateDb();
                          });
                        },
                        items: timezones.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                    ListTile(
                      title: Text('Verify Signatures'),
                      trailing: Switch(
                        value: _selectedVerifySignatures,
                        onChanged: (bool newValue) {
                          setState(() {
                            _selectedVerifySignatures = newValue;
                            _updateDb();
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.popUntil(context, ModalRoute.withName('/'));
                      },
                      child: Text('Return to Main Screen'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
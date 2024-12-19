import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'window_dialog_alias.dart';
import 'og_hive_interface.dart';
import 'package:flutter/services.dart';
import 'nostr_core.dart';

class AliasScreen extends StatefulWidget {
  @override
  _AliasScreenState createState() => _AliasScreenState();
}

/*
This class implements the Alias Screen where the user can control his ID and
do things like create new ID, delete, etc.  It is straightforward UI widgets
with calls to DB functions to implement the actions.
 */

class _AliasScreenState extends State<AliasScreen> {
  String? selectedAlias;
  List<Map<String, String>> aliasList = [];
  List<String> aliasNames = [];
  Map<String, String> selectedAliasMap = {};

  Future<void> refreshAliasDropDownfromDb() async {
    List<dynamic> tempList = await OG_HiveInterface.getListofAliases();
    setState(() {
      aliasList =
          tempList.map<Map<String, String>>((map) => Map<String, String>.from(
              map)).toList();
    });

    Map<String, String> preferredAliasMap = await OG_HiveInterface
        .getData_Chosen_Alias_Map();

    setState(() {
      if (preferredAliasMap.isNotEmpty) {
        selectedAliasMap = preferredAliasMap;
      } else if (aliasList.isNotEmpty) {
        selectedAliasMap = aliasList.first;
      } else {
        selectedAliasMap = {};
      }

      selectedAlias = selectedAliasMap['alias'];

      aliasNames =
          aliasList.map<String>((aliasInfo) => aliasInfo['alias'] ?? '')
              .toList();

      // If the selectedAlias is not in aliasNames, update it to the first item or null if the list is empty
      if (!aliasNames.contains(selectedAlias)) {
        selectedAlias = aliasNames.isNotEmpty ? aliasNames.first : null;
      }
    });
  }



  Future<void> _deleteUser(BuildContext context, String aliasName) async {
    bool? confirmedDeletion = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the user $aliasName? This cannot be undone!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('No'),
            ),
          ],
        );
      },
    );

    if (confirmedDeletion == true) {
      // Call your DB function to delete the user with the alias name here
      OG_HiveInterface.deleteAliasbyName(aliasName);
      refreshAliasDropDownfromDb();

    }
  }


  Future<void> _copyPubkeyToClipboard(String alias) async {

    String pubkey = await OG_HiveInterface.getData_PubkeyFromAlias(alias);

    try {
      pubkey = (nostr_core.hexToBech32(pubkey, "npub"));
    } catch (e) {
      print(e);
    }

    await Clipboard.setData(ClipboardData(text: pubkey));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pubkey copied to clipboard.'),

        duration: Duration(seconds: 5),
      ),
    );
  }


  Future<void> _copyPrivkeyToClipboard(String alias) async {

    String privkey = await OG_HiveInterface.getData_PrivkeyFromAlias(alias);
    await Clipboard.setData(ClipboardData(text: privkey));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Private Key copied to clipboard. DO NOT SHARE THIS WITH ANYONE!'),
        duration: Duration(seconds: 10),
      ),
    );
  }

  Future<void> _initData() async {
    await refreshAliasDropDownfromDb();
    if (aliasList.isNotEmpty) {
      setState(() {
        selectedAlias = selectedAliasMap['alias'] ?? '';

        aliasNames =
            aliasList.map<String>((aliasInfo) => aliasInfo['alias'] ?? '')
                .toList();
      });
    }
  }


  @override
  void initState() {
    super.initState();
    _initData().then((_) {
      // Any additional setup that needs to happen after _initData()

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage IDs'),
        backgroundColor: Color(0xFF9D58FF),
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
              'Here you can manage your IDs. \n Nicknames here are not shared on the Nostr network.\n',
              style: TextStyle(fontSize: 24),
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
                    offset: Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "Current ID set to: ",
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 10),
                  Container(
                    width: 700,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: EdgeInsets.only(left: 10.0, right: 10.0),
                        width: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: DropdownButton(
                          items: aliasNames.map((aliasName) {
                            return DropdownMenuItem(
                              value: aliasName,
                              child: Text(aliasName),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedAlias = newValue;
                              OG_HiveInterface.updateOrInsert_Chosen_Alias(selectedAlias);
                            });
                          },
                          value: aliasNames.contains(selectedAlias) ? selectedAlias : null,
                          underline: SizedBox(),
                          icon: Icon(Icons.arrow_drop_down),
                          iconSize: 24,
                          iconEnabledColor: Colors.grey,
                          isExpanded: true,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Here are some actions you can take:',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return WindowDialog(
                            parentContext: context,
                            onAliasAdded: () async {
                              await refreshAliasDropDownfromDb();
                            },
                          );
                        },
                      );
                    },
                    child: Text('Create a new Alias (ID)'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(300, 36),
                      backgroundColor: Color(0xFF9D58FF),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Copy the selected alias key:',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _copyPubkeyToClipboard('$selectedAlias');
                    },
                    child: Text('Copy Pubkey to Clipboard'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(300, 36),
                      backgroundColor: Color(0xFF9D58FF),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Export a private key for use in another nostr client',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _copyPrivkeyToClipboard('$selectedAlias');
                    },
                    child: Text('Copy Private Key to Clipboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // Set the background color to red
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Delete the selected user (BE CAREFUL!)',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _deleteUser(context, selectedAlias ?? '');
                      // Add your desired functionality here
                    },
                    child: Text('Delete this User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // Set the background color to red
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.popUntil(context, ModalRoute.withName('/'));
              },
              child: Text('Return to Main Screen'),
            ),
          ],
        ),
      ),
    );
  }
}


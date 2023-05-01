import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math';
import 'bip340.dart';
import 'og_hive_interface.dart';

class WindowDialog extends StatefulWidget {
  final Function onAliasAdded;
  final BuildContext parentContext;

  WindowDialog({required this.onAliasAdded, required this.parentContext, Key? key}) : super(key: key);

  @override
  _WindowDialogState createState() => _WindowDialogState();
}


class _WindowDialogState extends State<WindowDialog> {
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<
      ScaffoldMessengerState>();

  static Uint8List generatePrivateKey() {
    final random = Random.secure();
    final privateKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      privateKey[i] = random.nextInt(256);
    }
    return privateKey;
  }


  static Uint8List hexStringToUint8List(String hex) {
    if (hex.length % 2 != 0) {
      hex = '0' + hex;
    }
    return Uint8List.fromList(List<int>.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }

  static String toHexString(Uint8List data) {
    return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }

  Future<bool> CreateNewAlias(String alias, String privkey, BuildContext parentContext) async {
    if (privkey == "") {
      // Generate new keypair.
      Uint8List new_privkey = generatePrivateKey();
      String new_privkey_string = toHexString(new_privkey);
      Uint8List new_pubkey = bip340.pubkey_gen(new_privkey);
      String new_pubkey_string = toHexString(new_pubkey);

      try {
        await OG_HiveInterface.addData_Aliases(alias, new_privkey_string, new_pubkey_string);
      } catch (e) {
        // handle the exception that was thrown
        // Show the error message using a SnackBar
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('$e'),
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }
      // Do anything needed after the DB entry for new user with new private key.
      // Update the dropdown on alias screen so we have new alias visible immediately.
      widget.onAliasAdded();
      return true;
    }
    if (privkey != "") {
      // User entered a private key.  Let's verify it.

      privkey =privkey.trim();
      bool validHexFormat = true;
      RegExp regExp = new RegExp(r'^[0-9A-Fa-f]+$');

      if (!regExp.hasMatch(privkey)) {
        validHexFormat = false;
      }

      if (privkey.length != 64) {
        validHexFormat = false;
      }

      if (!validHexFormat) {

        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Private Keys must be 64 hexadecimal characters.'),
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }

      Uint8List privkey_bytes = hexStringToUint8List(privkey);

      Uint8List new_pubkey = new Uint8List(0);
      try {
        new_pubkey = bip340.pubkey_gen(privkey_bytes);
      } catch (e) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('$e'),
            duration: Duration(seconds: 5),
          ),
        );
      }



      String new_pubkey_string = toHexString(new_pubkey);

      // All good to go.. insert into DB for imported key.

      try {
        await OG_HiveInterface.addData_Aliases(alias, privkey, new_pubkey_string);

      } catch (e) {
        // handle the exception that was thrown
        // Show the error message using a SnackBar
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('$e'),
            duration: Duration(seconds: 5),
          ),
        );

        return false;
      }
      // Callback to refresh alias screen after alias with imported key is added.
      widget.onAliasAdded();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the widget tree.
    _line1Controller.dispose();
    _line2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create New ID'),
      content: Container(
        width: 200,
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _line1Controller,
              decoration: InputDecoration(
                labelText: 'Alias (your name):',
                hintText: 'Enter some text',
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _line2Controller,
              decoration: InputDecoration(
                labelText: 'Private Key (leave blank for new user)',
                hintText: 'Enter some text',
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Color(0xFF9D58FF)),
                  ),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () async {
                    String line2Value = _line2Controller.text;
                    String line1Value = _line1Controller.text;
                    bool aliasCreated = await CreateNewAlias(line1Value, line2Value, context);

                    if (aliasCreated) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('OK'),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Color(0xFF9D58FF)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }



} //end class



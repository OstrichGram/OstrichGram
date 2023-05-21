// Some global configurations.  Only minimally used so far.

class GlobalConfig {
  // Private constructor
  GlobalConfig._();

  // Private static variable to hold the instance
  static GlobalConfig? _instance = GlobalConfig._internal();

  // Public factory constructor
  factory GlobalConfig() {
    return _instance!;
  }


  GlobalConfig._internal();

  // number of limit items specified in the nostr filter.
  int _message_limit = 1000;
  int _max_group_message_chars=3000;
  int _max_number_relays_fatgroup_create = 10;

  // getters
  int get max_group_message_chars => _max_group_message_chars;
  int get message_limit => _message_limit;
  int get max_number_relays_fatgroup_create =>_max_number_relays_fatgroup_create;

}


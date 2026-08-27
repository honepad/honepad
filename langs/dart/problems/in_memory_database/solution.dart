class FieldVal {
  FieldVal(this.value, this.expiry);

  final String value;
  final int? expiry;
}

class BackupField {
  BackupField(this.value, this.remaining);

  final String value;
  final int? remaining;
}

class InMemoryDatabase {
  final Map<String, Map<String, FieldVal>> database = {};
  final List<int> backupTimestamps = [];
  final List<Map<String, Map<String, BackupField>>> backupStates = [];

  String _setInternal(String key, String field, String value, int? expiry) {
    database.putIfAbsent(key, () => {})[field] = FieldVal(value, expiry);
    return '';
  }

  bool _isAlive(String key, String field, int timestamp) {
    final fields = database[key];
    if (fields == null || !fields.containsKey(field)) {
      return false;
    }
    final expiry = fields[field]!.expiry;
    return expiry == null || timestamp < expiry;
  }

  String set(String key, String field, String value) {
    return _setInternal(key, field, value, null);
  }

  String get(String key, String field) {
    final fields = database[key];
    if (fields == null || !fields.containsKey(field)) {
      return '';
    }
    return fields[field]!.value;
  }

  String delete(String key, String field) {
    final fields = database[key];
    if (fields == null || !fields.containsKey(field)) {
      return 'false';
    }
    fields.remove(field);
    return 'true';
  }

  String _formatFields(Map<String, FieldVal> fields, List<String> names) {
    names.sort();
    return names.map((field) => '$field(${fields[field]!.value})').join(', ');
  }

  String scan(String key) {
    final fields = database[key];
    if (fields == null) {
      return '';
    }
    return _formatFields(fields, fields.keys.toList());
  }

  String scanByPrefix(String key, String prefix) {
    final fields = database[key];
    if (fields == null) {
      return '';
    }
    final names = [
      for (final field in fields.keys)
        if (field.startsWith(prefix)) field,
    ];
    return _formatFields(fields, names);
  }

  String setAt(String key, String field, String value, int timestamp) {
    return _setInternal(key, field, value, null);
  }

  String setAtWithTtl(
    String key,
    String field,
    String value,
    int timestamp,
    int ttl,
  ) {
    return _setInternal(key, field, value, timestamp + ttl);
  }

  String deleteAt(String key, String field, int timestamp) {
    if (!_isAlive(key, field, timestamp)) {
      return 'false';
    }
    database[key]!.remove(field);
    return 'true';
  }

  String getAt(String key, String field, int timestamp) {
    if (!_isAlive(key, field, timestamp)) {
      return '';
    }
    return database[key]![field]!.value;
  }

  String scanAt(String key, int timestamp) {
    final fields = database[key];
    if (fields == null) {
      return '';
    }
    final names = [
      for (final field in fields.keys)
        if (_isAlive(key, field, timestamp)) field,
    ];
    return _formatFields(fields, names);
  }

  String scanByPrefixAt(String key, String prefix, int timestamp) {
    final fields = database[key];
    if (fields == null) {
      return '';
    }
    final names = [
      for (final field in fields.keys)
        if (field.startsWith(prefix) && _isAlive(key, field, timestamp)) field,
    ];
    return _formatFields(fields, names);
  }

  String backup(int timestamp) {
    final state = <String, Map<String, BackupField>>{};
    database.forEach((key, fields) {
      fields.forEach((field, pair) {
        if (_isAlive(key, field, timestamp)) {
          final remaining =
              pair.expiry == null ? null : pair.expiry! - timestamp;
          state.putIfAbsent(key, () => {})[field] =
              BackupField(pair.value, remaining);
        }
      });
    });
    backupTimestamps.add(timestamp);
    backupStates.add(state);
    return '${state.length}';
  }

  String restore(int timestamp, int timestampToRestore) {
    var idx = -1;
    for (var i = 0; i < backupTimestamps.length; i++) {
      if (backupTimestamps[i] <= timestampToRestore) {
        idx = i;
      }
    }
    final backup = backupStates[idx];
    database.clear();
    backup.forEach((key, fields) {
      fields.forEach((field, pair) {
        final expiry =
            pair.remaining == null ? null : timestamp + pair.remaining!;
        _setInternal(key, field, pair.value, expiry);
      });
    });
    return '';
  }
}

class StoredFile {
  StoredFile(this.name, this.size, this.owner);

  final String name;
  final int size;
  String owner;
}

class Simulation {
  Simulation() {
    capacity['admin'] = null;
  }

  final Map<String, StoredFile> files = {};
  final Map<String, int?> capacity = {};
  final Map<String, Map<String, int>> backups = {};

  int _used(String userId) {
    var sum = 0;
    for (final item in files.values) {
      if (item.owner == userId) {
        sum += item.size;
      }
    }
    return sum;
  }

  int? _remaining(String userId) {
    if (!capacity.containsKey(userId)) {
      return null;
    }
    final cap = capacity[userId];
    if (cap == null) {
      return null;
    }
    return cap - _used(userId);
  }

  String addFile(String name, int size) {
    if (files.containsKey(name)) {
      return 'false';
    }
    files[name] = StoredFile(name, size, 'admin');
    return 'true';
  }

  String getFileSize(String name) {
    final item = files[name];
    return item == null ? '' : '${item.size}';
  }

  String deleteFile(String name) {
    final item = files.remove(name);
    return item == null ? '' : '${item.size}';
  }

  String getNLargest(String prefix, int n) {
    final matched = [
      for (final item in files.values)
        if (item.name.startsWith(prefix)) item,
    ];
    matched.sort((a, b) {
      final d = b.size.compareTo(a.size);
      return d != 0 ? d : a.name.compareTo(b.name);
    });
    final limit = n < matched.length ? n : matched.length;
    return matched
        .sublist(0, limit)
        .map((item) => '${item.name}(${item.size})')
        .join(', ');
  }

  String addUser(String userId, int cap) {
    if (capacity.containsKey(userId)) {
      return 'false';
    }
    capacity[userId] = cap;
    return 'true';
  }

  String addFileBy(String userId, String name, int size) {
    if (!capacity.containsKey(userId) || files.containsKey(name)) {
      return '';
    }
    final left = _remaining(userId);
    if (left != null && size > left) {
      return '';
    }
    files[name] = StoredFile(name, size, userId);
    final after = _remaining(userId);
    return after == null ? '' : '$after';
  }

  String mergeUser(String userId1, String userId2) {
    if (userId1 == userId2) {
      return '';
    }
    if (!capacity.containsKey(userId1) || !capacity.containsKey(userId2)) {
      return '';
    }
    final cap1 = capacity[userId1];
    final cap2 = capacity[userId2];
    if (cap1 == null || cap2 == null) {
      return '';
    }
    capacity[userId1] = cap1 + cap2;
    for (final item in files.values) {
      if (item.owner == userId2) {
        item.owner = userId1;
      }
    }
    capacity.remove(userId2);
    backups.remove(userId2);
    final left = _remaining(userId1);
    return left == null ? '' : '$left';
  }

  String backupUser(String userId) {
    if (!capacity.containsKey(userId)) {
      return '';
    }
    final snap = <String, int>{};
    for (final item in files.values) {
      if (item.owner == userId) {
        snap[item.name] = item.size;
      }
    }
    backups[userId] = snap;
    return '${snap.length}';
  }

  String restoreUser(String userId) {
    if (!capacity.containsKey(userId)) {
      return '';
    }
    final owned = [
      for (final item in files.values)
        if (item.owner == userId) item.name,
    ];
    for (final name in owned) {
      files.remove(name);
    }
    final snap = backups[userId];
    if (snap == null) {
      return '0';
    }
    var restored = 0;
    snap.forEach((name, size) {
      if (files.containsKey(name)) {
        return;
      }
      final left = _remaining(userId);
      if (left != null && size > left) {
        return;
      }
      files[name] = StoredFile(name, size, userId);
      restored += 1;
    });
    return '$restored';
  }
}

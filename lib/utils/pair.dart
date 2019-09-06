
class Pair<K,V>{
  K key;
  V value;

  Pair(this.key, this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Pair &&
              runtimeType == other.runtimeType &&
              key == other.key &&
              value == other.value;

  @override
  int get hashCode =>
      key.hashCode ^
      value.hashCode;

  @override
  String toString() {
    return 'Pair{key: $key, value: $value}';
  }
}
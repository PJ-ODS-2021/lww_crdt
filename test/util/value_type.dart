class ValueType {
  String value;

  ValueType(this.value);

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) =>
      other is ValueType ? other.value == value : false;

  @override
  String toString() {
    return 'ValueType("$value")';
  }
}

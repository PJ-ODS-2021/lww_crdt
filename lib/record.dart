import 'package:collection/collection.dart';

import 'distributed_clock.dart';

class Record<T> {
  DistributedClock clock;
  T? value;

  Record({required this.clock, this.value});

  Record.from(Record<T> other, {T Function(T)? cloneValue})
      : clock = DistributedClock.from(other.clock),
        value = other.value == null
            ? null
            : (cloneValue != null ? cloneValue(other.value!) : other.value);

  bool get isDeleted => value == null;

  Map<String, dynamic> toJson({Function(T)? valueEncode}) {
    return {
      'clock': clock.toJson(),
      'value': value == null
          ? null
          : (valueEncode != null ? valueEncode(value!) : value),
    };
  }

  factory Record.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic)? valueDecode,
  }) {
    var jsonValue = json.containsKey('value') ? json['value'] : null;

    return Record(
      clock: DistributedClock.fromJson(json['clock'] as Map<String, dynamic>),
      value: jsonValue == null
          ? null
          : (valueDecode != null ? valueDecode(jsonValue) : jsonValue as T),
    );
  }

  @override
  int get hashCode => ListEquality().hash([clock.hashCode, value?.hashCode]);

  @override
  bool operator ==(Object other) =>
      other is Record<T> ? other.clock == clock && other.value == value : false;
}

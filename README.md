# LWW CRDT

Dart implementation of a simple last-write-wins CRDT based on vector clocks, timestamps and node ids.
Heavily influenced by <https://github.com/cachapa/crdt>.

## About

This library provides a simple last-write-wins CRDT map implementation.
Because it uses vector clocks, it is only useful in applications with a limited number of nodes.

## Implementation Details

The MapCrdt class provides an interface to store key-value pairs.
Every entry is stored as a record with an instance of a distributed clock.
The distributed clock consists of a vector clock, an unix timestamp and the creating node id.
A MapCrdt can be merged with another and values that are registered with the same key are resolved in the following manner:

1. If the vector clocks are comparable and not equal, use the most recent entry
2. Use the entry with the most recent timestamp
3. Use the node id as a tiebreaker

Additionally, the vector clock of the merge result is updated so that it contains the most recently known vector clock.
If merging with a previously unknown node, all vector clocks (local and record entries) get updated to contain the new node.

The `test` folder contains many tests that can be used as an example of how to use this library.

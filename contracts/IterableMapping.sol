// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

library IterableMapping {
  struct Map {
    address[] keys;
    mapping(address => uint) values;
    mapping(address => uint) indexOf;
    mapping(address => bool) inserted;
  }

  function get(Map storage map, address key) public view returns (uint) {
    return map.values[key];
  }

  function getKeyAtIndex(Map storage map, uint index) public view returns(address) {
    return map.keys[index];
  }

  function size(Map storage map) public view returns(uint) {
    return map.keys.length;
  }

  function set(Map storage map, address key, uint val) public {
    if (map.inserted[key]) {
      map.values[key] = val;
    } else {
      map.keys.push(key);
      map.values[key] = val;
      map.indexOf[key] = map.keys.length;
      map.inserted[key] = true;
    }
  }

  function remove(Map storage map, address key) public {
    if (!map.inserted[key]) {
      return;
    } else {
      delete map.inserted[key];
      delete map.values[key];

      uint index = map.indexOf[key];
      uint lastIndex = map.keys.length - 1;
      address lastKey = map.keys[lastIndex];

      map.indexOf[lastKey] = index;
      delete map.indexOf[key];

      map.keys[index] = lastKey;
      map.keys.pop();
    }
  }
}
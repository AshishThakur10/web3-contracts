// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract hello_world {
  string public message ="hi moluguri :), have a good day <3";
  uint public age;
  string public status;
  string[] public fevFoods;

  function checkVotingEligibility(uint _age) public {
    age = _age;
    if (_age >= 18) {
      status = "you are eligible to vote";

    } else {
      status = "you are not eligible to vote";
    }
  }

  function addFood(string memory _food) public {
    fevFoods.push(_food);
  }

  function getFoodCount() public view returns (uint) {
    return fevFoods.length;
  }

  function getFood(uint index) public view returns(string memory) {
    return fevFoods[index];
  }

}

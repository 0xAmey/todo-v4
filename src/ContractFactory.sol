// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Todo.sol";

contract ContractFactory {
    event NewTodoContract(uint256 id);

    Todo public todo;
    //required for testing
    Todo[] public storeTodoContracts;

    //maps the user address to contract address
    mapping(address => address) public userAddressToContractAddress;

    function createTodo() public {
        todo = new Todo(msg.sender);
        //required for testing
        storeTodoContracts.push(todo);
        userAddressToContractAddress[msg.sender] = address(todo);
    }

    function getAddress(address _user) public view returns (address) {
        return userAddressToContractAddress[_user];
    }
}

// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Todo.sol";
import "./mocks/MockERC20.sol";
import "../src/ContractFactory.sol";

contract CounterTest is Test {
    MockERC20 public mockToken;
    ContractFactory public contractFactory;
    Todo public todo;

    event TaskAdded(uint256 indexed taskId);

    function setUp() public {
        contractFactory = new ContractFactory();
        contractFactory.createTodo();

        todo = contractFactory.storeTodoContracts(0);

        mockToken = new MockERC20();
    }

    function testInitializesConstructorCorrectly() public {
        assertEq(todo.isAuthorised(address(this)), true);
    }

    function testAddsTaskCorrectly() public {
        mockToken.approve(address(todo), 100e18);
        // vm.expectEmit(true, false, false, false);
        // emit TaskAdded(0);
        todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );

        assertEq(mockToken.balanceOf(address(todo)), 10e18);
    }

    function testApprovesTaskCorrectly() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );
        assertEq(todo.getApprovalCount(taskId), 1);
    }

    function testAddsAuthorisedCorrectly() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );
        assertEq(todo.getApprovalCount(taskId), 1);
        todo.addAuthorised(address(0x1));

        vm.prank(address(0x1));
        todo.approve(taskId);

        assertEq(todo.getApprovalCount(taskId), 2);
    }

    function testRevokesApprovalCorrectly() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );
        assertEq(todo.getApprovalCount(taskId), 1);
        todo.addAuthorised(address(0x1));

        vm.prank(address(0x1));
        todo.approve(taskId);

        assertEq(todo.getApprovalCount(taskId), 2);

        vm.prank(address(0x1));
        todo.revokeApproval(taskId);
        assertEq(todo.getApprovalCount(taskId), 1);
    }

    function testCannotRevokeApprovalAfterTime() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );
        assertEq(todo.getApprovalCount(taskId), 1);
        todo.addAuthorised(address(0x1));

        vm.prank(address(0x1));
        todo.approve(taskId);

        assertEq(todo.getApprovalCount(taskId), 2);

        vm.warp(88000);
        vm.startPrank(address(0x1));
        vm.expectRevert("Timeover");
        todo.revokeApproval(taskId);
        vm.stopPrank();
    }

    function testOnlyAllowsCreatorToAddTasks() public {
        vm.startPrank(address(0x1));
        mockToken.approve(address(todo), 100e18);

        vm.expectRevert("OnlyCreator");
        todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );
    }

    function testRemovesAuthorisedCorrectly() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );
        todo.addAuthorised(address(0x1));

        assertEq(todo.getNumOfPartners(), 2);

        todo.removeAuthorised(address(0x1));

        vm.startPrank(address(0x1));
        vm.expectRevert("NotAuthorised");
        todo.approve(taskId);
    }

    function testUpdatesRequireCorrectly() public {
        assertEq(todo.required(), 1);

        todo.updateRequired(2);

        assertEq(todo.required(), 2);
    }

    function testCannotApprovefterTime() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );

        console.log(block.timestamp);
        vm.warp(86402);
        console.log(block.timestamp);
        vm.expectRevert("Timeover");
        todo.approve(taskId);
    }

    function testOnlyCreatorCanUpdateRequire() public {
        vm.startPrank(address(0x1));
        vm.expectRevert("OnlyCreator");
        todo.updateRequired(2);
        vm.stopPrank();
    }

    function testTaskExecutesSuccesfullyCorrectly() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );

        assertEq(mockToken.balanceOf(address(todo)), 10e18);

        vm.warp(88000);
        todo.userWithdraw(taskId);

        assertEq(mockToken.balanceOf(address(todo)), 0);
    }

    function testTaskFailsCorrectly() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );

        todo.updateRequired(2);

        assertEq(mockToken.balanceOf(address(todo)), 10e18);

        vm.warp(90000);

        todo.userWithdraw(taskId);

        assertEq(mockToken.balanceOf(address(0x9)), 10e18);
    }

    function testTaskDoesNotExecuteBeforeTime() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );

        assertEq(mockToken.balanceOf(address(todo)), 10e18);

        vm.warp(8640);

        vm.expectRevert("NotEnoughTimeElapsed");
        todo.userWithdraw(taskId);
    }

    function testOnlyAllowsCreatorToWithdraw() public {
        mockToken.approve(address(todo), 100e18);
        uint256 taskId = todo.addTask(
            "ipfs://QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4",
            address(mockToken),
            10e18,
            address(0x9)
        );

        assertEq(mockToken.balanceOf(address(todo)), 10e18);

        vm.warp(86400);

        vm.startPrank(address(0x1));
        vm.expectRevert("OnlyCreator");
        todo.userWithdraw(taskId);

        vm.stopPrank();
    }
}

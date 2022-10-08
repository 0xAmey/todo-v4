// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";

contract Todo {
    //---------------------------------------//
    //             Assignnments              //
    //---------------------------------------//

    enum TaskState {
        ongoing,
        completed,
        failed
    }

    IERC20 public token;

    uint256 public taskId = 0;

    // authorised addresses to approve task completion
    address[] public authorised;

    mapping(address => bool) public isAuthorised;

    // storing the approvals
    mapping(uint256 => mapping(address => bool)) public approved;

    mapping(uint256 => bool) executed;

    // num of approvals required to mark a task
    uint256 public required = 1;

    struct Task {
        bytes text;
        uint256 taskId;
        address tokenAddress;
        uint256 amountStaked;
        uint256 startTimestamp;
        address fallbackAddress;
        TaskState state;
    }

    Task[] public tasks;

    //---------------------------------------//
    //                Events                 //
    //---------------------------------------//

    event TaskAdded(bytes indexed taskText, uint256 indexed taskId);

    event TaskFinished(
        bytes indexed taskText,
        uint256 indexed taskId,
        TaskState indexed state
    );

    //---------------------------------------//
    //             Constructor               //
    //---------------------------------------//

    constructor(address _sender) {
        authorised.push(_sender);
        isAuthorised[_sender] = true;
    }

    receive() external payable {}

    fallback() external payable {}

    //---------------------------------------//
    //               Modifiers               //
    //---------------------------------------//

    modifier onlyAuthorised() {
        require(isAuthorised[msg.sender] == true, "NotAuthorised");
        _;
    }

    modifier onlyCreator() {
        require(msg.sender == authorised[0], "OnlyCreator");
        _;
    }

    modifier onlyOngoing(uint256 _taskId) {
        require(tasks[_taskId].state == TaskState.ongoing, "TaskNotOngoing");
        _;
    }

    modifier notExecuted(uint256 _taskId) {
        require(executed[_taskId] != true, "AlreadyExecuted");
        _;
    }

    modifier timeLeft(uint256 _taskId) {
        require(
            block.timestamp <= (tasks[_taskId].startTimestamp + 86400),
            "Timeover"
        );
        _;
    }

    //---------------------------------------//
    //             Main Logic                //
    //---------------------------------------//

    function addTask(
        bytes memory taskText,
        address _tokenAddress,
        uint256 _amountStaked,
        address _fallbackAddress
    ) public onlyCreator returns (uint256) {
        Task memory task = Task({
            text: taskText,
            taskId: taskId,
            tokenAddress: _tokenAddress,
            amountStaked: _amountStaked,
            startTimestamp: block.timestamp,
            fallbackAddress: _fallbackAddress,
            state: TaskState.ongoing
        });
        tasks.push(task);

        // autmatically approves the task from user address
        approved[taskId][msg.sender] = true;

        token = IERC20(_tokenAddress);
        token.transferFrom(msg.sender, address(this), _amountStaked);

        emit TaskAdded(taskText, taskId);

        return taskId++;
    }

    function approve(uint256 _taskId)
        public
        onlyAuthorised
        onlyOngoing(_taskId)
        timeLeft(_taskId)
    {
        approved[_taskId][msg.sender] = true;
    }

    function revokeApproval(uint256 _taskId)
        external
        onlyAuthorised
        onlyOngoing(_taskId)
        timeLeft(_taskId)
    {
        require(approved[_taskId][msg.sender], "TxAlreadyUnapproved");
        approved[_taskId][msg.sender] = false;
    }

    function userWithdraw(uint256 _taskId)
        public
        onlyCreator
        notExecuted(_taskId)
    {
        require(
            block.timestamp >= (tasks[_taskId].startTimestamp + 86400),
            "NotEnoughTimeElapsed"
        );
        executed[taskId] = true;
        uint256 approvals = getApprovalCount(_taskId);
        Task memory task = tasks[_taskId];
        if (approvals >= required) {
            tasks[_taskId].state = TaskState.completed;
            IERC20(task.tokenAddress).transfer(
                authorised[0],
                task.amountStaked
            );
            emit TaskFinished(task.text, taskId, TaskState.completed);
        } else {
            tasks[_taskId].state = TaskState.failed;
            IERC20(task.tokenAddress).transfer(
                task.fallbackAddress,
                task.amountStaked
            );
            emit TaskFinished(task.text, taskId, TaskState.failed);
        }
    }

    function addAuthorised(address _newAuthorised) public onlyCreator {
        authorised.push(_newAuthorised);
        isAuthorised[_newAuthorised] = true;
    }

    function removeAuthorised(address _removeAddr) public onlyCreator {
        require(isAuthorised[_removeAddr] == true && _removeAddr != msg.sender);
        isAuthorised[_removeAddr] = false;
    }

    function updateRequired(uint256 _newRequired) public onlyCreator {
        required = _newRequired;
        require(required >= 1, "NumOfApprovalsShouldBe>=1");
    }

    //---------------------------------------//
    //                 Getters               //
    //---------------------------------------//

    function getApprovalCount(uint256 _taskId)
        public
        view
        returns (uint256 count)
    {
        for (uint256 i; i < authorised.length; i++) {
            if (approved[_taskId][authorised[i]]) {
                count += 1;
            }
        }
    }

    function getOngoingTasks()
        public
        view
        returns (Task[] memory ongoingTasks)
    {
        uint256 counter = 0;
        for (uint256 i = 0; i < tasks.length; i++) {
            if (tasks[i].state == TaskState.ongoing) {
                ongoingTasks[counter] = tasks[i];
                counter++;
            }
        }
        return ongoingTasks;
    }

    function getFailedTasks() public view returns (Task[] memory failedTasks) {
        uint256 counter = 0;
        for (uint256 i = 0; i < tasks.length; i++) {
            if (tasks[i].state == TaskState.failed) {
                failedTasks[counter] = tasks[i];
                counter++;
            }
        }
        return failedTasks;
    }

    function getCompletedTasks()
        public
        view
        returns (Task[] memory completedTasks)
    {
        uint256 counter = 0;
        for (uint256 i = 0; i < tasks.length; i++) {
            if (tasks[i].state == TaskState.completed) {
                completedTasks[counter] = tasks[i];
                counter++;
            }
        }
        return completedTasks;
    }

    function getNumOfPartners() public view returns (uint256) {
        return authorised.length;
    }

    // QmaP6wGiic5Z3csGJprx5DFFVvX5KhKBmSZsBmywQ9Ebr4

    function getTaskText(uint256 _taskId)
        public
        view
        returns (bytes memory taskText)
    {
        return tasks[_taskId].text;
    }
}

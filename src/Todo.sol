// SPDX-License-Identifier: None
pragma solidity ^0.8.13;

contract Todo {
    //---------------------------------------//
    //             Assignnments              //
    //---------------------------------------//

    enum TaskState {
        ongoing,
        completed,
        failed
    }

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
        string text;
        uint256 taskId;
        uint256 amountStaked;
        uint256 startTimestamp;
        address fallbackAddress;
        TaskState state;
    }

    Task[] public tasks;

    //---------------------------------------//
    //                Events                 //
    //---------------------------------------//

    event TaskAdded(string indexed taskText, uint256 indexed taskId);

    event TaskFinished(
        string indexed taskText,
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

    // Utility to transfer native token to an address
    function transferNativeToken(address payable _to, uint256 _amount)
        internal
        returns (bool)
    {
        (bool success, ) = _to.call{value: _amount}("");

        require(success, "Transfer failed");
        return true;
    }

    //---------------------------------------//
    //             Main Logic                //
    //---------------------------------------//

    function addTask(
        string memory taskText,
        uint256 _amountStaked,
        address _fallbackAddress
    ) public payable onlyCreator returns (uint256) {
        require(_amountStaked > 0, "AmountStakedZero");
        require(_amountStaked == msg.value, "AmountStakedNotEqual");

        Task memory task = Task({
            text: taskText,
            taskId: taskId,
            amountStaked: _amountStaked,
            startTimestamp: block.timestamp,
            fallbackAddress: _fallbackAddress,
            state: TaskState.ongoing
        });

        tasks.push(task);

        // automatically approves the task from user address
        approved[taskId][msg.sender] = true;

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

            transferNativeToken(payable(authorised[0]), task.amountStaked);

            emit TaskFinished(task.text, taskId, TaskState.completed);
        } else {
            tasks[_taskId].state = TaskState.failed;

            transferNativeToken(payable(task.fallbackAddress), task.amountStaked);

            emit TaskFinished(task.text, taskId, TaskState.failed);
        }
    }

    function addAuthorised(address _newAuthorised) public onlyCreator {
        authorised.push(_newAuthorised);
        isAuthorised[_newAuthorised] = true;
    }

    function removeAuthorised(address _removeAddr) public onlyCreator {
        require(isAuthorised[_removeAddr] == true && _removeAddr != msg.sender, "NotAuthorised");

        isAuthorised[_removeAddr] = false;
    }

    function updateRequired(uint256 _newRequired) public onlyCreator {
        require(_newRequired >= 1, "num approvals not >= 1");

        required = _newRequired;
    }

    //---------------------------------------//
    //               Getters                 //
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

    function getTaskText(uint256 _taskId)
        public
        view
        returns (string memory taskText)
    {
        return tasks[_taskId].text;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMainContract {
    function interact(address _user) external returns (uint256);
}

contract InteractFeeProxy {
    IMainContract public immutable mainContract;
    uint256 public immutable INTERACT_FEE;
    address public owner;

    event FeePaid(address indexed user, uint256 amount);
    event InteractionForwarded(address indexed user, bool success);
    event Withdraw(address indexed to, uint256 amount);

    constructor(address _mainContractAddress) {
        require(_mainContractAddress != address(0), "Invalid MainContract address");
        mainContract = IMainContract(_mainContractAddress);
        INTERACT_FEE = 0.001 ether;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function interactWithFee() public payable {
        require(msg.value >= INTERACT_FEE, "Insufficient fee sent");
        if (msg.value > INTERACT_FEE) {
            payable(msg.sender).transfer(msg.value - INTERACT_FEE);
        }
        emit FeePaid(msg.sender, INTERACT_FEE);
        
        (bool success, ) = address(mainContract).call(
            abi.encodeWithSignature("interact(address)", msg.sender)
        );
        require(success, "Failed to call interact on MainContract");

        emit InteractionForwarded(msg.sender, true);
    }

    function withdrawEther() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
        emit Withdraw(owner, balance);
    }
}

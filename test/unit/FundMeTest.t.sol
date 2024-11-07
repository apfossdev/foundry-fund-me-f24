// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "src/FundMe.sol"; //we import the main file here for testing it here;
import {DeployFundMe} from "script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user"); // makeAddr is also a cheat code not from vm but from std lib so no need of vm prefix
    //makeAddr creates an address from a string which can be accessed by USER constant as defined above
    uint256 constant SEND_VALUE = 0.1 ether; //as decimals don't work in solidity
    uint256 constant STARTING_VALUE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        //we are doing the above so that we can deploy the tests with the same address used in the deplyFundMe.s.sol(which deploys the main fundMe.sol contract) contract so that the tests don't fail
        vm.deal(USER, STARTING_VALUE); //we use this cheat code to give our prank USER a balance of 10 ether to start out with
    }

    function testMinimumDollarsIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        // use console.log for debugging
        // console.log(fundMe.i_owner());
        // console.log(msg.sender);
        // assertEq(fundMe.i_owner(), msg.sender); //this won't work as the owner of this contract is FundMeTest not us, so we change it to address(this)
        // above statement was previously now msg.sender is the owner of the contract and it will work after the REFACTORING PROCESS For Various Addreses
        // assertEq(fundMe.i_owner(), address(this));
        assertEq(fundMe.getOwner(), msg.sender);
    }

    // What can we do to work with addresses outside our system?
    // * **Unit tests**:
    // Focus on isolating and testing individual smart contract functions or functionalities.
    // * **Integration tests**:
    // Verify how a smart contract interacts with other contracts or external systems.
    // * **Forking tests**:
    // Forking refers to creating a copy of a blockchain state at a specific point in time. This copy, called a fork, is then used to run tests in a simulated environment.
    // * **Staging tests**:
    // Execute tests against a deployed smart contract on a staging environment before mainnet deployment.

    //the below function won't work as it spins up a local chain on anvil and deletes it after the test is over, hence the getVersion doesn't work as there exists no contract on the address and therefore it reverts back
    // so we use Forking tests using these flags in the previously used commands --fork-url $SEPOLIA_RPC_URL stored in .env
    function testPriceFeedVersionIsAccurate() public view {
        assertEq(fundMe.getVersion(), 4);
    }

    function testFundFailsIfEthAmountIsLessThanMinimum() public {
        vm.expectRevert();
        fundMe.fund{value: 0}(); //send 0 value
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); //The next txn will be sent by user
        fundMe.fund{value: SEND_VALUE}(); //sending 10 eth
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
        //as each time we run this test, it will go to the setup then test here ignoring all the other tests, so the funders array will it max always have only 1 funder in this testing environment atleast
    }

    //we write this modifier to increase code readability, and to use this everywhere wherever previously repeated reducing multiple lines of code increasing code readability
    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        // vm.prank(USER);
        // fundMe.fund{value: SEND_VALUE}();

        vm.expectRevert(); //here it should revert in the next line but it will in the next to next line as it ignores vm. lines
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        //this is the framework to write any test
        //1. Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //2. Act
        // uint256 gasStart = gasleft(); //assume 1000, to calc. how much gas is used we need the starting gas as well, so we use gasleft() to get the starting gas, it is an in built function of forge
        // vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner()); //assume costs 200
        fundMe.withdraw();

        // uint256 gasEnd = gasleft(); //then this should be 1000 - 200 = 800
        // uint256 gasUsed;
        // if (gasStart >= gasEnd) {
        //     gasUsed = (gasStart - gasEnd) * tx.gasprice;
        // } else {
        //     revert("Gas calculation error");
        // }
        // console.log("Gas used:", gasUsed);

        //3. Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        // 1. Arrange
        uint160 numberOfFunders = 10; //uint160 has the same number of bytes as an address, if you want to use bytes numbers to generate addresses use uint 160
        uint160 startingFunderIndex = 1; //not 0 and 1 for a particular reason, we want to start from 1 as 0 is the owner (came from superMaven not sure)
        for (uint160 funderIndex = startingFunderIndex; funderIndex < numberOfFunders; funderIndex++) {
            //prank + deal = hoax from std lib itself
            hoax(address(funderIndex), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // 2. Act
        // vm.prank(fundMe.getOwner());
        // fundMe.withdraw();

        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        //vm.startPrank and vm.stopPrank are same like startBroadcast and stopBroadcast for pranks

        // 3. Assert
        assert(address(fundMe).balance == 0); //we should have 0 balance after withdrawing
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance); //we should have the same balance after withdrawing
    }

    function testWithdrawFromMultipleFunders() public funded {
        // 1. Arrange
        uint160 numberOfFunders = 10; //uint160 has the same number of bytes as an address, if you want to use bytes numbers to generate addresses use uint 160
        uint160 startingFunderIndex = 1; //not 0 and 1 for a particular reason, we want to start from 1 as 0 is the owner (came from superMaven not sure)
        for (uint160 funderIndex = startingFunderIndex; funderIndex < numberOfFunders; funderIndex++) {
            //prank + deal = hoax from std lib itself
            hoax(address(funderIndex), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // 2. Act
        // vm.prank(fundMe.getOwner());
        // fundMe.withdraw();

        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //vm.startPrank and vm.stopPrank are same like startBroadcast and stopBroadcast for pranks

        // 3. Assert
        assert(address(fundMe).balance == 0); //we should have 0 balance after withdrawing
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance); //we should have the same balance after withdrawing
    }
}

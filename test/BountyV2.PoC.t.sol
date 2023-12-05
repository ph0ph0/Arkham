pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "../src/ARKM.sol";
import "../src/ARKM_Upgrade.sol";
import "../src/import.sol";
import "../src/BountyV2.sol";

contract BountyV2Test is Test {
    using stdJson for string;

    ARKM public arkm;
    ARKMV2 public arkmV2;
    AdminUpgradeabilityProxy public proxy;
    ARKM public proxyAsARKM;
    BountyV2 public bounty;

    address public owner;
    address public impOwner;
    address public testUser;
    address public testUser2;
    // Used to create addresses
    uint256 _addressSeed = 123456789;

    function makeAddress(string memory label) public returns (address) {
        address addr = vm.addr(_addressSeed);
        vm.label(addr, label);
        _addressSeed++;
        return addr;
    }

    function setUp() public {
        owner = makeAddress("Owner");
        impOwner = makeAddress("ImpOwner");
        testUser = makeAddress("TestUser");
        testUser2 = makeAddress("TestUser2");
        vm.deal(owner, 100 ether);
        vm.deal(testUser, 100 ether);
        vm.deal(testUser2, 100 ether);
        vm.startPrank(owner, owner);
        // Deploy Arkham implementation
        arkm = new ARKM();
        // Deploy Arkham proxy
        proxy = new AdminUpgradeabilityProxy(address(arkm), owner, "");
        vm.stopPrank();
        // Call init on Arkham implementation
        // In the constructor of ARKM, you will notice that there is a call to _disableInitializers() in the constructor. This is to ensure that the initialize() function is not called directly in the contract, but through the proxy, as the state needs to be initialized in the proxy contract.
        vm.startPrank(impOwner, impOwner);
        // (bool success1,) = address(proxy).call(abi.encodeWithSelector(arkm.initialize.selector));
        // require(success1, "Call to init failed");
        // Call init on Arkham proxy
        address proxyAddress = address(proxy);
        proxyAsARKM = ARKM(proxyAddress);
        proxyAsARKM.initialize();

        // Transfer some ARMK to the testUser
        proxyAsARKM.transfer(testUser, 1000000);
        // Transfer some ARMK to the testUser2
        proxyAsARKM.transfer(testUser2, 10000000000000000000);

        // Deploy BountyV2
        /// @notice BountyV2 constructor
        /// @param _arkmAddress Address of the ARKM token
        /// @param _initialSubmissionStake Amount of ARKM to stake when submitting a new bounty
        /// @param _initialMakerFee Percentage of the bounty amount to be paid to the bounty creator
        /// @param _initialTakerFee Percentage of the bounty amount to be paid to the bounty solver
        /// @param _bountyDuration Duration of the bounty in seconds
        /// @param _feeReceiverAddress Address to receive the fees
        /// @param _initialMaxActiveSubmissions Maximum number of active submissions per bounty
        /// @param _initialMinBounty Minimum amount of ARKM to create a bounty
        bounty =
        new BountyV2(address(proxy), 10000000000000000000, 250, 500, 30, 0x90423cBdE95cBC6FA30860b22eF5DD0181283914, 100, 100);
        vm.stopPrank();
    }

    // function test_Upgrade() public {
    //     address impOwner = testUser;
    //     address proxyOwner = owner;

    //     vm.startPrank(impOwner, impOwner);
    //     // Deploy new Arkham implementation
    //     arkmV2 = new ARKMV2();
    //     address arkmV2address = address(arkmV2);
    //     console2.log("arkm", address(arkm));
    //     console2.log("arkmV2", arkmV2address);
    //     vm.stopPrank();

    //     vm.startPrank(proxyOwner, proxyOwner);

    //     // Get the proxy address, then create the ARKM contract using the proxy address
    //     address proxyAddress = address(proxy);
    //     ARKM proxyAsARKM = ARKM(proxyAddress);

    //     // Upgrade to new implementation in the proxy
    //     // Call as proxy owner to upgrade the proxy implementation address record
    //     proxyAsARKM.upgradeTo(arkmV2address);
    //     // Get and log the upgraded to address in the proxy
    //     address upgradedTo = ITransparentUpgradeableProxy(address(proxy)).implementation();
    //     console2.log("upgradedToInProxy", upgradedTo);
    //     vm.stopPrank();

    //     // NOTE: You can also call as implementation owner to upgrade the implementation imp address record, and it will work the same as calling as proxy owner above
    //     vm.startPrank(impOwner, impOwner);
    //     proxyAsARKM.upgradeTo(arkmV2address);

    //     // vm.startPrank(impOwner, impOwner);
    //     // Now call initialize on the new implementation
    //     // First get create the proxyAsARKMV2 variable
    //     ARKMV2 proxyAsARKMV2 = ARKMV2(proxyAddress);
    //     // proxyAsARKMV2.initialize();
    //     uint256 num = proxyAsARKMV2.getNum();
    //     console2.log("num", num);
    // }

    // function test_FundBounty() public {
    //     vm.startPrank(testUser, testUser);
    //     // Since it's an ERC20 we must approve the Bounty contract so it can spend our ARKM.
    //     proxyAsARKM.approve(address(bounty), 10000000000000000000);
    //     // Fund the bounty
    //     bounty.fundBounty(1, 100);
    //     vm.stopPrank();
    // }

    // function testRevert_OnlyApproverCanCloseBounty() public {
    //     vm.startPrank(testUser, testUser);
    //     // Since it's an ERC20 we must approve the Bounty contract so it can spend our ARKM.
    //     proxyAsARKM.approve(address(bounty), 10000000000000000000);
    //     // Fund the bounty
    //     bounty.fundBounty(1, 100);
    //     vm.expectRevert("BountyV2: only approvers can close before expiration");
    //     bounty.closeBounty(1);
    //     vm.stopPrank();
    // }

    function test_ApproverCanCloseBounty() public {
        vm.startPrank(testUser, testUser);
        // Since it's an ERC20 we must approve the Bounty contract so it can spend our ARKM.
        proxyAsARKM.approve(address(bounty), 10000000000000000000);
        // Fund the bounty
        bounty.fundBounty(1, 100);
        vm.stopPrank();

        vm.startPrank(owner, owner);
        bounty.grantApprover(owner);
        bool ownerIsApprover = bounty.approver(owner);
        console2.log("ownerIsApprover", ownerIsApprover);
        bounty.closeBounty(1);
        vm.stopPrank();
    }

    // function test_SubmissionForBounty() public {
    //     vm.startPrank(testUser, testUser);
    //     // Since it's an ERC20 we must approve the Bounty contract so it can spend our ARKM.
    //     proxyAsARKM.approve(address(bounty), 10000000000000000000);
    //     // Fund the bounty
    //     bounty.fundBounty(1, 100);
    //     vm.stopPrank();

    //     vm.startPrank(testUser2, testUser2);
    //     // Approve ARKM for testUser2
    //     proxyAsARKM.approve(address(bounty), bounty.submissionStake());
    //     // Submit a solution for the bounty
    //     bounty.makeSubmission(1, 0);
    //     vm.stopPrank();
    // }
}

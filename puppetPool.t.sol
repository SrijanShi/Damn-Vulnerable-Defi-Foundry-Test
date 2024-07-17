pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "src/uniswap-V1/PuppetPool.sol";
import "wallet-mining/DamnValuableToken.sol";

contract MockUniswapPair {
    DamnValuableToken public token;
    uint256 public ethBalance;
    uint256 public tokenBalance;

    constructor(address _token) {
        token = DamnValuableToken(_token);
    }

    function addLiquidity(uint256 tokenAmount) external payable {
        require(msg.value > 0, "Must send ETH");
        require(tokenAmount > 0, "Must send tokens");
        
        token.transferFrom(msg.sender, address(this), tokenAmount);
        ethBalance += msg.value;
        tokenBalance += tokenAmount;
    }

    function getTokenToEthInputPrice(uint256 tokensSold) external view returns (uint256) {
        require(tokenBalance > 0 && ethBalance > 0, "No liquidity");
        return (tokensSold * ethBalance) / tokenBalance;
    }

    receive() external payable {}
}

contract puppetPoolTest is Test {
    MockUniswapPair public uniswapPair;
    DamnValuableToken public token;
    PuppetPool public pool;

    address public constant attacker = address(0x1);
    uint256 public constant POOL_INITIAL_TOKEN_BALANCE = 100000e18;
    uint256 public constant UNISWAP_INITIAL_ETH_BALANCE = 10 ether;
    uint256 public constant UNISWAP_INITIAL_TOKEN_BALANCE = 10e18;
    uint256 public constant ATTACKER_INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 public constant ATTACKER_INITIAL_ETH_BALANCE = 25 ether;

    function setUp() public {
        token = new DamnValuableToken();
        uniswapPair = new MockUniswapPair(address(token));
        pool = new PuppetPool(address(token), address(uniswapPair));

        // Setup initial balances
        token.transfer(address(this), UNISWAP_INITIAL_TOKEN_BALANCE);
        token.approve(address(uniswapPair), UNISWAP_INITIAL_TOKEN_BALANCE);
        uniswapPair.addLiquidity{value: UNISWAP_INITIAL_ETH_BALANCE}(UNISWAP_INITIAL_TOKEN_BALANCE);

        token.transfer(address(pool), POOL_INITIAL_TOKEN_BALANCE);
        token.transfer(attacker, ATTACKER_INITIAL_TOKEN_BALANCE);
        
        vm.deal(attacker, ATTACKER_INITIAL_ETH_BALANCE);

        assertEq(token.balanceOf(address(pool)), POOL_INITIAL_TOKEN_BALANCE);
        assertEq(token.balanceOf(attacker), ATTACKER_INITIAL_TOKEN_BALANCE);
        assertEq(attacker.balance, ATTACKER_INITIAL_ETH_BALANCE);
    }

    function testInitialSetup() public {
        assertEq(address(pool.token()), address(token));
        assertEq(pool.uniswapPair(), address(uniswapPair));
        assertEq(token.balanceOf(address(pool)), POOL_INITIAL_TOKEN_BALANCE);
        assertEq(token.balanceOf(attacker), ATTACKER_INITIAL_TOKEN_BALANCE);
        assertEq(attacker.balance, ATTACKER_INITIAL_ETH_BALANCE);
        assertEq(uniswapPair.ethBalance(), UNISWAP_INITIAL_ETH_BALANCE);
        assertEq(uniswapPair.tokenBalance(), UNISWAP_INITIAL_TOKEN_BALANCE);
    }

    function testConstructor() public {
        // Create a new instance of PuppetPool to trigger the constructor
        PuppetPool newPool = new PuppetPool(address(token), address(uniswapPair));
        
        // Assertions to verify constructor state
        assertEq(address(newPool.token()), address(token));
        assertEq(address(newPool.uniswapPair()), address(uniswapPair));
    }

    function testDepositRequired() public {
        uint256 amount = 100e18;
        uint256 ETHrequired = pool.calculateDepositRequired(amount);
        assertGt(ETHrequired, 0);
    }
    function testBorrow() public {
        uint256 borrowAmount = 10e18;
        uint256 depositRequired = pool.calculateDepositRequired(borrowAmount);

        vm.startPrank(attacker);
        token.approve(address(pool), borrowAmount);
        pool.borrow{value: depositRequired}(borrowAmount, attacker);
        vm.stopPrank();

        assertEq(token.balanceOf(attacker), ATTACKER_INITIAL_TOKEN_BALANCE + borrowAmount);
        assertEq(attacker.balance, ATTACKER_INITIAL_ETH_BALANCE - depositRequired);
        assertEq(address(pool).balance, depositRequired);
    }
    
    function testBorrowInsufficientCollateral() public {
        uint256 borrowAmount = 10e18;
        uint256 depositRequired = pool.calculateDepositRequired(borrowAmount);

        vm.startPrank(attacker);
        token.approve(address(pool), borrowAmount);
        vm.expectRevert(PuppetPool.NotEnoughCollateral.selector);
        pool.borrow{value: depositRequired - 1}(borrowAmount, attacker);
        vm.stopPrank();
    }

    /*function testBorrowInsufficientPoolLiquidity() public {
    uint256 borrowAmount = POOL_INITIAL_TOKEN_BALANCE + 1;
    uint256 depositRequired = pool.calculateDepositRequired(borrowAmount);
    //vm.expectRevert("TransferFailed()");
    //assertEq(POOL_INITIAL_TOKEN_BALANCE, borrowAmount);
    vm.startPrank(attacker);
    token.approve(address(pool), borrowAmount);
    vm.expectRevert(abi.encodeWithSignature("TransferFailed()"));
    pool.borrow{value: depositRequired}(borrowAmount, attacker);
    vm.stopPrank();
    }*/
    function testBorrowWithExcessETH() public {
    uint256 borrowAmount = 10e18;
    uint256 depositRequired = pool.calculateDepositRequired(borrowAmount);
    uint256 excessETH = 1 ether;

    uint256 initialBalance = attacker.balance;

    vm.startPrank(attacker);
    token.approve(address(pool), borrowAmount);
    pool.borrow{value: depositRequired + excessETH}(borrowAmount, attacker);
    vm.stopPrank();

    assertEq(attacker.balance, initialBalance - depositRequired);
    }
    function testComputeOraclePrice() public {
    uint256 amount = 1e18; // 1 token
    uint256 depositRequired = pool.calculateDepositRequired(amount);
    
    // Expected price calculation
    uint256 expectedPrice = (UNISWAP_INITIAL_ETH_BALANCE * 1e18) / UNISWAP_INITIAL_TOKEN_BALANCE;
    uint256 expectedDepositRequired = (amount * expectedPrice * pool.DEPOSIT_FACTOR()) / 1e18;
    
    assertEq(depositRequired, expectedDepositRequired);
    }
    function testBorrowEvent() public {
    uint256 borrowAmount = 10e18;
    uint256 depositRequired = pool.calculateDepositRequired(borrowAmount);

    vm.startPrank(attacker);
    token.approve(address(pool), borrowAmount);
    
    vm.expectEmit(true, true, false, true);
    emit PuppetPool.Borrowed(attacker, attacker, depositRequired, borrowAmount);
    pool.borrow{value: depositRequired}(borrowAmount, attacker);
    vm.stopPrank();
    }
      
}

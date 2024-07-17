pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "damn-vulnerable-defi/src/puppet-v2/UniswapV2Library.sol";
import "damn-vulnerable-defi/src/puppet-v2/PuppetV2Pool.sol";
import {IUniswapV2Pair} from "node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";


interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}


contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "ERC20: insufficient allowance");
        allowance[from][msg.sender] -= amount;
        return _transfer(from, to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        require(balanceOf[from] >= amount, "ERC20: insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
contract PuppetPoolv2Test is Test {
    PuppetV2Pool public pool;
    MockERC20 public weth;
    MockERC20 public token;
    address public uniswapPair;
    address public uniswapFactory;
    address public user = address(1);
    uint256 public constant INITIAL_WETH_BALANCE = 1000 ether;
    uint256 public constant INITIAL_TOKEN_BALANCE = 1000000e18;

    function setUp() public {
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        token = new MockERC20("DamnVulToken", "DVT", 18);
        uniswapPair = address(2);
        uniswapFactory = address(3);
        pool = new PuppetV2Pool(address(weth), address(token), uniswapPair, uniswapFactory);

        token.mint(address(pool), INITIAL_TOKEN_BALANCE);
        weth.mint(address(user), INITIAL_WETH_BALANCE);
        token.mint(address(user), 1000e18);

        // Mock the factory's getPair function
        vm.mockCall(
            uniswapFactory,
            abi.encodeWithSelector(IUniswapV2Factory.getPair.selector, address(weth), address(token)),
            abi.encode(uniswapPair)
        );

        // Mock the pair's getReserves function
        vm.mockCall(
            uniswapPair,
            abi.encodeWithSelector(IUniswapV2Pair.getReserves.selector),
            abi.encode(100 ether, 100 ether, uint32(block.timestamp))
        );
    }
    function testBorrow() public {
        uint256 borrowAmount = 10e18;
        uint256 requiredDeposit = pool.calculateDepositOfWETHRequired(borrowAmount);
        vm.startPrank(user);
        weth.approve(address(pool), requiredDeposit);
        uint256 userInitialWETHBalance = weth.balanceOf(user);
        uint256 userInitialTokenBalance = token.balanceOf(user);
        uint256 poolInitialWETHBalance = weth.balanceOf(address(pool));
        uint256 poolInitialTokenBalance = token.balanceOf(address(pool));

        pool.borrow(borrowAmount);
        assertEq(weth.balanceOf(user), userInitialWETHBalance - requiredDeposit);
        assertEq(token.balanceOf(user), userInitialTokenBalance + borrowAmount);
        assertEq(weth.balanceOf(address(pool)), poolInitialWETHBalance + requiredDeposit);
        assertEq(token.balanceOf(address(pool)), poolInitialTokenBalance - borrowAmount);
        vm.stopPrank();
    }
}
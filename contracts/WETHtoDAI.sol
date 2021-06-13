//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./DCA.sol";

interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
}
interface IYearnV2Vault {
    function deposit(uint amount) external returns (uint);
    function withdraw(uint amount) external returns (uint);
}

contract WETHtoDAI is DCA {
  using SafeERC20 for IERC20;

  IUniswapV2Pair constant sushiDaiPair = IUniswapV2Pair(0xC3D03e4F041Fd4cD388c549Ee2A29a9E5075882f);
  IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  constructor() DCA("ETH->DAI", "DCA Vault: yETH->yDAI", 0xa9fE4601811213c340e850ea305481afF02f5b28, 0x19D3364A399d251E894aC732651be8B0E4e85001){
    DAI.approve(0x19D3364A399d251E894aC732651be8B0E4e85001,  2**256 - 1); // DAI doesn't decrease allowance if it's uint(-1)
  }

  function executeSell(uint minReceivedPerToken) internal override returns (uint pricePerToken) {
    uint amountIn = IYearnV2Vault(address(tokenToSell)).withdraw(dailyTotalSell);

    tokenToSell.safeTransfer(address(sushiDaiPair), amountIn);
    (uint256 reserve0, uint256 reserve1, ) = sushiDaiPair.getReserves();
    uint256 amountInWithFee = amountIn * 997;
    uint amountOut = (amountInWithFee * reserve0) / ((reserve1 * 1000) + amountInWithFee);
    sushiDaiPair.swap(amountOut, 0, address(this), new bytes(0));

    uint tokensToBuyReceived = IYearnV2Vault(address(tokenToBuy)).deposit(amountOut);
    require(tokensToBuyReceived >= (dailyTotalSell * minReceivedPerToken), "Slippage");
    pricePerToken = (tokensToBuyReceived * 1e18)/dailyTotalSell;
  }

  function _baseURI() internal pure override returns (string memory) {
    return "https://dca-api.llama.fi/yethydai/";
  }
}
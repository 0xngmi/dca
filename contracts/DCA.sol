//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DCA is ERC721, AccessControl {
  using SafeERC20 for IERC20;

  bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");
  struct UserPosition {
    uint256 dayStart;
    uint256 dailySellAmount;
    uint256 lastDay;
  }

  IERC20 public immutable tokenToSell;
  IERC20 public immutable tokenToBuy;
  uint256 public length;
  uint256 public dailyTotalSell;
  uint256 public lastDaySold;

  mapping(uint256 => uint256) public exchangePricesCumulative;
  mapping(uint256 => uint256) public removeSellAmountByDay;
  mapping(uint256 => UserPosition) public userPositions;

  function currentDay() public view returns (uint256) {
    return block.timestamp / 1 days;
  }

  constructor(string memory _name, string memory _symbol, address _tokenToSell, address _tokenToBuy)
    ERC721(_name, _symbol)
  {
    tokenToSell = IERC20(_tokenToSell);
    tokenToBuy = IERC20(_tokenToBuy);
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    lastDaySold = currentDay();
  }

  function provide(uint256 sellDurationInDays, uint256 dailySellAmount)
    public
    returns (uint256)
  {
    tokenToSell.safeTransferFrom(
      msg.sender,
      address(this),
      sellDurationInDays * dailySellAmount
    );
    return createPosition(sellDurationInDays, dailySellAmount);
  }

  function createPosition(uint256 sellDurationInDays, uint256 dailySellAmount)
    internal
    returns (uint256)
  {
    require(sellDurationInDays > 0, "duration!=0");
    uint256 dayStart = currentDay();
    require((lastDaySold + 2) > dayStart, "Halted");
    if(lastDaySold < dayStart){
      unchecked{dayStart -= 1;} // Already sold today
    }
    uint256 lastDay = dayStart + sellDurationInDays;
    removeSellAmountByDay[lastDay] += dailySellAmount;
    dailyTotalSell += dailySellAmount;

    uint256 id = length;
    userPositions[id] = UserPosition({
      dayStart: dayStart,
      dailySellAmount: dailySellAmount,
      lastDay: lastDay
    });
    _mint(msg.sender, id);
    unchecked {length += 1;}

    return id;
  }

  function min(uint a, uint b) pure internal returns (uint) {
    return a<b?a:b;
  }

  function computeTokensBought(uint lastDay, uint positionDayStart, uint dailySellAmount) view internal returns (uint tokensBought){
    uint priceCumulative;
    unchecked {
     priceCumulative = exchangePricesCumulative[lastDay] - exchangePricesCumulative[positionDayStart]; 
    }
    tokensBought = (priceCumulative * dailySellAmount)/1e18;
  }

  function tokensToBuyBought(uint256 id)
    public
    view
    returns (uint)
  {
    UserPosition memory position = userPositions[id];
    uint lastDay = min(lastDaySold, position.lastDay);
    return computeTokensBought(lastDay, position.dayStart, position.dailySellAmount);
  }

  function computeTokensToSellLeft(uint lastDay, uint dailySellAmount) view internal returns (uint tokensLeft){
    uint dayDiff = 0;
    if(lastDaySold < lastDay){
      unchecked {
        dayDiff = lastDay - lastDaySold;
      }
    }
    tokensLeft = dayDiff * dailySellAmount;
  }

  function tokensToSellLeft(uint256 id)
    public
    view
    returns (uint)
  {
    UserPosition memory position = userPositions[id];
    return computeTokensToSellLeft(position.lastDay, position.dailySellAmount);
  }

  function exit(uint256 id)
    public
  {
    require(ownerOf(id) == msg.sender, "Not authorized");
    _burn(id);
    UserPosition storage position = userPositions[id];
    if(lastDaySold < position.lastDay){
      dailyTotalSell -= position.dailySellAmount;
      removeSellAmountByDay[position.lastDay] -= position.dailySellAmount;
    }
    uint lastDay = min(lastDaySold, position.lastDay);
    uint tokensBought = computeTokensBought(lastDay, position.dayStart, position.dailySellAmount);
    tokenToBuy.safeTransfer(msg.sender, tokensBought);
    tokenToSell.safeTransfer(msg.sender, computeTokensToSellLeft(position.lastDay, position.dailySellAmount));
  }

  function withdrawSold(uint256 id)
    public
  {
    require(ownerOf(id) == msg.sender, "Not authorized");
    UserPosition storage position = userPositions[id];
    uint lastDay = min(lastDaySold, position.lastDay);
    uint tokensBought = computeTokensBought(lastDay, position.dayStart, position.dailySellAmount);

    position.dayStart = lastDay;
    tokenToBuy.safeTransfer(msg.sender, tokensBought);
  }

  function executeSell(uint minReceivedPerToken) internal virtual returns (uint) {}

  function sell(uint minReceivedPerToken) public onlyRole(SELLER_ROLE) {
    uint today = currentDay();
    require(lastDaySold == (today - 1));
    uint price = executeSell(minReceivedPerToken);
    exchangePricesCumulative[today] = exchangePricesCumulative[today - 1] + price;
    lastDaySold = today;
    dailyTotalSell -= removeSellAmountByDay[today];
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
    return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
  }
}

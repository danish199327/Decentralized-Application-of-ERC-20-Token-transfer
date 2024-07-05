// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PKRToken.sol";

contract XYZStockToken is ERC20, Ownable {
    // Bidding structure
    struct Bid {
        uint256 tokenAmount;
        uint256 pkrAmount;
    }

    PKRToken public pkrToken;
    mapping(address => Bid) public bids;
    uint256 public lockedTokens;

    constructor(PKRToken _pkrToken, address initialOwner) ERC20("XYZ Stock Token", "XYZT") Ownable(initialOwner) {
        _mint(initialOwner, 1500 * 10 ** decimals());
        pkrToken = _pkrToken;
    }

    function placeBid(uint256 tokenAmount, uint256 pkrAmount) external {
        require(tokenAmount > 0, "Token amount must be greater than zero");
        require(pkrAmount > 0, "PKR amount must be greater than zero");

        uint256 ownerBalance = balanceOf(owner());
        require(ownerBalance - lockedTokens >= tokenAmount, "Owner does not have enough unlocked tokens");

        bids[msg.sender] = Bid({
            tokenAmount: tokenAmount,
            pkrAmount: pkrAmount
        });

        lockedTokens += tokenAmount;
        require(pkrToken.transferFrom(msg.sender, address(this), pkrAmount), "Transfer of PKR failed");
    }

    function acceptBid(address bidder) external onlyOwner {
        Bid memory bid = bids[bidder];
        require(bid.tokenAmount > 0 && bid.pkrAmount > 0, "No valid bid found");

        uint256 ownerBalance = balanceOf(owner());
        require(ownerBalance >= bid.tokenAmount, "Owner does not have enough tokens");

        _transfer(owner(), bidder, bid.tokenAmount);
        require(pkrToken.transfer(owner(), bid.pkrAmount), "Transfer of PKR failed");

        lockedTokens -= bid.tokenAmount;
        delete bids[bidder];
    }

    function rejectBid(address bidder) external onlyOwner {
        Bid memory bid = bids[bidder];
        require(bid.tokenAmount > 0 && bid.pkrAmount > 0, "No valid bid found");

        require(pkrToken.transfer(bidder, bid.pkrAmount), "Transfer of PKR failed");

        lockedTokens -= bid.tokenAmount;
        delete bids[bidder];
    }

    function withdrawBid() external {
        Bid memory bid = bids[msg.sender];
        require(bid.tokenAmount > 0 && bid.pkrAmount > 0, "No valid bid found");

        require(pkrToken.transfer(msg.sender, bid.pkrAmount), "Transfer of PKR failed");

        lockedTokens -= bid.tokenAmount;
        delete bids[msg.sender];
    }

    function distributeDividends(address[] calldata stakeholders, uint256 totalDividendAmount) external onlyOwner {
        require(totalDividendAmount > 0, "Dividend amount must be greater than zero");
        require(pkrToken.balanceOf(address(this)) >= totalDividendAmount, "Not enough balance in contract");

        uint256 totalSupply = totalSupply();
        for (uint256 i = 0; i < stakeholders.length; i++) {
            address stakeholder = stakeholders[i];
            uint256 balance = balanceOf(stakeholder);
            if (balance > 0) {
                uint256 dividend = (totalDividendAmount * balance) / totalSupply;
                require(pkrToken.transfer(stakeholder, dividend), "Transfer of PKR failed");
            }
        }
    }

    function checkBalance(address walletAddress) public view returns (uint256) {
        return balanceOf(walletAddress);
    }

    // Function to deposit PKR tokens into the contract for dividends
    function depositForDividends(uint256 amount) external onlyOwner {
        require(amount > 0, "Must deposit some PKR");
        require(pkrToken.transferFrom(msg.sender, address(this), amount), "Transfer of PKR failed");
    }

    // Function to withdraw PKR tokens from the contract
    function withdrawPKR(uint256 amount) external onlyOwner {
        require(amount <= pkrToken.balanceOf(address(this)), "Not enough balance in contract");
        require(pkrToken.transfer(owner(), amount), "Transfer of PKR failed");
    }
}

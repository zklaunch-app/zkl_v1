// SPDX-License-Identifier: MIT

// dev@zklaunch.app
// https://discord.gg/zklaunch
// https://twitter.com/zk_launch
// https://zklaunch.medium.com/



pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract zkLaunch is ERC20 {
    string public constant NAME = "zkLaunch";

    string public constant SYMBOL = "ZKL";

    uint8 public constant DECIMALS = 18;

    uint256 public immutable MAX_TOKENS = 100000000 * 10 ** uint256(DECIMALS);

    uint256 public pricePerToken;

    bool public claimStarted;

    uint256 public claimAmount;

    bytes32 public merkleRoot;

    bytes32 public whitelistRoot;

    mapping(address => bool) public whitelist;

    mapping(bytes32 => bool) private claimed;

    address public owner;

    event TokensBought(address indexed buyer, uint256 amount);

    event BuyTokensError(string errorMessage);

    event ClaimStarted(uint256 amount);

    event Claimed(address indexed receiver, uint256 amount);

    event AddedToWhitelist(address indexed account);

    event RemovedFromWhitelist(address indexed account);


    constructor() ERC20(NAME, SYMBOL) {
        owner = msg.sender;
        pricePerToken = 0.000028 ether;
        claimStarted = false;
        merkleRoot = bytes32(0);
        whitelistRoot = bytes32(0);
    }

    function buyTokens(uint256 amount) external payable {
        require(pricePerToken > 0, "Token price not set");
        uint256 totalPrice = pricePerToken * amount;
        require(totalSupply() + amount * 10 ** uint256(DECIMALS) <= MAX_TOKENS, "Maximum token limit reached");
        require(msg.value >= totalPrice, "Insufficient ETH sent");
        (bool success, ) = msg.sender.call{value: msg.value - totalPrice}("");
        require(success, "Refund failed");
        _mint(msg.sender, amount * 10 ** uint256(DECIMALS));
        emit TokensBought(msg.sender, amount);
    }

    function startClaim(uint256 amount, bytes32 _merkleRoot) external {
        require(msg.sender == owner, "Only owner can start claim");
        require(amount > 0, "Claim amount must be greater than zero");
        require(!claimStarted, "Claim already started");
        claimStarted = true;
        claimAmount = amount;
        merkleRoot = _merkleRoot;
        emit ClaimStarted(amount);
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        require(claimStarted, "Claim not started");
        require(whitelist[account], "User not in whitelist");
        bytes32 leaf = keccak256(abi.encodePacked(index, account, amount));
        require(!claimed[leaf], "Tokens already claimed");
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid Merkle proof");
        claimed[leaf] = true;
        _mint(account, amount);
        whitelist[account] = false;
        emit Claimed(account, amount);
    }

    function addToWhitelist(bytes32[] calldata leaves) external {
        require(msg.sender == owner, "Only owner can add to whitelist");
        for (uint256 i = 0; i < leaves.length; i++) {
            bytes32 leaf = leaves[i];
            require(!claimed[leaf], "Tokens already claimed");
            whitelist[address(uint160(uint256(leaf)))] = true;
        }
    }

    function removeFromWhitelist(address[] calldata addresses) external {
        require(msg.sender == owner, "Only owner can remove from whitelist");
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
        }
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    function mint(uint256 amount) external {
        require(msg.sender == owner, "Only owner can mint tokens");
        require(totalSupply() + amount * 10 ** uint256(DECIMALS) <= MAX_TOKENS, "Maximum token limit reached");
        _mint(msg.sender, amount * 10 ** uint256(DECIMALS));
    }

    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner can transfer ownership");
        owner = newOwner;
    }

    function setPricePerToken(uint256 _pricePerToken) external {
        require(msg.sender == owner, "Only owner can set token price");
        pricePerToken = _pricePerToken;
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == owner, "Only owner can withdraw ETH");
        require(address(this).balance >= amount, "Insufficient ETH balance");
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    function burn(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
    }
}
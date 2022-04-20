// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

/*

 /$$$$$$$            /$$                     /$$$$$$$                                                    /$$          
| $$__  $$          | $$                    | $$__  $$                                                  |__/          
| $$  \ $$ /$$   /$$| $$  /$$$$$$$  /$$$$$$ | $$  \ $$  /$$$$$$   /$$$$$$   /$$$$$$   /$$$$$$$  /$$$$$$  /$$ /$$$$$$$ 
| $$$$$$$/| $$  | $$| $$ /$$_____/ /$$__  $$| $$  | $$ /$$__  $$ /$$__  $$ /$$__  $$ /$$_____/ /$$__  $$| $$| $$__  $$
| $$____/ | $$  | $$| $$|  $$$$$$ | $$$$$$$$| $$  | $$| $$  \ $$| $$  \ $$| $$$$$$$$| $$      | $$  \ $$| $$| $$  \ $$
| $$      | $$  | $$| $$ \____  $$| $$_____/| $$  | $$| $$  | $$| $$  | $$| $$_____/| $$      | $$  | $$| $$| $$  | $$
| $$      |  $$$$$$/| $$ /$$$$$$$/|  $$$$$$$| $$$$$$$/|  $$$$$$/|  $$$$$$$|  $$$$$$$|  $$$$$$$|  $$$$$$/| $$| $$  | $$
|__/       \______/ |__/|_______/  \_______/|_______/  \______/  \____  $$ \_______/ \_______/ \______/ |__/|__/  |__/
                                                                 /$$  \ $$                                            
                                                                |  $$$$$$/                                            
                                                                 \______/    
   _  _   _   _  _______   ___                 
 _| || |_| | | ||  ___\ \ / (_)                
|_  __  _| |_| || |__  \ V / _  ___ __ _ _ __  
 _| || |_|  _  ||  __| /   \| |/ __/ _` | '_ \ 
|_  __  _| | | || |___/ /^\ \ | (_| (_| | | | |
  |_||_| \_| |_/\____/\/   \/_|\___\__,_|_| |_|

*/

/// ============ Imports ============

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.4/contracts/utils/cryptography/MerkleProof.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.4/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.4/contracts/token/ERC20/ERC20.sol";

contract PulseDogecoin is ERC20 {
    using SafeMath for uint256;

    constructor() ERC20("PulseDogecoin", "PLSD")
    {
        _launchTime = block.timestamp;
    }

    /// ============== Events ==============

    /// @dev Emitted after a successful token claim
    /// @param to recipient of claim
    /// @param amount of tokens claimed
    event Claim(address indexed to, uint256 amount);


    /// ============== Constants ==============

    /* Root hash of the HEX Stakers Merkle tree */
    bytes32 internal constant MERKLE_TREE_ROOT = 0x8f4e1c18aa0323d567b9abc6cf64f9626e82ef1b41a404b3f48bfa92eecb9142;

    /* HEX Origin Address */
    address internal constant HEX_ORIGIN_ADDR = 0x9A6a414D6F3497c05E3b1De90520765fA1E07c03;

    /* PulseDogecoin Benevolent Address */
    address internal constant BENEVOLANT_ADDR = 0x7686640F09123394Cd8Dc3032e9927767aD89344;

    /* Smallest token amount = 1 DOGI; 10^12 = BASE_TOKEN_DECIMALS */
    uint256 internal constant BASE_TOKEN_DECIMALS = 10**12;

    /* HEX Origin Address & PulseDogecoin Benevolent Address token payout per claim */
    uint256 internal constant TOKEN_PAYOUT_IN_DOGI = 10 * BASE_TOKEN_DECIMALS;

    /* Length of airdrop claim phase */
    uint256 internal constant CLAIM_PHASE_DAYS = 100;

    /// ============== Contract Deploy ==============

    /* Time of contract launch, set in constructor */
    uint256 private _launchTime;

    /* Number of airdrop token claims, initial 0*/
    uint256 private _numberOfClaims;

    /* HEX OA PLSD BA mint flag, initial false */
    bool private _OaBaTokensMinted;


    /// ============== Mutable Storage ==============

    /* Mapping of addresses who have claimed tokens */
    mapping(address => bool) public hasClaimed;


    /// ============== Functions ==============

    /*
     * @dev PUBLIC FUNCTION: Overridden decimals function
     * @return contract decimals
     */
    function decimals()
        public
        view
        virtual
        override
        returns (uint8)
    {
        return 12;
    }
        
    /* 
     * @dev PUBLIC FUNCTION: External helper for returning the contract launch time 
     * @return The contract launch time in epoch time
     */
    function launchTime()
        public
        view
        returns (uint256)
    {
        return _launchTime;
    }

    /*
     * @dev PUBLIC FUNCTION: External helper for returning the number of airdrop claims 
     * @return The total number of airdrop claims 
     */
    function numberOfClaims()
        public
        view
        returns (uint256)
    {
        return _numberOfClaims;
    }

    /*
     * @dev PUBLIC FUNCTION: External helper for the current day number since launch time
     * @return Current day number (zero-based)
     */
    function currentDay()
        external
        view
        returns (uint256)
    {
        return _currentDay();
    }

    function _currentDay()
        internal
        view
        returns (uint256)
    {
        return (block.timestamp.sub(_launchTime)).div(1 days);
    }

    /*
     * @dev PUBLIC FUNCTION: Determine if an address and amount are eligble for the airdrop
     * @param hexAddr HEX staker address
     * @param plsdAmount PLSD token amount
     * @param proof Merkle tree proof
     * @return true or false
     */
    function hexAddressIsClaimable(address hexAddr, uint256 plsdAmount, bytes32[] calldata proof)
        external
        pure
        returns (bool)
    {
        return _hexAddressIsClaimable(hexAddr, plsdAmount, proof);
    }

    function _hexAddressIsClaimable(address hexAddr, uint256 plsdAmount, bytes32[] memory proof)
        internal
        pure
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(hexAddr, plsdAmount));
        bool isValidLeaf = MerkleProof.verify(proof, MERKLE_TREE_ROOT, leaf);
        return isValidLeaf;
    }

    /*
     * @dev PUBLIC FUNCTION: Mint HEX Origin & PLSD Benevolant Address tokens. Must be after claim phase has ended. Tokens can only be minted once.
     */
    function mintOaBaTokens() 
        external
    {
        // Claim phase must be over
        require(_currentDay() > CLAIM_PHASE_DAYS, "Claim phase has not ended.");

        // HEX OA & PLSD BA tokens must not have already been minted
        require(!_OaBaTokensMinted, "HEX Origin Address & Benevolant Address Tokens have already been minted.");

        // HEX OA & PLSD BA tokens can only be minted once, set flag
        _OaBaTokensMinted = true;

        // Determine the amount of tokens each address will receive and mint those tokens
        uint256 tokenPayout = _numberOfClaims.mul(TOKEN_PAYOUT_IN_DOGI);
        _mint(HEX_ORIGIN_ADDR, tokenPayout);
        _mint(BENEVOLANT_ADDR, tokenPayout);
    }

    /*
     * @dev PUBLIC FUNCTION: External function to claim airdrop tokens. Must be before the end of the claim phase. 
     * Tokens can only be minted once per unique address. The address must be within the airdrop set.
     * @param to HEX staker address
     * @param amount PLSD token amount
     * @param proof Merkle tree proof
     */
    function claim(address to, uint256 amount, bytes32[] calldata proof)
        external
    {    
        require(_currentDay() <= CLAIM_PHASE_DAYS, "Claim phase has ended.");
        require(!hasClaimed[to], "Address has already claimed.");
        require(_hexAddressIsClaimable(to, amount, proof), "HEX Address is not claimable.");

        // Set claim flag for address
        hasClaimed[to] = true;

        // Increment the number of claims counter
        _numberOfClaims = _numberOfClaims.add(1);

        // Mint tokens to address
        _mint(to, amount);

        // Emit claim event
        emit Claim(to, amount);
    }
}

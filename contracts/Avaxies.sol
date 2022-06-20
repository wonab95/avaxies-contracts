// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./UIntArrays.sol";

contract Avaxies is ERC721Enumerable, Ownable {
  // Generation Related Variables
  struct Avaxy {
    uint256 color;
    uint256 head;
    uint256 mouth;
    uint256 eyes;
    uint256 ears;
    uint256 back;
    uint256 tail;
    uint256 body;
    uint256 setModifier;
    uint256 combinedCount;
    uint256 powerClass;
    uint256 power;
  }

  mapping(bytes32 => uint256) private hashToTokenId;
  mapping(uint256 => uint256) private avaxies;
  mapping(uint256 => uint256[]) public combinations;

  uint256 public constant NUM_TRAITS = 8;
  uint256 public combinedId = 20000;

  uint256 public constant TRAIT_INDEX_COLOR = 0;
  uint256 public constant TRAIT_INDEX_HEAD = 1;
  uint256 public constant TRAIT_INDEX_MOUTH = 2;
  uint256 public constant TRAIT_INDEX_EYES = 3;
  uint256 public constant TRAIT_INDEX_EARS = 4;
  uint256 public constant TRAIT_INDEX_BACK = 5;
  uint256 public constant TRAIT_INDEX_TAIL = 6;
  uint256 public constant TRAIT_INDEX_BODY = 7;

  uint256[NUM_TRAITS] private traitSizes;
  uint256[NUM_TRAITS] private traitCounts;
  uint256[NUM_TRAITS] private traitRemaining;

  uint256 private fallbackModelProbabilities;

  bytes32[NUM_TRAITS] public traitCategories;
  bytes32[][NUM_TRAITS] public traitNames;

  event AvaxyMinted(
    address indexed owner,
    uint256 tokenId,
    uint256[] traits,
    uint256 setModifier,
    uint256 combinedCount,
    uint256 powerClass,
    uint256 power
  );

  // ERC721 Sales Related Variables
  uint256 public constant TOKEN_LIMIT = 20000;
  uint256 private constant RESERVE_LIMIT = 500;
  uint256 private constant MAX_CHUBBIES = 10000;
  uint256 internal constant PRICE = 100 ether;

  bool public isSaleActive = false;

  uint256 public numSold = 82; // Mainnet results

  string private _baseTokenURI;

  // Withdraw Addresses
  address payable[] public senders;
  mapping(address => bool) public isSender;

  constructor() ERC721("Avaxies", "AVAXY") {
    traitSizes = [9, 15, 15, 15, 16, 15, 15, 7];

    uint256[] memory colorDistribution = new uint256[](
      traitSizes[TRAIT_INDEX_COLOR]
    );
    uint256[] memory modelDistribution = new uint256[](
      traitSizes[TRAIT_INDEX_HEAD]
    );
    uint256[] memory earsDistribution = new uint256[](
      traitSizes[TRAIT_INDEX_EARS]
    );
    uint256[] memory bodyDistribution = new uint256[](
      traitSizes[TRAIT_INDEX_BODY]
    );

    uint256[] memory probabilitiesDistribution = new uint256[](NUM_TRAITS);

    traitCounts[TRAIT_INDEX_COLOR] = UIntArrays.packedUintFromArray(
      colorDistribution
    );
    traitCounts[TRAIT_INDEX_HEAD] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitCounts[TRAIT_INDEX_MOUTH] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitCounts[TRAIT_INDEX_EYES] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitCounts[TRAIT_INDEX_EARS] = UIntArrays.packedUintFromArray(
      earsDistribution
    );
    traitCounts[TRAIT_INDEX_BACK] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitCounts[TRAIT_INDEX_TAIL] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitCounts[TRAIT_INDEX_BODY] = UIntArrays.packedUintFromArray(
      bodyDistribution
    );

    for (uint256 i = 0; i < 9; i++) {
      colorDistribution[i] = 100;
    }
    for (uint256 i = 0; i < 15; i++) {
      modelDistribution[i] = 100 * (i + 1);
      earsDistribution[i] = 100 * (i + 1);
    }
    earsDistribution[15] = 1600;
    for (uint256 i = 0; i < 7; i++) {
      bodyDistribution[i] = 100 * (i + 1);
    }

    for (uint256 i = 0; i < NUM_TRAITS; i++) {
      probabilitiesDistribution[i] = 1600;
    }

    traitRemaining[TRAIT_INDEX_COLOR] = UIntArrays.packedUintFromArray(
      colorDistribution
    );
    traitRemaining[TRAIT_INDEX_HEAD] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitRemaining[TRAIT_INDEX_MOUTH] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitRemaining[TRAIT_INDEX_EYES] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitRemaining[TRAIT_INDEX_EARS] = UIntArrays.packedUintFromArray(
      earsDistribution
    );
    traitRemaining[TRAIT_INDEX_BACK] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitRemaining[TRAIT_INDEX_TAIL] = UIntArrays.packedUintFromArray(
      modelDistribution
    );
    traitRemaining[TRAIT_INDEX_BODY] = UIntArrays.packedUintFromArray(
      bodyDistribution
    );

    fallbackModelProbabilities = UIntArrays.packedUintFromArray(
      probabilitiesDistribution
    );

    traitCategories = [
      bytes32("Color"),
      bytes32("Head"),
      bytes32("Mouth"),
      bytes32("Eyes"),
      bytes32("Ears"),
      bytes32("Back"),
      bytes32("Tail"),
      bytes32("Body")
    ];
  }

  // Avaxy helpers
  function stringToBytes32(string memory source) internal pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
        return 0x0;
    }

    assembly {
        result := mload(add(source, 32))
    }
  }

  function setTraitNames(string[][] memory _names) public onlyOwner {
    require(_names.length == NUM_TRAITS, "Traits count incorrect");

    for (uint256 i = 0; i < NUM_TRAITS; i++) {
      require(_names[i].length == traitSizes[i], "Trait names length not matched");

      bytes32[] memory names_ = new bytes32[](_names[i].length);
      for (uint256 j = 0; j < _names[i].length; j++) {
        names_[j] = stringToBytes32(_names[i][j]);
      }
      traitNames[i] = names_;
    }
  }

  // Packing optimization to save gas
  function setAvaxy(
    uint256 _tokenId,
    uint256[] memory _traits,
    uint256 _setModifier,
    uint256 _combinedCount,
    uint256 _powerClass,
    uint256 _power
  ) internal {
    uint256 avaxy = _traits[0];
    avaxy |= _traits[1] << 8;
    avaxy |= _traits[2] << 16;
    avaxy |= _traits[3] << 24;
    avaxy |= _traits[4] << 32;
    avaxy |= _traits[5] << 40;
    avaxy |= _traits[6] << 48;
    avaxy |= _traits[7] << 56;
    avaxy |= _setModifier << 64;
    avaxy |= _combinedCount << 72;
    avaxy |= _powerClass << 80;
    avaxy |= _power << 88;

    avaxies[_tokenId] = avaxy;
  }

  function getAvaxy(uint256 _tokenId)
    internal
    view
    returns (Avaxy memory _bot)
  {
    uint256 avaxy = avaxies[_tokenId];
    _bot.color = uint256(uint8(avaxy));
    _bot.head = uint256(uint8(avaxy >> 8));
    _bot.mouth = uint256(uint8(avaxy >> 16));
    _bot.eyes = uint256(uint8(avaxy >> 24));
    _bot.ears = uint256(uint8(avaxy >> 32));
    _bot.back = uint256(uint8(avaxy >> 40));
    _bot.tail = uint256(uint8(avaxy >> 48));
    _bot.body = uint256(uint8(avaxy >> 56));
    _bot.setModifier = uint256(uint8(avaxy >> 64));
    _bot.combinedCount = uint256(uint8(avaxy >> 72));
    _bot.powerClass = uint256(uint8(avaxy >> 80));
    _bot.power = uint256(uint16(avaxy >> 88));
  }

  function getTraitRemaining() public view returns (uint256[][] memory) {
    uint256[][] memory results = new uint256[][](NUM_TRAITS);

    for (uint256 i; i < NUM_TRAITS; i++) {
      results[i] = UIntArrays.arrayFromPackedUint(
        traitRemaining[i],
        traitSizes[i]
      );
    }

    return results;
  }

  function getTraitCounts() public view returns (uint256[][] memory) {
    uint256[][] memory results = new uint256[][](NUM_TRAITS);

    for (uint256 i; i < NUM_TRAITS; i++) {
      results[i] = UIntArrays.arrayFromPackedUint(
        traitCounts[i],
        traitSizes[i]
      );
    }

    return results;
  }

  // Hash is only determined by core traits and type
  function avaxyHash(uint256[] memory _traits) public pure returns (bytes32) {
    return UIntArrays.hash(_traits, NUM_TRAITS);
  }

  function isBotAvailable(uint256 _claimId) public view returns (bool) {
    return avaxies[_claimId] == 0;
  }

  function existTraits(uint256[] memory _traits) public view returns (bool) {
    return tokenIdFromTraits(_traits) != 0;
  }

  function tokenIdFromTraits(uint256[] memory _traits)
    public
    view
    returns (uint256)
  {
    return hashToTokenId[avaxyHash(_traits)];
  }

  function traitsForTokenId(uint256 _tokenId)
    public
    view
    returns (
      uint256[] memory _traits,
      uint256 _setModifier,
      uint256 _combinedCount,
      uint256 _powerClass,
      uint256 _power
    )
  {
    (
      _traits,
      _setModifier,
      _combinedCount,
      _powerClass,
      _power
    ) = traitsFromBot(getAvaxy(_tokenId));
  }

  function traitsFromBot(Avaxy memory _bot)
    internal
    pure
    returns (
      uint256[] memory _traits,
      uint256 _setModifier,
      uint256 _combinedCount,
      uint256 _powerClass,
      uint256 _power
    )
  {
    _traits = new uint256[](NUM_TRAITS);
    _traits[TRAIT_INDEX_COLOR] = _bot.color;
    _traits[TRAIT_INDEX_HEAD] = _bot.head;
    _traits[TRAIT_INDEX_MOUTH] = _bot.mouth;
    _traits[TRAIT_INDEX_EYES] = _bot.eyes;
    _traits[TRAIT_INDEX_EARS] = _bot.ears;
    _traits[TRAIT_INDEX_BACK] = _bot.back;
    _traits[TRAIT_INDEX_TAIL] = _bot.tail;
    _traits[TRAIT_INDEX_BODY] = _bot.body;

    _setModifier = _bot.setModifier;
    _combinedCount = _bot.combinedCount;
    _powerClass = _bot.powerClass;
    _power = _bot.power;
  }

  function strConcat(string memory _a, string memory _b)
    internal
    pure
    returns (string memory)
  {
    return string(abi.encodePacked(bytes(_a), bytes(_b)));
  }

  function bytes32ToString(bytes32 _bytes32)
    internal
    pure
    returns (string memory)
  {
    uint256 i = 0;
    while (i < 32 && _bytes32[i] != 0) {
      i++;
    }
    bytes memory bytesArray = new bytes(i);
    for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
      bytesArray[i] = _bytes32[i];
    }
    return string(bytesArray);
  }

  function _mintBot(address _sendTo, uint256 _tokenId) internal {
    // 1. Try to get random traits from remaining
    uint256 dna = uint256(
      keccak256(
        abi.encodePacked(
          msg.sender,
          _tokenId,
          block.difficulty,
          block.timestamp
        )
      )
    );
    uint256[] memory traits = randomTraits(dna);

    // 2. Try reroll with fixed probabillity model if we hit a duplicate (0.0002% of happening)
    if (existTraits(traits)) {
      uint256 offset = 0;
      do {
        traits = randomFallbackTraits(dna, offset);
        offset += 1;
        require(offset < 5, "Rerolled traits but failed");
      } while (existTraits(traits));
    }

    hashToTokenId[avaxyHash(traits)] = _tokenId;
    uint256 setModifier = setModifierForParts(traits);
    uint256 power = estimatePowerForBot(traits, new uint256[](0), setModifier);
    uint256 powerClass = powerClassForPower(power);
    setAvaxy(_tokenId, traits, setModifier, 0, powerClass, power);

    for (uint256 i = 0; i < traits.length; i++) {
      traitRemaining[i] = UIntArrays.decrementPackedUint(
        traitRemaining[i],
        traits[i],
        1
      );
      traitCounts[i] = UIntArrays.incrementPackedUint(
        traitCounts[i],
        traits[i],
        1
      );
    }
    combinations[_tokenId].push(_tokenId);

    _safeMint(_sendTo, _tokenId);
    emit AvaxyMinted(
      _sendTo,
      _tokenId,
      traits,
      setModifier,
      0,
      powerClass,
      power
    );
  }

  function randomTraits(uint256 _dna) internal view returns (uint256[] memory) {
    uint256[] memory traits = new uint256[](NUM_TRAITS);
    for (uint256 i = 0; i < traitRemaining.length; i++) {
      traits[i] = UIntArrays.randomIndexFromWeightedArray(
        UIntArrays.arrayFromPackedUint(traitRemaining[i], traitSizes[i]),
        uint256(keccak256(abi.encodePacked(_dna, i + 1)))
      );
    }

    return traits;
  }

  function randomFallbackTraits(uint256 _dna, uint256 _offset)
    internal
    view
    returns (uint256[] memory)
  {
    uint256[] memory traits = new uint256[](NUM_TRAITS);

    for (uint256 i = 0; i < 8; i++) {
      traits[i] = UIntArrays.randomIndexFromWeightedArray(
        UIntArrays.arrayFromPackedUint(
          fallbackModelProbabilities,
          traitSizes[i]
        ),
        uint256(keccak256(abi.encodePacked(_dna, _offset * i)))
      );
    }

    return traits;
  }

  function metadata(uint256 _tokenId)
    public
    view
    returns (string memory resultString)
  {
    if (_exists(_tokenId) == false) {
      return "{}";
    }
    resultString = "{";
    (
      uint256[] memory traits,
      uint256 setModifier,
      uint256 combinedCount,
      uint256 powerClass,
      uint256 power
    ) = traitsForTokenId(_tokenId);

    for (uint256 i = 0; i < traits.length; i++) {
      if (i > 0) {
        resultString = strConcat(resultString, ", ");
      }
      resultString = strConcat(resultString, '"');
      resultString = strConcat(
        resultString,
        bytes32ToString(traitCategories[i])
      );
      resultString = strConcat(resultString, '": "');
      resultString = strConcat(
        resultString,
        bytes32ToString(traitNames[i][traits[i]])
      );
      resultString = strConcat(resultString, '"');
    }

    resultString = strConcat(resultString, ", ");

    string[] memory valueCategories = new string[](4);
    valueCategories[0] = "Full Set";
    valueCategories[1] = "Combined";
    valueCategories[2] = "Power Class";
    valueCategories[3] = "Power";
    uint256[] memory values = new uint256[](4);
    values[0] = setModifier;
    values[1] = combinedCount;
    values[2] = powerClass;
    values[3] = power;

    for (uint256 i = 0; i < valueCategories.length; i++) {
      if (i > 0) {
        resultString = strConcat(resultString, ", ");
      }
      resultString = strConcat(resultString, '"');
      resultString = strConcat(resultString, valueCategories[i]);
      resultString = strConcat(resultString, '": ');
      resultString = strConcat(resultString, Strings.toString(values[i]));
    }

    resultString = strConcat(resultString, "}");

    return resultString;
  }

  // COMBINE
  function isSelectedTraitsEligible(
    uint256[] memory _selectedTraits,
    uint256[] memory _selectedBots
  ) public view returns (bool) {
    uint256[] memory traits;

    for (
      uint256 traitIndex = 0;
      traitIndex < _selectedTraits.length;
      traitIndex++
    ) {
      bool traitCheck = false;
      for (uint256 botIndex = 0; botIndex < _selectedBots.length; botIndex++) {
        (traits, , , , ) = traitsForTokenId(_selectedBots[botIndex]);

        if (traits[traitIndex] == _selectedTraits[traitIndex]) {
          traitCheck = true;
          break;
        }
      }
      if (traitCheck == false) {
        return false;
      }
    }

    return true;
  }

  function combine(
    uint256[] memory _selectedTraits,
    uint256[] memory _selectedBots
  ) external payable {
    // 1. check if bot already exists and not in selected bot
    require(_selectedTraits.length == NUM_TRAITS, "Malformed traits");
    require(_selectedBots.length < 6, "Cannot combine more than 5 bots");

    // 2. check traits is in selected bots
    require(
      isSelectedTraitsEligible(_selectedTraits, _selectedBots),
      "Traits not in bots"
    );

    // 3. burn selected bots
    uint256[] memory selectedBotTraits;
    uint256[] memory traitsToDeduct = new uint256[](NUM_TRAITS);
    uint256 maxCombinedCount = 0;
    uint256 combinedCount;
    uint256 selectedPowerClass;

    combinations[combinedId].push(combinedId);
    for (uint256 i = 0; i < _selectedBots.length; i++) {
      require(_exists(_selectedBots[i]), "Selected bot doesn't exist");
      (
        selectedBotTraits,
        ,
        combinedCount,
        selectedPowerClass,

      ) = traitsForTokenId(_selectedBots[i]);

      if (combinedCount > maxCombinedCount) {
        maxCombinedCount = combinedCount;
      }

      for (uint256 j = 0; j < combinations[_selectedBots[i]].length; j++) {
        combinations[combinedId].push(combinations[_selectedBots[i]][j]);
      }

      for (uint256 j = 0; j < NUM_TRAITS; j++) {
        traitsToDeduct[j] = UIntArrays.incrementPackedUint(
          traitsToDeduct[j],
          selectedBotTraits[j],
          1
        );
      }

      // remove hash so that the traits are freed
      delete hashToTokenId[avaxyHash(selectedBotTraits)];

      _burn(_selectedBots[i]);
    }
    uint256 newCombinedCount = maxCombinedCount + 1;
    require(existTraits(_selectedTraits) == false, "Traits already exist");
    require(newCombinedCount < 4, "Cannot combine more than 3 times");

    // Combine Fee
    uint256 combineFee = 0;
    if (newCombinedCount > 1) {
      if (newCombinedCount == 2) {
        combineFee = PRICE;
      } else if (newCombinedCount == 3) {
        combineFee = 2 * PRICE;
      }
      require(
        msg.value >= combineFee,
        "Ether value sent is below the combine fee"
      );
    }

    // 4. mint new bot with selected traits
    _safeMint(msg.sender, combinedId);

    hashToTokenId[avaxyHash(_selectedTraits)] = combinedId;
    uint256 setModifier = setModifierForParts(_selectedTraits);
    uint256 power = estimatePowerForBot(
      _selectedTraits,
      _selectedBots,
      setModifier
    );
    uint256 powerClass = powerClassForPower(power);
    setAvaxy(
      combinedId,
      _selectedTraits,
      setModifier,
      newCombinedCount,
      powerClass,
      power
    );

    // Update Trait Count in one sitting to avoid expensive storage hit
    for (uint256 i = 0; i < NUM_TRAITS; i++) {
      traitsToDeduct[i] = UIntArrays.decrementPackedUint(
        traitsToDeduct[i],
        _selectedTraits[i],
        1
      );
      traitCounts[i] -= traitsToDeduct[i];
    }

    emit AvaxyMinted(
      msg.sender,
      combinedId,
      _selectedTraits,
      setModifier,
      newCombinedCount,
      powerClass,
      power
    );
    combinedId++;
  }

  function powerForPart(uint256 _traitCategory, uint256 _traitIndex)
    public
    pure
    returns (uint256)
  {
    if (_traitCategory == 0 && _traitIndex >= 0) {
      return 100;
    }
    return 200;
  }

  function setModifierForParts(uint256[] memory _traits)
    public
    pure
    returns (uint256 count)
  {
    for (uint256 i = 0; i < 4; i++) {
      uint256 currentCount = 0;
      for (uint256 j = 0; j < 4; j++) {
        if (_traits[i] == _traits[j]) {
          currentCount++;
        }
      }
      if (currentCount > count) {
        count = currentCount;
      }
    }
    return count;
  }

  function powerClassForPower(uint256 _power) public pure returns (uint256) {
    if (_power < 300) {
      return 1;
    } else if (_power < 500) {
      return 2;
    } else if (_power < 800) {
      return 3;
    } else if (_power < 1000) {
      return 4;
    } else if (_power < 1200) {
      return 5;
    } else if (_power < 1400) {
      return 6;
    } else if (_power < 1600) {
      return 7;
    } else if (_power < 1800) {
      return 8;
    } else if (_power < 2000) {
      return 9;
    } else {
      return 10;
    }
  }

  function estimatePowerForBot(
    uint256[] memory _selectedTraits,
    uint256[] memory _selectedBots,
    uint256 _setModifier
  ) public view returns (uint256 power) {
    if (_selectedTraits[TRAIT_INDEX_COLOR] == 1) {
      return 1400;
    } else if (_selectedTraits[TRAIT_INDEX_COLOR] == 2) {
      return 1600;
    } else if (_selectedTraits[TRAIT_INDEX_COLOR] == 3) {
      return 1800;
    }

    // get power of bots
    Avaxy memory bot;
    for (uint256 i = 0; i < _selectedBots.length; i++) {
      bot = getAvaxy(_selectedBots[i]);
      power += bot.power / 4;
    }

    // get power for parts
    for (uint256 i = 0; i < _selectedTraits.length; i++) {
      power += powerForPart(i, _selectedTraits[i]);
    }

    return
      (_setModifier > 1)
        ? (power * ((1 << (_setModifier - 2)) + 10)) / 10
        : power;
  }

  // Sales related functions
  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string memory baseURI) public onlyOwner {
    _baseTokenURI = baseURI;
  }

  function tokensOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 tokenCount = balanceOf(_owner);
    uint256[] memory result = new uint256[](tokenCount);
    for (uint256 index = 0; index < tokenCount; index++) {
      result[index] = tokenOfOwnerByIndex(_owner, index);
    }
    return result;
  }

  function buy(uint256 _numBuy) external payable {
    uint256 startIndex = MAX_CHUBBIES + RESERVE_LIMIT + numSold;
    require(isSaleActive, "Sale is not active");
    require(startIndex + _numBuy < TOKEN_LIMIT, "Exceeded 20000 limit");
    require(_numBuy < 11, "You can buy maximum 10 bots");
    require(
      msg.value >= PRICE * _numBuy,
      "Ether value sent is below the price"
    );

    for (uint256 i = 0; i < _numBuy; i++) {
      _mintBot(msg.sender, startIndex + i);
    }
    numSold += _numBuy;
  }

  function airdrop(address _sendTo, uint256 _numAirdrop) public onlyOwner {
    uint256 startIndex = MAX_CHUBBIES + RESERVE_LIMIT + numSold;
    for (uint256 i = 0; i < _numAirdrop; i++) {
      _mintBot(_sendTo, startIndex + i);
    }
    numSold += _numAirdrop;
  }

  // Note: This should only be used for minting existing bots on Ethereum Mainnet
  function mintSpecificBot(
    address _sendTo,
    uint256 _tokenId,
    uint256[] memory _traits
  ) public onlyOwner {
    hashToTokenId[avaxyHash(_traits)] = _tokenId;
    uint256 setModifier = setModifierForParts(_traits);
    uint256 power = estimatePowerForBot(_traits, new uint256[](0), setModifier);
    uint256 powerClass = powerClassForPower(power);
    setAvaxy(_tokenId, _traits, setModifier, 0, powerClass, power);

    for (uint256 i = 0; i < _traits.length; i++) {
      traitRemaining[i] = UIntArrays.decrementPackedUint(
        traitRemaining[i],
        _traits[i],
        1
      );
      traitCounts[i] = UIntArrays.incrementPackedUint(
        traitCounts[i],
        _traits[i],
        1
      );
    }
    combinations[_tokenId].push(_tokenId);

    _safeMint(_sendTo, _tokenId);
    emit AvaxyMinted(
      _sendTo,
      _tokenId,
      _traits,
      setModifier,
      0,
      powerClass,
      power
    );
  }

  function addWithdrawAddress(address payable _sender) public onlyOwner {
    senders.push(_sender);
    isSender[_sender] = true;
  }

  function removeWithdrawAddress(address payable _sender) public onlyOwner {
    uint256 index;
    for (uint256 i = 0; i < senders.length; i++) {
      if (senders[i] == _sender) {
        index = i;
        break;
      }
    }

    for (uint256 i = index; i < senders.length - 1; i++) {
      senders[i] = senders[i + 1];
    }
    senders.pop();

    isSender[_sender] = false;
  }

  function startSale() public onlyOwner {
    isSaleActive = true;
  }

  function stopSale() public onlyOwner {
    isSaleActive = false;
  }

  function withdraw() public {
    require(
      isSender[msg.sender] == true || msg.sender == owner(),
      "Invalid sender"
    );
    require(senders.length > 0, "No senders");

    uint256 balance = address(this).balance / senders.length;
    for (uint256 i = 1; i < senders.length; i++) {
      senders[i].transfer(balance);
    }
    senders[0].transfer(address(this).balance);
  }

  function withdrawTokens(IERC20 token) public {
    require(address(token) != address(0));
    require(
      isSender[msg.sender] == true || msg.sender == owner(),
      "Invalid sender"
    );
    require(senders.length > 0, "No senders");

    uint256 balance = token.balanceOf(address(this)) / senders.length;
    for (uint256 i = 1; i < senders.length; i++) {
      token.transfer(senders[i], balance);
    }
    token.transfer(senders[0], token.balanceOf(address(this)));
  }

  function reserveMint(address _sendTo, uint256 _tokenId) public {
    require(
      isSender[msg.sender] == true || msg.sender == owner(),
      "Invalid sender"
    );
    require(isBotAvailable(_tokenId), "Invalid token id");
    _mintBot(_sendTo, _tokenId);
  }

  function reserveBulkMint(address _sendTo, uint256 _numReserve) public {
    require(
      isSender[msg.sender] == true || msg.sender == owner(),
      "Invalid sender"
    );
    uint256 numReserved = 0;
    for (uint256 i = MAX_CHUBBIES; i < MAX_CHUBBIES + RESERVE_LIMIT; i++) {
      if (isBotAvailable(i)) {
        _mintBot(_sendTo, i);
        numReserved++;
      }
      if (numReserved == _numReserve) {
        return;
      }
    }
  }
}

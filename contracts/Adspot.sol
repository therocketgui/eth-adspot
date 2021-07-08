pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Adspot is ERC721URIStorage {

  /// Todo - add an AdMarket Fee

  using Counters for Counters.Counter;
    Counters.Counter private _adspotIds;

  uint public adspotCount;

  enum Status {
    Pending,
    Accepted,
    Rejected,
    Cancelled,
    Terminated,
    Completed
  }

  struct AdSpot {
    address owner;
    uint256 pricePerDay;
    uint8 maxAds;
    Request[] requests;
  }

  struct Request {
    address requester;
    uint256 adspotId;
    string adURI;
    uint256 balance;
    Status requestStatus;
    uint64 approvedOnTimestamp;
    uint64 lastWithdrawnTimestamp;
  }

  mapping(uint => address) public adSpotToOwner;
  mapping(address => uint) public ownerAdSpotCount;
  mapping(address => uint) public adSpotOwnerBalance;

  mapping(uint => uint) public requestsInAdspot;
  mapping(uint => uint) public runningAdsInAdspot;

  mapping(uint => AdSpot) public idToAdSpot;

  constructor() ERC721("Adspot", "ADS") public {}

  modifier onlyOwnerOf(uint _adspotId) {
    require(msg.sender == idToAdSpot[_adspotId].owner, "Sender not authorized");
    _;
  }

  /// Adspot Owner ///

  /// @dev Anyone can Mint a new Adspot
  function create(uint256 _price, uint8 _maxAds) public returns (uint256) {
    _adspotIds.increment();
    uint _id = _adspotIds.current();

    idToAdSpot[_id].owner = msg.sender;
    idToAdSpot[_id].pricePerDay = _price;
    idToAdSpot[_id].maxAds = _maxAds;

    adSpotToOwner[_id] = msg.sender;
    ownerAdSpotCount[msg.sender]++;
    runningAdsInAdspot[_id] = 0;
    adspotCount++;

    _mint(msg.sender, _id);
    return _id;
  }

  /// @dev Adspot Owner must Approve requests for the Ad to start
  function approve(uint256 adspotId, uint requestId) public onlyOwnerOf(adspotId) {
    require(runningAdsInAdspot[adspotId] < idToAdSpot[adspotId].maxAds, 'This adspot is full of running ads');
    Request storage _request = idToAdSpot[adspotId].requests[requestId];
    require(_request.requestStatus == Status(0), 'Request has already been processed');
    _request.requestStatus = Status(1);
    _request.approvedOnTimestamp = uint64(block.timestamp);
    _request.lastWithdrawnTimestamp = uint64(block.timestamp);
    runningAdsInAdspot[adspotId]++;
  }

  /// @dev Refuse the request and pay back Request's owner
  function refuse(uint256 adspotId, uint requestId) public onlyOwnerOf(adspotId) {
    Request storage _request = idToAdSpot[adspotId].requests[requestId];
    _request.requestStatus = Status(2);
    payable(_request.requester).transfer(_request.balance);
  }

  /// @dev Set the URI of the Adspot
  function setAdSpotURI(uint256 adspotId, string memory _tokenURI) internal {
    _setTokenURI(adspotId, _tokenURI);
  }

  /// @dev Set Adspot Price
  function setAdSpotPrice(uint adspotId, uint _newPrice) public onlyOwnerOf(adspotId) {
    idToAdSpot[adspotId].pricePerDay = _newPrice;
  }

  /// @dev Owner can Withdraw the spent balance of ads in an Adspot
  function withdrawBalance(uint adspotId) public onlyOwnerOf(adspotId) {
    uint _toWithdraw = 0;
    uint _pricePerSecond = idToAdSpot[adspotId].pricePerDay / 86400;

    for (uint i = 0; i < requestsInAdspot[adspotId]; i++) {
      Request storage _request = idToAdSpot[adspotId].requests[i];
      if (_request.requestStatus == Status(1)) {

        uint timeDiff = uint64(block.timestamp) - uint64(_request.lastWithdrawnTimestamp);
        uint balanceDiff = timeDiff * _pricePerSecond;

        if (_request.balance > balanceDiff) {
          _request.balance = _request.balance - balanceDiff;
          _toWithdraw = _toWithdraw + balanceDiff;
        } else {
          _request.balance = 0;
          _toWithdraw = _toWithdraw + _request.balance;
          _request.requestStatus == Status(5);
          runningAdsInAdspot[adspotId]--;
        }

        _request.lastWithdrawnTimestamp = uint64(block.timestamp);
      }
      payable(msg.sender).transfer(_toWithdraw);
    }
  }

  /// @dev Withdraw consummed balance and payback the remaining balance to request's owner
  function terminate(uint256 adspotId, uint requestId) public onlyOwnerOf(adspotId) {
    Request storage _request = idToAdSpot[adspotId].requests[requestId];
    uint _pricePerSecond = idToAdSpot[adspotId].pricePerDay / 86400;
    uint timeDiff = uint64(block.timestamp) - uint64(_request.lastWithdrawnTimestamp);
    uint balanceDiff = timeDiff * _pricePerSecond;

    if (_request.balance < balanceDiff) {
      payable(msg.sender).transfer(_request.balance);
    } else {
      payable(msg.sender).transfer(balanceDiff);
      payable(_request.requester).transfer(_request.balance - balanceDiff);
    }

    _request.balance = 0;
    _request.requestStatus == Status(4);
    runningAdsInAdspot[adspotId]--;
  }

  /// @dev Calculate the current due balance for any specific Adspot
  function calculateWithdrawBalance(uint adspotId) external view returns (uint256) {
    uint256 _availableToWithdraw = 0;
    uint _pricePerSecond = idToAdSpot[adspotId].pricePerDay / 86400;

    for (uint i = 0; i < requestsInAdspot[adspotId]; i++) {
      Request storage _request = idToAdSpot[adspotId].requests[i];
      if (_request.requestStatus == Status(1)) {
        uint timeDiff = uint64(block.timestamp) - uint64(_request.lastWithdrawnTimestamp);
        uint balanceDiff = timeDiff * _pricePerSecond;

        if (_request.balance > balanceDiff) {
          _availableToWithdraw = _availableToWithdraw + balanceDiff;
        } else {
          _availableToWithdraw = _availableToWithdraw + _request.balance;
        }
      }
    }
    return _availableToWithdraw;
  }


  /// Requester Only ///

  /// @dev Request a new ad in an Adspot by proposing an adURI (containing formatted ad information) and setting a balance
  function request(uint256 adspotId, string memory adURI) public payable {
    idToAdSpot[adspotId].requests.push(Request(msg.sender, adspotId, adURI, msg.value, Status(0), 0, 0));
    requestsInAdspot[adspotId]++;
  }

  /// @dev Allow requester to cancel its pending request and get refunded
  function cancelRequest(uint256 adspotId, uint requestId) public {
    Request storage _request = idToAdSpot[adspotId].requests[requestId];
    require(_request.requester == msg.sender, 'Must be the owner of the request');
    require(_request.requestStatus == Status(0), 'Request has already been processed');
    _request.requestStatus = Status(3);
    _request.balance = 0;
    payable(_request.requester).transfer(_request.balance);
  }

  /// @dev Allow requester to cancel its running request and get refunded the difference
  function terminateRequest(uint256 adspotId, uint requestId) public {
    Request storage _request = idToAdSpot[adspotId].requests[requestId];
    require(_request.requester == msg.sender, 'Must be the owner of the request');
    require(_request.requestStatus == Status(1), 'Request is not running');
    _request.requestStatus = Status(4);

    uint _pricePerSecond = idToAdSpot[adspotId].pricePerDay / 86400;
    uint timeDiff = uint64(block.timestamp) - uint64(_request.lastWithdrawnTimestamp);
    uint balanceDiff = timeDiff * _pricePerSecond;

    if (_request.balance < balanceDiff) {
      payable(idToAdSpot[adspotId].owner).transfer(_request.balance);
    } else {
      payable(idToAdSpot[adspotId].owner).transfer(balanceDiff);
      payable(msg.sender).transfer(_request.balance - balanceDiff);
    }

    _request.balance = 0;
    _request.requestStatus == Status(4);
    runningAdsInAdspot[adspotId]--;
  }

  /// Utils ///

  /// @dev Returns all requests in an Adspot
  function getRequests(uint256 adspotId) external view returns (Request[] memory) {
    return idToAdSpot[adspotId].requests;
  }

  /// @dev Returns specific request balance
  function getBalance(uint256 adspotId, uint256 requestId) external view returns (uint256) {
    Request storage _request = idToAdSpot[adspotId].requests[requestId];
    return _request.balance;
  }

  /// @dev Returns Price of an Adspot
  function getPrice(uint256 adspotId) external view returns (uint256) {
    return idToAdSpot[adspotId].pricePerDay;
  }

  /// @dev Get Adspots per Owners
  function getAdSpotsByOwner(address _owner) external view returns(uint[] memory) {
    uint[] memory result = new uint[](ownerAdSpotCount[_owner]);
    uint counter = 0;
    for (uint i = 0; i < adspotCount; i++) {
      if (adSpotToOwner[i] == _owner) {
        result[counter] = i;
        counter++;
      }
    }
    return result;
  }

}

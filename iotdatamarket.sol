pragma solidity ^0.4.19;

contract iotdatamarket {
    
    enum EncryptionScheme { DES, DES3,  AES128, AES256 }
    /* contract owner */
    address private creator;


    /* payload from a specific sensor type */
    struct payload {
        address device_id;
        uint timestamp;
        string swarm;
        string schema;
        string spatial;
        uint key_index;
        EncryptionScheme encryption_scheme;
        string encrypted_key;
    }

    /* everything about vendors */
    struct vendor {
        string prefix;
        // vendor supported sensor types
        mapping(uint => bool) types;
        // unit prices for every sensor type
        mapping(uint => uint) prices;
        // payload from a specific sensor type
        mapping(uint => payload[]) payloads;
        // devices belong to specific vendor
        mapping(address => bool) devices;
        // total count of votes
        uint votes;
    }

    struct customer{
        payload[] paid_arr;
        mapping(address => bool) vote_map_used;
        string pub_key;
    }

    mapping(address => vendor) private vendor_map;
    mapping(address => customer) private customer_map;
    address[] private vendor_arr;
    mapping(address => uint) balances;

    function getEncryptionScheme(uint _encID) private pure returns (EncryptionScheme){
        if(_encID==0) return EncryptionScheme.DES;
        if(_encID==1) return EncryptionScheme.DES3;
        if(_encID==2) return EncryptionScheme.AES128;
        if(_encID==3) return EncryptionScheme.AES256;
        revert();
    }
    
    
    /// @dev Registers a vendor to marketplace to be able to list their sensor_data_push
    /// @param prefix Symbol for vendor which is shown on marketplace
    /// @param sensors list of sensor types vendor will publish on marketplace
    /// @param costs list of prices corresponding to each sensor
    /// @return result succesfull registered or not 
    function vendor_register (string prefix, uint[] sensors, uint[] costs) public returns (address) {
        // check if vendor is already registered .
        require(bytes(vendor_map[msg.sender].prefix).length == 0);
        vendor_map[msg.sender].prefix = prefix;
        for (uint it = 0; it < sensors.length; it++) {
            vendor_map[msg.sender].types[sensors[it]] = true;
            vendor_map[msg.sender].prices[sensors[it]] = costs[it];
        }
        // add vendor address to "vendor array" 
        vendor_arr.push(msg.sender);
        return msg.sender;
    }
    
    /// @dev Registers a customer to marketplace 
    /// @param _pub_key Customer's public key which is required to key exchange between parties  
    /// @return address of registered customer if succesfull
    
    function customer_register (string _pub_key) public returns (address) {
        // check if customer is already registered .
        require(bytes(customer_map[msg.sender].pub_key).length == 0);
        customer_map[msg.sender].pub_key = _pub_key;
        return msg.sender;
    }
    

    /// @dev Add devices address that can push data on behalf of vendor
    /// @param device_address Address of the device that allowed to push data 
    /// @return Address of current added device
    function add_valid_device (address device_address) public returns (address) {
        require(!vendor_map[msg.sender].devices[device_address]);
        vendor_map[msg.sender].devices[device_address] = true;
        return device_address;
    }

    /// @dev Get total vendors registered on market
    /// @return returns total count of vendors 
    function vendor_length () public view returns (uint length) {
        return vendor_arr.length;
    }

    /// @dev Get symbol of the vendor to be listed
    /// @param addr Address of the vendor 
    /// @return prefix corresponding symbol to vendor's address
    function get_vendor (address addr) public view returns (string prefix) {
        return (vendor_map[addr].prefix);
    }

    /// @dev Adds the data to be shown on market
    /// @param vendor_address Address of the vendor 
    /// @param sensor_type Represents data belongs to which sensor type
    /// @param schema JSON representation of schema representation of data
    /// @param timestamp Time when data is pushed on swarm
    /// @param spatial Geolocation of device where the data is pushed
    /// @param swarm url of the content on swarm  
    function sensor_data_push (address vendor_address, uint sensor_type, string schema, uint timestamp, string spatial, string swarm,uint key_index, uint _encID ) public returns (address) {
        require(vendor_map[vendor_address].types[sensor_type] && vendor_map[vendor_address].devices[msg.sender]);
        vendor_map[vendor_address].payloads[sensor_type].push(payload(msg.sender,timestamp,swarm,schema,spatial,key_index, getEncryptionScheme(_encID),""));
        return vendor_address;
    }

    /// @dev Checks whether vendor has sensor_type or not, returns address if vendor has
    /// @param sensor_type Numeric representation of corresponding sensor_type
    /// @param index iteration number for vendor_list
    function query_sensor (uint sensor_type, uint index) public view returns (address result) {
        require(vendor_map[vendor_arr[index]].types[sensor_type] && vendor_map[vendor_arr[index]].payloads[sensor_type].length > 0);
        return vendor_arr[index];
    }

    /// @dev Getting data from the vendor for specific sensor. It's complementary to query from application
    /// @param vendor_address address of the vendor who has data for queried sensor_data_pull
    /// @param sensor_type Look-up sensor types
    /// @param index The position of payload since vendor may have multiple data for one sensor type 
    /// @return all payload except swarm url and corresponding price to sensor type 
    function sensor_data_pull (address vendor_address, uint sensor_type, uint index) public view returns (string schema, uint timestamp, string spatial, uint price) {
        return (vendor_map[vendor_address].payloads[sensor_type][index].schema,
                vendor_map[vendor_address].payloads[sensor_type][index].timestamp,
                vendor_map[vendor_address].payloads[sensor_type][index].spatial,
                vendor_map[vendor_address].prices[sensor_type]);
    }
    
    /// @dev Gets how much datasets a vendor has for one sensor type
    /// @param vendor_address Address of the vendor 
    /// @param sensor_type Sensor type which data belongs to
    /// @return count of datasets for given sensor type
    function sensor_data_length (address vendor_address, uint sensor_type) public view returns (uint len) {
        return vendor_map[vendor_address].payloads[sensor_type].length;
    }

    /// @dev makes transaction between vendor and buyer while providing swarm url to buyer
    /// @param vendor_address Address of the vendor 
    /// @param sensor_type Sensor type which data belongs to
    /// @param index Position of asked payload in array
    /// @return returns address of the vendor if payloadRequest event is succesfully requested
    function request_for_data (address vendor_address, uint sensor_type, uint index) public returns (address) {
        uint sensor_price = vendor_map[vendor_address].prices[sensor_type];
        require(sensor_price<=balances[msg.sender]);
        //customer_map[msg.sender].paid_arr.push((vendor_map[vendor_address].payloads[sensor_type])[index]);
        customer_map[msg.sender].vote_map_used[vendor_address] = true;
        //return (vendor_map[vendor_address].payloads[sensor_type])[index].swarm;
        emit payload_request(msg.sender,vendor_address,customer_map[msg.sender].pub_key,sensor_type,index);
        return vendor_address;
        
    }
    
    event payload_request(
        address indexed _from,
        address indexed _to,
        string pub_key,
        uint sensor_type,
        uint index
    );

    event payload_response(
        address indexed _from,
        address indexed _to,
        string dec_key,
        uint sensor_type,
        uint index,
        string swarm
    );
    
    function transfer_key_and_data(string dec_key,address _to, uint sensor_type, uint index)public returns(string){
        uint _price = vendor_map[msg.sender].prices[sensor_type];
        require(balances[_to]>=_price);
        balances[_to]-= _price;
        balances[msg.sender] += _price;
        (vendor_map[msg.sender].payloads[sensor_type])[index].encrypted_key=dec_key;
        customer_map[_to].paid_arr.push((vendor_map[msg.sender].payloads[sensor_type])[index]);
        emit payload_response(msg.sender,_to,dec_key, sensor_type,index,(vendor_map[msg.sender].payloads[sensor_type])[index].swarm);
        return dec_key;
    }
    
    
    function deposit() payable public returns (bool) {
        balances[msg.sender] += msg.value;
        return true;
    }
    
    
    /// Consensys Smart Contract Best Practices
    function withdraw() public {
        uint amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        require(msg.sender.call.value(amountToWithdraw)()); 
        
    }
    
    
    

    /// @dev Provides functionality for basic voting mechanism by letting payers to evaluate vendors
    /// @param vendor_address Address of the vendor 
    /// @param vote upvote is represented by 1, where downvote is represented by int208
    /// @return current count of votes for vendor
    function vote_for_vendor (address vendor_address,uint vote) public returns (uint) {
    require(customer_map[msg.sender].vote_map_used[vendor_address]);
        if (vote == 1) {
            vendor_map[vendor_address].votes += 1;
        } else if (vote == 0 && vendor_map[vendor_address].votes > 0) {
            vendor_map[vendor_address].votes -= 1;
        } else {
            revert();
        }
        customer_map[msg.sender].vote_map_used[vendor_address] = false;
        return vendor_map[vendor_address].votes;

    }

    function update_sensor_price (uint sensor_type, uint price) public returns (uint) {
        require(vendor_map[msg.sender].types[sensor_type]);
        vendor_map[msg.sender].prices[sensor_type] = price;
        return price;
    }

    function get_sensor_price(uint sensor_type_index) public view returns (uint) {
        if (vendor_map[msg.sender].types[sensor_type_index] != true) {
            return 0;
        } else {
            return vendor_map[msg.sender].prices[sensor_type_index];
        }
    }
    
    /// @dev fallback function that accepts ether to be sent to the contract 
    function () public payable {}
    
    /// @dev constructor 
    constructor() public {
        creator = msg.sender;
    }

    /// @dev kills contract and sends remaining funds back to creator 
    function kill() public {
        if (msg.sender == creator) {
            selfdestruct(creator);
        }
    }

}

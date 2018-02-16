pragma solidity ^0.4.19;

contract iotdatamarket {
    /* contract owner */
    address private creator;

    /* payload from a specific sensor type */
    struct payload {
        uint timestamp;
        string swarm;
        string schema;
        string spatial;
    }

    /* everything about vendors */
    struct vendor {
        string prefix;
        // vendor supported sensor types: [001001010]
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
    }

    mapping(address => vendor) private vendor_map;
    mapping(address => customer) private customer_map;
    address[] private vendor_arr;

    function query_sensor (uint sensor_type, uint index) public view returns (address result) {
        if (vendor_map[vendor_arr[index]].types[sensor_type] != true || vendor_map[vendor_arr[index]].payloads[sensor_type].length == 0) {
            // TODO check, if doesnt work return 0xdeadbeef
            revert();
        }
        return vendor_arr[index];
    }


    function vendor_register (string prefix, uint[] sensors, uint[] costs) public returns (bool result) {
        /* check if vendor is already registered */
        if (bytes(vendor_map[msg.sender].prefix).length != 0) {
            return false;
        }
        /* add to vendor object to "vendor map" */
        vendor_map[msg.sender].prefix = prefix;
        for (uint it = 0; it < sensors.length; it++) {
            vendor_map[msg.sender].types[sensors[it]] = true;
            vendor_map[msg.sender].prices[sensors[it]] = costs[it];
        }
        /* add vendor address to "vendor array" */
        vendor_arr.push(msg.sender);
        return true;
    }

    function add_valid_device (address device_address) public returns (bool) {
        // returns false if device is already added
        if (vendor_map[msg.sender].devices[device_address] == true) {
            return false;
        }
        vendor_map[msg.sender].devices[device_address] = true;
        return true;
    }

    function vendor_length () public view returns (uint length) {
        return vendor_arr.length;
    }

    function get_vendor (address addr) public view returns (string prefix) {
        return (vendor_map[addr].prefix);
    }

    function sensor_data_push (address vendor_address, uint sensor_type, string schema, uint timestamp, string spatial, string swarm) public returns (bool result) {
        if (vendor_map[vendor_address].types[sensor_type] != true) {
            return false;
        }
        if (vendor_map[vendor_address].devices[msg.sender] != true){
            return false;
        }
        /* TODO if no element is touched payloads[] could not be resolved */
        vendor_map[vendor_address].prefix = vendor_map[vendor_address].prefix;
        vendor_map[vendor_address].payloads[sensor_type].push(payload(timestamp,swarm,schema,spatial));
        return true;
    }

    function sensor_data_pull (address vendor_address, uint sensor_type, uint index) public view returns (string schema, uint timestamp, string spatial, uint price) {
        return (vendor_map[vendor_address].payloads[sensor_type][index].schema,
                vendor_map[vendor_address].payloads[sensor_type][index].timestamp,
                vendor_map[vendor_address].payloads[sensor_type][index].spatial,
                vendor_map[vendor_address].prices[sensor_type]);
    }

    function sensor_data_length (address vendor_address, uint sensor_type) public view returns (uint len) {
        return vendor_map[vendor_address].payloads[sensor_type].length;
    }

    function pay_for_data (address vendor_address, uint sensor_type, uint index) public payable returns (string swarm) {
        if (msg.value < vendor_map[vendor_address].prices[sensor_type]) {
            revert();
        } else {
            // more control statements?
            customer_map[msg.sender].paid_arr.push((vendor_map[vendor_address].payloads[sensor_type])[index]);
            customer_map[msg.sender].vote_map_used[vendor_address] = true;
            if(vendor_address.send(msg.value)){
                return (vendor_map[vendor_address].payloads[sensor_type])[index].swarm;
            }
            else{
                revert();
            }
        }
    }

    function vote_for_vendor (address vendor_address,uint vote) public returns (bool) {
        if (customer_map[msg.sender].vote_map_used[vendor_address] == true) {
            if (vote == 1) {
                vendor_map[vendor_address].votes += 1;
            } else if (vote == 0 && vendor_map[vendor_address].votes > 0) {
                vendor_map[vendor_address].votes -= 1;
            } else {
                revert();
            }
            customer_map[msg.sender].vote_map_used[vendor_address] = false;
            return true;
        }
        return false;
    }

    function update_sensor_price (uint sensor_type, uint price) public returns (bool) {
        if (vendor_map[msg.sender].types[sensor_type] != true) {
            return false;
        }
        vendor_map[msg.sender].prices[sensor_type] = price;
        return true;
    }

    function get_sensor_price(uint sensor_type_index) public view returns (uint) {
        if (vendor_map[msg.sender].types[sensor_type_index] != true) {
            return 0;
        } else {
            return vendor_map[msg.sender].prices[sensor_type_index];
        }
    }

    /* constructor */
    function iotdatamarket() public {
        creator = msg.sender;
    }

    /* kills contract and sends remaining funds back to creator */
    function kill() public {
        if (msg.sender == creator) {
            selfdestruct(creator);
        }
    }

    /*
        function query_sensor_length (uint sensor_type) public view returns (uint vcount) {
        uint vendor_count = 0;
        for (uint it = 0; it < vendor_arr.length; it++) {
            if (vendor_map[vendor_arr[it]].types[sensor_type] == true && vendor_map[vendor_arr[it]].payloads[sensor_type].length>0) {
               vendor_count++;
            }
        }
        return vendor_count;
    }
    */
}

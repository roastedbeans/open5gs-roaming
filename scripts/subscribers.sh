#!/bin/bash

# 5G Core Network Subscriber Management Script
# This script manages subscribers in the MongoDB database for 5G core network
# Supports adding multiple subscribers in ranges and bulk operations

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="hplmn"  # Fixed namespace - no option to change
DB_NAME="open5gs"
COLLECTION_NAME="subscribers"
DEFAULT_KEY="465B5CE8B199B49FAA5F0A2EE238A6BC"
DEFAULT_OPC="E8ED289DEBA952E4283B54E88E6183CA"
BATCH_SIZE=10

# Global variables
START_IMSI=""
END_IMSI=""
OPERATION=""
CUSTOM_KEY=""
CUSTOM_OPC=""

# Function to display usage
show_usage() {
    echo -e "${CYAN}5G Subscriber Management Script${NC}"
    echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo "Operations:"
    echo "  --add-range          Add subscribers in IMSI range"
    echo "  --add-single         Add single subscriber"
    echo "  --delete-all         Delete all subscribers"
    echo "  --list-subscribers   List all subscribers"
    echo "  --count-subscribers  Count total subscribers"
    echo ""
    echo "Options:"
    echo "  --start-imsi IMSI    Starting IMSI for range operations"
    echo "  --end-imsi IMSI      Ending IMSI for range operations"
    echo "  --imsi IMSI          Single IMSI for single subscriber"
    echo "  --key KEY            Custom authentication key (optional)"
    echo "  --opc OPC            Custom OPC value (optional)"
    echo "  --batch-size SIZE    Number of subscribers per batch (default: 10)"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --add-range --start-imsi 001011234567891 --end-imsi 001011234567900"
    echo "  $0 --add-single --imsi 001011234567891"
    echo "  $0 --delete-all"
    echo "  $0 --count-subscribers"
}

# Function to validate IMSI format
validate_imsi() {
    local imsi=$1
    if [[ ! $imsi =~ ^[0-9]{15}$ ]]; then
        echo -e "${RED}Error: IMSI must be exactly 15 digits${NC}"
        return 1
    fi
    return 0
}

# Function to increment IMSI
increment_imsi() {
    local imsi=$1
    local incremented=$((10#$imsi + 1))
    printf "%015d" $incremented
}

# Function to get MongoDB pod
get_mongodb_pod() {
    local pod_name=$(microk8s kubectl get pods -n $NAMESPACE -l app=mongodb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$pod_name" ]; then
        echo -e "${RED}Error: MongoDB pod not found in namespace $NAMESPACE${NC}"
        exit 1
    fi
    echo $pod_name
}

# Function to create subscriber document
create_subscriber_document() {
    local imsi=$1
    local key=${2:-$DEFAULT_KEY}
    local opc=${3:-$DEFAULT_OPC}
    
    cat << EOF
{
    "schema_version": NumberInt(1),
    "imsi": "$imsi",
    "msisdn": [],
    "imeisv": "1110000000000000",
    "mme_host": [],
    "mm_realm": [],
    "purge_flag": [],
    "slice": [
        {
            "sst": NumberInt(1),
            "default_indicator": true,
            "session": [
                {
                    "name": "internet",
                    "type": NumberInt(3),
                    "qos": {
                        "index": NumberInt(9),
                        "arp": {
                            "priority_level": NumberInt(8),
                            "pre_emption_capability": NumberInt(1),
                            "pre_emption_vulnerability": NumberInt(1)
                        }
                    },
                    "ambr": {
                        "downlink": {
                            "value": NumberInt(1),
                            "unit": NumberInt(3)
                        },
                        "uplink": {
                            "value": NumberInt(1),
                            "unit": NumberInt(3)
                        }
                    },
                    "pcc_rule": [],
                    "_id": new ObjectId()
                }
            ],
            "_id": new ObjectId()
        }
    ],
    "security": {
        "k": "$key",
        "op": null,
        "opc": "$opc",
        "amf": "8000",
        "sqn": NumberLong(1184)
    },
    "ambr": {
        "downlink": {"value": NumberInt(1), "unit": NumberInt(3)},
        "uplink": {"value": NumberInt(1), "unit": NumberInt(3)}
    },
    "access_restriction_data": 32,
    "network_access_mode": 2,
    "subscriber_status": 0,
    "operator_determined_barring": 0,
    "subscribed_rau_tau_timer": 12,
    "__v": 0
}
EOF
}

# Function to add single subscriber
add_single_subscriber() {
    local imsi=$1
    local key=${2:-$DEFAULT_KEY}
    local opc=${3:-$DEFAULT_OPC}
    local mongodb_pod=$(get_mongodb_pod)
    
    echo -e "${BLUE}Adding subscriber with IMSI: $imsi${NC}"
    
    # Create MongoDB script
    cat > /tmp/add-single-subscriber.js << EOF
db = db.getSiblingDB('$DB_NAME');

// Ensure collection exists
if (!db.getCollectionNames().includes('$COLLECTION_NAME')) {
    db.createCollection('$COLLECTION_NAME');
    print("Created $COLLECTION_NAME collection");
}

// Add subscriber
var subscriber = $(create_subscriber_document "$imsi" "$key" "$opc");

db.$COLLECTION_NAME.updateOne(
    { imsi: "$imsi" },
    {\$setOnInsert: subscriber},
    { upsert: true }
);

// Verify
var result = db.$COLLECTION_NAME.findOne({imsi: "$imsi"});
if (result) {
    print("SUCCESS: Subscriber $imsi added successfully");
} else {
    print("ERROR: Failed to add subscriber $imsi");
}
EOF

    # Execute script
    microk8s kubectl cp /tmp/add-single-subscriber.js $NAMESPACE/$mongodb_pod:/tmp/add-single-subscriber.js
    microk8s kubectl exec -n $NAMESPACE $mongodb_pod -- mongo --quiet /tmp/add-single-subscriber.js
    
    rm -f /tmp/add-single-subscriber.js
}

# Function to add subscribers in range
add_subscribers_range() {
    local start_imsi=$1
    local end_imsi=$2
    local key=${3:-$DEFAULT_KEY}
    local opc=${4:-$DEFAULT_OPC}
    local mongodb_pod=$(get_mongodb_pod)
    
    # Validate range
    if [ $((10#$start_imsi)) -gt $((10#$end_imsi)) ]; then
        echo -e "${RED}Error: Start IMSI cannot be greater than end IMSI${NC}"
        exit 1
    fi
    
    local total_subscribers=$((10#$end_imsi - 10#$start_imsi + 1))
    echo -e "${BLUE}Adding $total_subscribers subscribers from $start_imsi to $end_imsi${NC}"
    
    # Process in batches
    local current_imsi=$start_imsi
    local batch_count=0
    local total_added=0
    
    while [ $((10#$current_imsi)) -le $((10#$end_imsi)) ]; do
        local batch_end=$((10#$current_imsi + BATCH_SIZE - 1))
        if [ $batch_end -gt $((10#$end_imsi)) ]; then
            batch_end=$((10#$end_imsi))
        fi
        
        batch_count=$((batch_count + 1))
        local batch_size=$((batch_end - 10#$current_imsi + 1))
        
        echo -e "${YELLOW}Processing batch $batch_count ($batch_size subscribers)...${NC}"
        
        # Create batch script
        cat > /tmp/add-batch-subscribers.js << EOF
db = db.getSiblingDB('$DB_NAME');

// Ensure collection exists
if (!db.getCollectionNames().includes('$COLLECTION_NAME')) {
    db.createCollection('$COLLECTION_NAME');
    print("Created $COLLECTION_NAME collection");
}

var operations = [];
var added_count = 0;

EOF
        
        # Add subscribers to batch
        local temp_imsi=$current_imsi
        while [ $((10#$temp_imsi)) -le $batch_end ]; do
            echo "var subscriber_$temp_imsi = $(create_subscriber_document "$temp_imsi" "$key" "$opc");" >> /tmp/add-batch-subscribers.js
            echo "operations.push({" >> /tmp/add-batch-subscribers.js
            echo "    updateOne: {" >> /tmp/add-batch-subscribers.js
            echo "        filter: { imsi: \"$temp_imsi\" }," >> /tmp/add-batch-subscribers.js
            echo "        update: {\$setOnInsert: subscriber_$temp_imsi}," >> /tmp/add-batch-subscribers.js
            echo "        upsert: true" >> /tmp/add-batch-subscribers.js
            echo "    }" >> /tmp/add-batch-subscribers.js
            echo "});" >> /tmp/add-batch-subscribers.js
            
            temp_imsi=$(increment_imsi $temp_imsi)
        done
        
        # Execute batch operation
        cat >> /tmp/add-batch-subscribers.js << EOF

// Execute bulk operation
if (operations.length > 0) {
    var result = db.$COLLECTION_NAME.bulkWrite(operations);
    print("Batch completed: " + result.upsertedCount + " new subscribers added, " + result.modifiedCount + " updated");
    added_count = result.upsertedCount;
} else {
    print("No operations to execute");
}

print("Batch $batch_count processed: " + added_count + " subscribers");
EOF

        # Execute script
        microk8s kubectl cp /tmp/add-batch-subscribers.js $NAMESPACE/$mongodb_pod:/tmp/add-batch-subscribers.js
        microk8s kubectl exec -n $NAMESPACE $mongodb_pod -- mongo --quiet /tmp/add-batch-subscribers.js
        
        total_added=$((total_added + batch_size))
        current_imsi=$(printf "%015d" $((batch_end + 1)))
        
        # Progress indicator
        local progress=$((total_added * 100 / total_subscribers))
        echo -e "${GREEN}Progress: $total_added/$total_subscribers ($progress%)${NC}"
        
        # Clean up temporary file
        rm -f /tmp/add-batch-subscribers.js
        
        # Small delay between batches
        sleep 1
    done
    
    echo -e "${GREEN}Successfully added $total_added subscribers${NC}"
}

# Function to delete all subscribers
delete_all_subscribers() {
    local mongodb_pod=$(get_mongodb_pod)
    
    echo -e "${YELLOW}WARNING: This will delete ALL subscribers from the database!${NC}"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Operation cancelled${NC}"
        return
    fi
    
    echo -e "${BLUE}Deleting all subscribers...${NC}"
    
    cat > /tmp/delete-all-subscribers.js << EOF
db = db.getSiblingDB('$DB_NAME');

var count_before = db.$COLLECTION_NAME.count();
print("Subscribers before deletion: " + count_before);

var result = db.$COLLECTION_NAME.deleteMany({});
print("Deleted " + result.deletedCount + " subscribers");

var count_after = db.$COLLECTION_NAME.count();
print("Subscribers remaining: " + count_after);
EOF

    microk8s kubectl cp /tmp/delete-all-subscribers.js $NAMESPACE/$mongodb_pod:/tmp/delete-all-subscribers.js
    microk8s kubectl exec -n $NAMESPACE $mongodb_pod -- mongo --quiet /tmp/delete-all-subscribers.js
    
    rm -f /tmp/delete-all-subscribers.js
    echo -e "${GREEN}All subscribers deleted successfully${NC}"
}

# Function to list subscribers
list_subscribers() {
    local mongodb_pod=$(get_mongodb_pod)
    
    echo -e "${BLUE}Listing all subscribers...${NC}"
    
    cat > /tmp/list-subscribers.js << EOF
db = db.getSiblingDB('$DB_NAME');

var subscribers = db.$COLLECTION_NAME.find({}, {imsi: 1, _id: 0}).sort({imsi: 1});
var count = 0;

subscribers.forEach(function(sub) {
    print("IMSI: " + sub.imsi);
    count++;
});

print("Total subscribers: " + count);
EOF

    microk8s kubectl cp /tmp/list-subscribers.js $NAMESPACE/$mongodb_pod:/tmp/list-subscribers.js
    microk8s kubectl exec -n $NAMESPACE $mongodb_pod -- mongo --quiet /tmp/list-subscribers.js
    
    rm -f /tmp/list-subscribers.js
}

# Function to count subscribers
count_subscribers() {
    local mongodb_pod=$(get_mongodb_pod)
    
    echo -e "${BLUE}Counting subscribers...${NC}"
    
    cat > /tmp/count-subscribers.js << EOF
db = db.getSiblingDB('$DB_NAME');
var count = db.$COLLECTION_NAME.count();
print("Total subscribers in database: " + count);
EOF

    microk8s kubectl cp /tmp/count-subscribers.js $NAMESPACE/$mongodb_pod:/tmp/count-subscribers.js
    microk8s kubectl exec -n $NAMESPACE $mongodb_pod -- mongo --quiet /tmp/count-subscribers.js
    
    rm -f /tmp/count-subscribers.js
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --add-range)
            OPERATION="add-range"
            shift
            ;;
        --add-single)
            OPERATION="add-single"
            shift
            ;;
        --delete-all)
            OPERATION="delete-all"
            shift
            ;;
        --list-subscribers)
            OPERATION="list"
            shift
            ;;
        --count-subscribers)
            OPERATION="count"
            shift
            ;;
        --start-imsi)
            START_IMSI="$2"
            shift 2
            ;;
        --end-imsi)
            END_IMSI="$2"
            shift 2
            ;;
        --imsi)
            START_IMSI="$2"
            shift 2
            ;;
        --key)
            CUSTOM_KEY="$2"
            shift 2
            ;;
        --opc)
            CUSTOM_OPC="$2"
            shift 2
            ;;
        --batch-size)
            BATCH_SIZE="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Validate operation
if [ -z "$OPERATION" ]; then
    echo -e "${RED}Error: No operation specified${NC}"
    show_usage
    exit 1
fi

# Main execution
echo -e "${CYAN}5G Subscriber Management Script${NC}"
echo -e "${BLUE}Namespace: $NAMESPACE (fixed)${NC}"
echo -e "${BLUE}Database: $DB_NAME${NC}"
echo -e "${BLUE}Collection: $COLLECTION_NAME${NC}"
echo "----------------------------------------"

case $OPERATION in
    "add-range")
        if [ -z "$START_IMSI" ] || [ -z "$END_IMSI" ]; then
            echo -e "${RED}Error: Both --start-imsi and --end-imsi are required for range operations${NC}"
            exit 1
        fi
        validate_imsi "$START_IMSI" || exit 1
        validate_imsi "$END_IMSI" || exit 1
        add_subscribers_range "$START_IMSI" "$END_IMSI" "$CUSTOM_KEY" "$CUSTOM_OPC"
        ;;
    "add-single")
        if [ -z "$START_IMSI" ]; then
            echo -e "${RED}Error: --imsi is required for single subscriber operations${NC}"
            exit 1
        fi
        validate_imsi "$START_IMSI" || exit 1
        add_single_subscriber "$START_IMSI" "$CUSTOM_KEY" "$CUSTOM_OPC"
        ;;
    "delete-all")
        delete_all_subscribers
        ;;
    "list")
        list_subscribers
        ;;
    "count")
        count_subscribers
        ;;
    *)
        echo -e "${RED}Error: Invalid operation${NC}"
        show_usage
        exit 1
        ;;
esac

echo "----------------------------------------"
echo -e "${GREEN}Operation completed successfully${NC}"
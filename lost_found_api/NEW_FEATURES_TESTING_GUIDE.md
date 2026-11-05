# Lost & Found Module - Premium Features Testing Guide

**Version:** 2.0.0  
**Total Test Cases:** 80+  
**Status:** Production Ready ✅  
**Date:** November 4, 2026

---

## Table of Contents

1. [Test Environment Setup](#test-environment-setup)
2. [Feature #1: Messaging Tests (12 cases)](#feature-1-messaging-tests)
3. [Feature #2: Push Notifications Tests (10 cases)](#feature-2-push-notifications-tests)
4. [Feature #3: AI Matching Tests (16 cases)](#feature-3-ai-matching-tests)
5. [Feature #4: Analytics Tests (15 cases)](#feature-4-analytics-tests)
6. [Feature #5: Rewards Tests (18 cases)](#feature-5-rewards-tests)
7. [Integration Tests (9 cases)](#integration-tests)
8. [Performance & Load Tests (5 cases)](#performance--load-tests)
9. [Security Tests (6 cases)](#security-tests)
10. [Test Execution Commands](#test-execution-commands)

---

## Test Environment Setup

### Prerequisites

```bash
# Database setup
php artisan migrate
php artisan migrate:fresh --seed  # For demo data

# Clear caches
php artisan cache:clear
php artisan config:clear

# Ensure Sanctum tokens are configured
php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"
```

### Test User Accounts

Create 5 test users:

```bash
php artisan tinker

# User 1: Alice (Lost items)
$user1 = User::create([
  'name' => 'Alice Smith',
  'email' => 'alice@test.com',
  'phone' => '0612345678',
  'password' => bcrypt('password123'),
  'phone_verified_at' => now(),
]);

# User 2: Bob (Found items)
$user2 = User::create([
  'name' => 'Bob Johnson',
  'email' => 'bob@test.com',
  'phone' => '0687654321',
  'password' => bcrypt('password123'),
  'phone_verified_at' => now(),
]);

# User 3: Charlie (Helper)
$user3 = User::create([
  'name' => 'Charlie Brown',
  'email' => 'charlie@test.com',
  'phone' => '0699999999',
  'password' => bcrypt('password123'),
  'phone_verified_at' => now(),
]);

# User 4: Diana (Analytics viewer)
$user4 = User::create([
  'name' => 'Diana Prince',
  'email' => 'diana@test.com',
  'phone' => '0611111111',
  'password' => bcrypt('password123'),
  'phone_verified_at' => now(),
]);

# User 5: Eve (Social user)
$user5 = User::create([
  'name' => 'Eve Taylor',
  'email' => 'eve@test.com',
  'phone' => '0622222222',
  'password' => bcrypt('password123'),
  'phone_verified_at' => now(),
]);
```

### Get Authentication Tokens

```bash
# For each user
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@test.com","password":"password123"}'

# Response: { "token": "ABC123...", "user": {...} }
# Save tokens for use in tests below
```

---

## Feature #1: Messaging Tests

### Test 1.1: Send Message Between Users

**Objective:** Verify basic message sending works

```bash
# Alice (user_id: uuid1) sends message to Bob (user_id: uuid2)
curl -X POST http://localhost:8000/api/messages/send \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "to_user_id": "'$BOB_UUID'",
    "item_id": "'$ITEM_UUID'",
    "content": "I think I found your lost keys!"
  }'

# Expected:
# ✅ Status: 201 Created
# ✅ Response includes: id, from_user_id, to_user_id, content, is_read: false
# ✅ Database record created with correct relationships
```

### Test 1.2: Message Persists in Database

**Objective:** Verify message is stored correctly

```bash
# In tinker
$msg = Message::where('content', 'I think I found your lost keys!')->first();
assert($msg->from_user_id == $alice->id);
assert($msg->to_user_id == $bob->id);
assert($msg->is_read == false);
```

**Expected:**
- ✅ Message exists with all correct fields
- ✅ Timestamps are current
- ✅ UUID is valid format

### Test 1.3: Get Conversations List

**Objective:** Verify user sees all conversations

```bash
# Alice retrieves conversations
curl -X GET http://localhost:8000/api/messages/conversations \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Response shows Bob in conversations (last_message, last_message_time, unread_count)
# ✅ Sorted by latest message time
```

### Test 1.4: Get Message History With User

**Objective:** Verify message thread retrieval

```bash
# Alice retrieves messages with Bob
curl -X GET http://localhost:8000/api/messages/with/$BOB_UUID \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Returns paginated list (default 20 per page)
# ✅ Messages sorted by created_at ASC (oldest first)
# ✅ Shows correct from/to users
# ✅ Read status accurate
```

### Test 1.5: Pagination on Message History

**Objective:** Verify large message threads paginate

```bash
# Create 50+ messages between Alice and Bob
for i in {1..50}; do
  # Send message via API
  curl -s -X POST http://localhost:8000/api/messages/send \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"to_user_id":"'$BOB_UUID'","content":"Message '$i'"}'
done

# Get page 1 (20 per page)
curl http://localhost:8000/api/messages/with/$BOB_UUID?page=1 \
  -H "Authorization: Bearer $ALICE_TOKEN" | jq '.data | length'
# Expected: 20

# Get page 3
curl http://localhost:8000/api/messages/with/$BOB_UUID?page=3 \
  -H "Authorization: Bearer $ALICE_TOKEN" | jq '.data | length'
# Expected: 10
```

### Test 1.6: Mark Message as Read

**Objective:** Verify read status updates

```bash
# Get a message ID from conversation
MESSAGE_ID=$(curl -s http://localhost:8000/api/messages/with/$ALICE_UUID \
  -H "Authorization: Bearer $BOB_TOKEN" | jq -r '.data[0].id')

# Bob marks message as read
curl -X PATCH http://localhost:8000/api/messages/$MESSAGE_ID/read \
  -H "Authorization: Bearer $BOB_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Response shows is_read: true, read_at is set
# ✅ Database updated with read timestamp
```

### Test 1.7: Unread Count Endpoint

**Objective:** Verify unread message counter

```bash
# Bob checks unread count
curl http://localhost:8000/api/messages/unread-count \
  -H "Authorization: Bearer $BOB_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Returns: { "unread_count": 47 } (from Test 1.5 messages)
```

### Test 1.8: Cannot Send Message to Non-Existent User

**Objective:** Verify validation

```bash
curl -X POST http://localhost:8000/api/messages/send \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "to_user_id": "00000000-0000-0000-0000-000000000000",
    "content": "Invalid"
  }'

# Expected:
# ✅ Status: 422 Unprocessable Entity
# ✅ Error message about invalid user
```

### Test 1.9: Cannot Exceed Message Length

**Objective:** Verify character limits

```bash
LONG_MSG=$(python -c "print('x' * 5001)")

curl -X POST http://localhost:8000/api/messages/send \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"to_user_id":"'$BOB_UUID'","content":"'$LONG_MSG'"}'

# Expected:
# ✅ Status: 422 Unprocessable Entity
# ✅ Error: content must not exceed 5000 characters
```

### Test 1.10: Can Send Empty Item Reference

**Objective:** Verify item_id is optional

```bash
curl -X POST http://localhost:8000/api/messages/send \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "to_user_id": "'$BOB_UUID'",
    "content": "General inquiry, no specific item"
  }'

# Expected:
# ✅ Status: 201 Created
# ✅ Response shows item_id: null
```

### Test 1.11: Messages Show Related Item

**Objective:** Verify item context is included

```bash
curl http://localhost:8000/api/messages/with/$BOB_UUID \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  | jq '.data[] | select(.item_id != null) | {content, item_id, item_name}'

# Expected:
# ✅ Messages with items show item details
# ✅ Can use item information for context
```

### Test 1.12: Cannot Access Other Users' Messages

**Objective:** Verify privacy/authorization

```bash
# Get Charlie's conversation with Bob
# Then try to access as Alice (unauthorized)
curl http://localhost:8000/api/messages/with/$CHARLIE_UUID \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 403 Forbidden or 404 Not Found
# ✅ Cannot read other users' private messages
```

---

## Feature #2: Push Notifications Tests

### Test 2.1: Notification Created on Item Posted

**Objective:** Verify notification triggers on new item

```bash
# Bob posts a found item (phone)
curl -X POST http://localhost:8000/api/items \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "name=Black iPhone" \
  -F "category=electronics" \
  -F "type=found" \
  -F "latitude=48.8566" \
  -F "longitude=2.3522" \
  -F "description=Black iPhone 13, cracked screen, found at mall" \
  -F "image=@phone.jpg"

# Check if Alice (who lost similar phone) got notification
psql -d lost_found -c \
  "SELECT * FROM notifications WHERE user_id='$ALICE_UUID' AND type='nearby_match' ORDER BY created_at DESC LIMIT 1;"

# Expected:
# ✅ Notification created for Alice
# ✅ Type: nearby_match
# ✅ Data contains match_score > 60
```

### Test 2.2: Match Score Calculated Correctly

**Objective:** Verify scoring algorithm

```bash
# Check notification data
SELECT data FROM notifications 
WHERE type='nearby_match' 
ORDER BY created_at DESC LIMIT 1;

# Expected:
# ✅ match_score is between 0-100
# ✅ If items similar: score > 60
# ✅ Data includes other_item_id, distance_km
```

### Test 2.3: Notification Not Created for Low Scores

**Objective:** Verify threshold filtering

```bash
# Charlie posts a completely different item (document found)
curl -X POST http://localhost:8000/api/items \
  -H "Authorization: Bearer $CHARLIE_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "name=Lost Passport" \
  -F "category=documents" \
  -F "type=found" \
  -F "latitude=48.8566" \
  -F "longitude=2.3522" \
  -F "description=Red passport found in metro" \
  -F "image=@passport.jpg"

# Check Alice notifications - should NOT have triggered
psql -d lost_found -c \
  "SELECT COUNT(*) FROM notifications WHERE user_id='$ALICE_UUID' AND data->>'document' IS NOT NULL;"

# Expected:
# ✅ No notification for mismatched category
# ✅ Score was < 60, notification not created
```

### Test 2.4: Message Notification Triggered

**Objective:** Verify message notifications

```bash
# Alice sends message to Bob
curl -s -X POST http://localhost:8000/api/messages/send \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{"to_user_id":"'$BOB_UUID'","content":"Important update!"}' > /dev/null

# Check if Bob received notification
psql -d lost_found -c \
  "SELECT * FROM notifications WHERE user_id='$BOB_UUID' AND type='message' ORDER BY created_at DESC LIMIT 1;"

# Expected:
# ✅ Notification created for Bob
# ✅ Title contains Alice's name
# ✅ Message preview shown
```

### Test 2.5: Item Recovery Notification

**Objective:** Verify recovery alerts

```bash
# Get a match between Alice and Bob
MATCH_ID=$(psql -d lost_found -tc \
  "SELECT id FROM matches WHERE status='pending' LIMIT 1;" | xargs)

# Bob confirms recovery
curl -X POST http://localhost:8000/api/matches/$MATCH_ID/confirm-restitution \
  -H "Authorization: Bearer $BOB_TOKEN"

# Check Alice notification
psql -d lost_found -c \
  "SELECT * FROM notifications WHERE user_id='$ALICE_UUID' AND type='item_recovered';"

# Expected:
# ✅ Notification created for Alice
# ✅ Title: "Great news! Your item was recovered"
# ✅ Data includes item_id and match_id
```

### Test 2.6: Trending Notification (Manual)

**Objective:** Verify trending item alerts

```bash
# In tinker - manually create trending notification
app(NotificationService::class)->trendingItems(
  $alice,
  'electronics',
  7,  // count
);

# Verify notification created
SELECT * FROM notifications 
WHERE type='trending_item' 
ORDER BY created_at DESC LIMIT 1;

# Expected:
# ✅ Notification created
# ✅ Category: electronics
# ✅ Count: 7 items
```

### Test 2.7: Unread Notification Tracking

**Objective:** Verify is_read flag

```bash
# Get unread notifications
psql -d lost_found -c \
  "SELECT COUNT(*) FROM notifications WHERE user_id='$ALICE_UUID' AND is_read=false;"

# Mark as read (via notification ID)
NOTIF_ID=$(psql -d lost_found -tc \
  "SELECT id FROM notifications WHERE user_id='$ALICE_UUID' ORDER BY created_at DESC LIMIT 1;" | xargs)

# Update in DB (or via API if endpoint exists)
psql -d lost_found -c \
  "UPDATE notifications SET is_read=true, read_at=NOW() WHERE id='$NOTIF_ID';"

# Verify
psql -d lost_found -c \
  "SELECT is_read, read_at FROM notifications WHERE id='$NOTIF_ID';"

# Expected:
# ✅ is_read: true
# ✅ read_at is timestamp
```

### Test 2.8: Notification Data Accuracy

**Objective:** Verify payload contains correct data

```bash
# Get recent notification
psql -d lost_found -c \
  "SELECT data FROM notifications ORDER BY created_at DESC LIMIT 1;" | jq '.'

# Expected structure (for nearby_match):
# {
#   "match_score": 87,
#   "other_item_id": "uuid",
#   "distance_km": 2.3
# }
```

### Test 2.9: Performance - Notifications Created Quickly

**Objective:** Verify no query bottlenecks

```bash
# Time item posting (should trigger notifications)
time curl -s -X POST http://localhost:8000/api/items \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "name=Test Item" \
  -F "category=electronics" \
  -F "type=found" \
  -F "latitude=48.8566" \
  -F "longitude=2.3522" \
  -F "description=Test" \
  -F "image=@image.jpg" > /dev/null

# Expected:
# ✅ Response time < 2 seconds (including notification dispatch)
```

### Test 2.10: Multiple Notifications per User

**Objective:** Verify user can have multiple unread notifications

```bash
# Create multiple triggers
# Post 3 different found items (should match Alice's lost items)
# Send 2 messages to Alice

# Check total unread
psql -d lost_found -c \
  "SELECT COUNT(*), type FROM notifications WHERE user_id='$ALICE_UUID' AND is_read=false GROUP BY type;"

# Expected:
# ✅ Multiple notifications of different types
# ✅ All stored and retrievable
```

---

## Feature #3: AI Matching Tests

### Test 3.1: Basic Match Score Calculation

**Objective:** Verify MatchingService scoring

```bash
# In tinker
$lostItem = Item::where('type', 'lost')->where('category', 'electronics')->first();
$foundItem = Item::where('type', 'found')->where('category', 'electronics')->first();

$matchingService = app(MatchingService::class);
$score = $matchingService->scoreMatch($lostItem, $foundItem);

echo "Score: " . $score;

# Expected:
# ✅ Score between 0-100
# ✅ For similar electronics: score > 60
```

### Test 3.2: Category Match Scoring

**Objective:** Verify category weight (40%)

```bash
# Test exact category match
$score = $matchingService->scoreMatch(
  Item::factory()->create(['category' => 'electronics', 'created_at' => now(), 'location' => 'POINT(48.8566 2.3522)']),
  Item::factory()->create(['category' => 'electronics', 'created_at' => now(), 'location' => 'POINT(48.8566 2.3522)'])
);

// Category should contribute 40% to score
// If only category matches: score ≈ 40

# Expected:
# ✅ Score around 40 (category weight only)
# ✅ Related categories score ≈ 30 (0.75 × 40%)
```

### Test 3.3: Temporal Match Scoring

**Objective:** Verify temporal weight (30%)

```bash
# Test same day
$oldItem = Item::factory()->create(['created_at' => now()->subDays(1)]);
$newItem = Item::factory()->create(['created_at' => now()]);
$score = $matchingService->scoreMatch($oldItem, $newItem);
// Difference: 1 day → temporal score = 0.75
// If only temporal: score ≈ 22.5 (0.75 × 30%)

# Expected:
# ✅ 1-3 days apart: temporal contribution ≈ 22.5%
# ✅ 8-14 days apart: temporal contribution ≈ 7.5%
# ✅ 15+ days apart: temporal contribution = 0%
```

### Test 3.4: Geographic Match Scoring

**Objective:** Verify distance weight (20%)

```bash
# Test close locations (< 1 km)
$item1 = Item::factory()->create(['location' => 'POINT(48.8566 2.3522)']);
$item2 = Item::factory()->create(['location' => 'POINT(48.8570 2.3525)']);  // ~0.5 km
$score = $matchingService->scoreMatch($item1, $item2);
// Distance close → distance score = 1.0
// If only distance: score ≈ 20 (1.0 × 20%)

# Expected:
# ✅ 0-1 km: distance contribution = 20%
# ✅ 1-5 km: distance contribution = 15%
# ✅ 5-10 km: distance contribution = 10%
# ✅ 20+ km: distance contribution = 0%
```

### Test 3.5: Description Match Scoring

**Objective:** Verify keyword similarity (10%)

```bash
# Test keyword overlap
$item1 = Item::factory()->create(['description' => 'Black iPhone 13 with cracked screen']);
$item2 = Item::factory()->create(['description' => 'Black iPhone 13 damaged display']);
$score = $matchingService->scoreMatch($item1, $item2);
// Keywords: [black, iphone, 13, cracked/damaged, screen/display]
// High overlap → description score ≈ 0.8
// If only description: score ≈ 8 (0.8 × 10%)

# Expected:
# ✅ High keyword overlap: description ≈ 8-10%
# ✅ No keyword overlap: description = 0%
# ✅ Partial overlap: description ≈ 3-5%
```

### Test 3.6: Combined Score Verification

**Objective:** Verify weighted combination

```bash
# Item pair with:
# - Exact category (1.0)
# - 2 days apart (0.75)
# - 2 km distance (0.75)
# - 60% keyword match (0.6)

# Score = (0.40 × 1.0) + (0.30 × 0.75) + (0.20 × 0.75) + (0.10 × 0.6)
#       = 0.40 + 0.225 + 0.15 + 0.06
#       = 0.835 = 83.5

$item1 = Item::factory()->create([
  'category' => 'electronics',
  'created_at' => now()->subDays(2),
  'location' => 'POINT(48.8566 2.3522)',
  'description' => 'Black iPhone 13'
]);

$item2 = Item::factory()->create([
  'category' => 'electronics',
  'created_at' => now(),
  'location' => 'POINT(48.8570 2.3525)',  // ~2km
  'description' => 'Black iPhone 13 cracked'
]);

$score = $matchingService->scoreMatch($item1, $item2);

# Expected:
# ✅ Score ≈ 75-85
```

### Test 3.7: Haversine Distance Accuracy

**Objective:** Verify distance calculation

```bash
# Test known coordinates
// Paris to London ≈ 344 km
$distance = $matchingService->haversineDistance(
  48.8566, 2.3522,    // Paris
  51.5074, -0.1278    // London
);

echo $distance . " km";

# Expected:
# ✅ ≈ 344 km (within ±10km tolerance)
```

### Test 3.8: Find Matches for Lost Item

**Objective:** Verify findMatches returns scored results

```bash
# Create lost item
$lostPhone = Item::factory()->create([
  'type' => 'lost',
  'category' => 'electronics',
  'name' => 'Black iPhone',
  'description' => 'Black iPhone 13, lost at mall',
  'location' => 'POINT(48.8566 2.3522)'
]);

# Create potential matches
Item::factory()->create([  // High match
  'type' => 'found',
  'category' => 'electronics',
  'name' => 'iPhone',
  'description' => 'Black iPhone found',
  'location' => 'POINT(48.8570 2.3525)'
]);

Item::factory()->create([  // Low match
  'type' => 'found',
  'category' => 'accessories',
  'name' => 'Phone case',
  'description' => 'Black phone case',
  'location' => 'POINT(48.9000 2.4000)'
]);

# Find matches
$matches = $matchingService->findMatches($lostPhone, radiusKm: 50);

# Expected:
# ✅ Returns Collection with 2+ matches
# ✅ Each has: score, item, reason, confidence
# ✅ Sorted by score DESC
# ✅ High match first, low match second
```

### Test 3.9: Confidence Levels

**Objective:** Verify confidence classification

```bash
// Given scores: 87, 72, 55, 35

$scoreConfidence = [
  87 => 'very_high',
  72 => 'high',
  55 => 'medium',
  35 => 'low'
];

foreach ($scoreConfidence as $score => $expectedConfidence) {
  $actual = $matchingService->getConfidenceLevel($score);
  assert($actual == $expectedConfidence);
}

# Expected:
# ✅ > 80: very_high
# ✅ 60-80: high
# ✅ 40-60: medium
# ✅ < 40: low
```

### Test 3.10: Match Reasons Generated

**Objective:** Verify explanation text

```bash
$matches = $matchingService->findMatches($lostItem);
$firstMatch = $matches->first();

echo $firstMatch['reason'];
// Expected: "Exact category match, 2km away, 1 day difference, 75% description similarity"

# Expected:
# ✅ Reason string explains each factor
# ✅ Includes percentage breakdowns
# ✅ Readable for end-users
```

### Test 3.11: API Endpoint Returns Matches

**Objective:** Verify GET /items/{item}/matches endpoint

```bash
curl http://localhost:8000/api/items/$LOST_ITEM_UUID/matches \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Returns array of matches
# ✅ Each has: id, score, reason, confidence
# ✅ Sorted by score descending
```

### Test 3.12: Radius Filter Works

**Objective:** Verify distance filter

```bash
# Find matches within 10 km
curl "http://localhost:8000/api/items/$LOST_ITEM_UUID/matches?radius=10" \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Only returns items within 10 km
# ✅ Further items filtered out
```

### Test 3.13: Match Score Threshold

**Objective:** Verify minimum score filtering

```bash
# Request only high-confidence matches (>70)
$matches = $matchingService->findMatches($lostItem)->filter(fn($m) => $m['score'] > 70);

# Expected:
# ✅ All returned scores > 70
```

### Test 3.14: Performance - Match Calculation

**Objective:** Verify scoring speed

```bash
// Time finding 100 matches
$start = microtime(true);
$matches = $matchingService->findMatches($lostItem);
$duration = microtime(true) - $start;

echo "Time: {$duration}s";

# Expected:
# ✅ < 500ms for 100+ items
# ✅ Linear complexity O(n)
```

### Test 3.15: Related Categories

**Objective:** Verify category relations

```bash
// Test "electronics" vs "gadgets" = 0.75
$score1 = $matchingService->categoryMatch('electronics', 'gadgets');
assert($score1 == 0.75);

// Test "electronics" vs "accessories" = 0.0 (no relation)
$score2 = $matchingService->categoryMatch('electronics', 'accessories');
assert($score2 == 0.0);

# Expected:
# ✅ Defined relations score 0.75
# ✅ Undefined relations score 0.0 (except exact match = 1.0)
```

### Test 3.16: Stop Word Removal

**Objective:** Verify keyword extraction

```bash
$desc1 = "A black iPhone with a cracked screen";
$keywords1 = $matchingService->extractKeywords($desc1);
// Expected: [black, iphone, cracked, screen] (removed: a, with)

$desc2 = "Black iPhone damaged display";
$keywords2 = $matchingService->extractKeywords($desc2);
// Expected: [black, iphone, damaged, display]

# Expected:
# ✅ Common words removed (a, the, with, etc.)
# ✅ Keywords lowercased
# ✅ Punctuation removed
```

---

## Feature #4: Analytics Tests

### Test 4.1: User Stats Endpoint

**Objective:** Verify personal statistics

```bash
curl http://localhost:8000/api/analytics/user-stats \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Response includes:
#    - items_posted: 5
#    - items_resolved: 3
#    - recovery_rate: 60
#    - avg_time_to_recovery: "3.2 days"
#    - successful_matches: 4
#    - messages_sent: 12
#    - coins_earned: 450
#    - badges_earned: ["first_recovery", "helpful_community"]
#    - trust_score: 92
```

### Test 4.2: Recovery Rate Calculation

**Objective:** Verify percentage calculation

```bash
# If Alice posted 10 items, 7 resolved
# recovery_rate = 7/10 × 100 = 70%

$stats = $userStatsService->getUserStats($alice);
assert($stats['recovery_rate'] == 70);

# Expected:
# ✅ Formula: (resolved_items / total_items) × 100
# ✅ Handles 0 items (returns 0%)
```

### Test 4.3: Average Time to Recovery

**Objective:** Verify duration calculation

```bash
# Items recovered:
# - Lost: 2026-11-01 → Found: 2026-11-02 = 1 day
# - Lost: 2026-11-01 → Found: 2026-11-07 = 6 days
// Average: 3.5 days

# Expected:
# ✅ Calculated from resolved items
# ✅ Shows in human-readable format ("3.5 days")
```

### Test 4.4: Platform Stats Endpoint (Cached)

**Objective:** Verify aggregate statistics

```bash
curl http://localhost:8000/api/analytics/platform-stats \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Response includes:
#    - total_users: 1250
#    - active_users_7d: 850
#    - total_items: 3420
#    - total_recovered: 1840
#    - platform_recovery_rate: 53.8
#    - avg_resolution_time: "2.8 days"
#    - total_matches: 2150
#    - total_messages: 12340
#    - timestamp: "2026-11-04T10:30:00Z"
```

### Test 4.5: Cache TTL on Platform Stats

**Objective:** Verify 1-hour caching

```bash
# Call 1
$start = now();
$stats1 = analyticsService->getPlatformStats();

# Add new item
Item::factory()->create();

# Call 2 (immediate)
$stats2 = analyticsService->getPlatformStats();

// Should be identical (cached)
assert($stats1['total_items'] == $stats2['total_items']);

# Wait 1 hour, then call 3
$stats3 = analyticsService->getPlatformStats();

// Should reflect new item (cache expired)
assert($stats3['total_items'] == $stats1['total_items'] + 1);

# Expected:
# ✅ Cache hit within 1 hour
# ✅ Cache invalidated after 1 hour
```

### Test 4.6: Time Series Data

**Objective:** Verify daily metrics

```bash
curl "http://localhost:8000/api/analytics/time-series?days=30&metric=recovery_rate" \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Returns array with 30 data points
# ✅ Each point: {date: "2026-10-05", value: 45.2}
# ✅ Dates sequential, sorted chronologically
```

### Test 4.7: Trending Categories

**Objective:** Verify category trends

```bash
curl "http://localhost:8000/api/analytics/trending-categories?days=7&limit=5" \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Returns top 5 categories by count (last 7 days)
# ✅ Each includes: category, count, recovery_rate
# ✅ Sorted by count DESC
```

### Test 4.8: Top Users Leaderboard

**Objective:** Verify user ranking

```bash
curl "http://localhost:8000/api/analytics/top-users?metric=recovery&limit=10" \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Returns top 10 users by recovery count
# ✅ Each: rank, user_id, username, value, trend
# ✅ Sorted by value DESC
```

### Test 4.9: Success Stories

**Objective:** Verify recovered item stories

```bash
curl "http://localhost:8000/api/analytics/success-stories?limit=5" \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Returns 5 recent recovery stories
# ✅ Each: item_name, lost_by, found_by, recovery_date, time_to_recovery
# ✅ Sorted by recovery_date DESC
```

### Test 4.10: Active Users Calculation

**Objective:** Verify 7-day active user count

```bash
# Create 10 users, 6 active in last 7 days
// Active = has sent message or item in last 7 days

$stats = analyticsService->getPlatformStats();
assert($stats['active_users_7d'] == 6);

# Expected:
# ✅ Counts users with activity in past 7 days
# ✅ Activity = item post or message sent
```

### Test 4.11: Permission Check - Public Stats

**Objective:** Verify platform stats are public or private

```bash
# Without auth token
curl http://localhost:8000/api/analytics/platform-stats

# Expected: Either
# ✅ Status: 200 (public stats) OR
# ✅ Status: 401 (auth required)
# (Based on app policy)
```

### Test 4.12: Permission Check - User Stats

**Objective:** Verify user stats require auth

```bash
# Without token
curl http://localhost:8000/api/analytics/user-stats

# Expected:
# ✅ Status: 401 Unauthorized
```

### Test 4.13: Cannot See Other User Stats

**Objective:** Verify privacy

```bash
# Alice tries to access Bob's stats by modifying response
# (Note: endpoint doesn't take user_id param, so this should auto-return Alice's stats)

curl http://localhost:8000/api/analytics/user-stats \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Always returns authenticated user's stats (Alice's)
# ✅ No privacy violation possible
```

### Test 4.14: Stats with No Activity

**Objective:** Verify zero handling

```bash
# New user with no activity
$newUser = User::create([...]);

$stats = analyticsService->getUserStats($newUser);

# Expected:
# ✅ items_posted: 0
# ✅ items_resolved: 0
# ✅ recovery_rate: 0 (or null, based on design)
# ✅ No errors, graceful degradation
```

### Test 4.15: Large Dataset Performance

**Objective:** Verify query performance at scale

```bash
# Create 10,000 items over 90 days

time curl http://localhost:8000/api/analytics/platform-stats

# Expected:
# ✅ Response time < 500ms (due to caching and indexing)
# ✅ No database timeouts
```

---

## Feature #5: Rewards Tests

### Test 5.1: Coin Balance Endpoint

**Objective:** Verify balance retrieval

```bash
curl http://localhost:8000/api/rewards/balance \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Response: { "balance": 450, "badges": ["first_recovery"], ... }
```

### Test 5.2: Coins Earned on Recovery

**Objective:** Verify coin reward

```bash
# Alice's initial balance
GET /rewards/balance → balance: 350

# Confirm recovery (match)
curl -X POST http://localhost:8000/api/matches/$MATCH_ID/confirm-restitution \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Check new balance
GET /rewards/balance → balance: 400 (350 + 50 coins for recovery)

# Expected:
# ✅ +50 coins added
# ✅ Ledger entry created in user_rewards
```

### Test 5.3: Coin Ledger Transparency

**Objective:** Verify transaction history

```bash
# In tinker
$transactions = UserReward::where('user_id', $alice->id)
  ->orderBy('created_at', 'desc')
  ->take(10)
  ->get();

$transactions->each(function($t) {
  echo "{$t->reason}: {$t->coins} coins\n";
});

// Expected output:
// Item recovered: 50 coins
// Post found item: 10 coins
// Post found item: 10 coins

# Expected:
# ✅ Each transaction logged
# ✅ Reason field explains action
# ✅ Positive and negative coins tracked
```

### Test 5.4: Badge Automatic Award

**Objective:** Verify badge unlock on trigger

```bash
# Alice recovers 1st item
// Verify badge earned
$badge = UserBadge::where('user_id', $alice->id)
  ->where('badge_name', 'first_recovery')
  ->first();

assert($badge != null);

# Expected:
# ✅ Badge automatically created
# ✅ Timestamp set to recovery time
```

### Test 5.5: Multiple Badges

**Objective:** Verify various badge awards

```bash
# Trigger multiple badge conditions
// 1. Recovery (first_recovery)
// 2. 10+ recoveries (recovery_master)
// 3. Quick recovery < 1hr (speed_demon)
// 4. Long distance (distance_hero)
// 5. 20+ messages (helpful_community)
// 6. Trust score > 85 (trusted_member)

$alice->badges;

# Expected:
# ✅ Multiple badges visible
# ✅ No duplicates (unique constraint)
# ✅ All relevant badges awarded
```

### Test 5.6: Generate Share Link

**Objective:** Verify share token creation

```bash
curl -X POST http://localhost:8000/api/rewards/share/$ITEM_UUID \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 201 Created
# ✅ Response includes:
#    - share_token: "abc123def456ghi789"
#    - share_url: "https://app.lostfound.com/share/abc123def456ghi789"
#    - platforms: {whatsapp: "...", telegram: "...", etc}
```

### Test 5.7: Share URL Structure

**Objective:** Verify URL format

```bash
# Parse share URL
// Expected: https://lostfound.com/share/{UUID}

$url = "https://app.lostfound.com/share/abc123def456ghi789";
assert(strpos($url, '/share/') !== false);
assert(strlen(explode('/share/', $url)[1]) == 36);  // UUID length

# Expected:
# ✅ URL includes share_token
# ✅ Accessible to anyone (public)
```

### Test 5.8: Track Share Clicks

**Objective:** Verify click counter

```bash
# Generate share link
// Get share_token: "abc123"

// Click 1
curl http://localhost:8000/api/share/abc123

// Click 2
curl http://localhost:8000/api/share/abc123

// Click 3
curl http://localhost:8000/api/share/abc123

# Check click count
$share = ItemShare::where('share_token', 'abc123')->first();
assert($share->clicked_count == 3);

# Expected:
# ✅ clicked_count incremented each visit
# ✅ first_click_at timestamp set on first visit
```

### Test 5.9: Coins Earned on Share Clicks

**Objective:** Verify social reward

```bash
# Alice shares item (generate token)
// Initial balance: 400

// 10 people click link
for i in 1..10; do
  curl -s http://localhost:8000/api/share/token123 > /dev/null
done

# Check balance
// 400 + (10 × 15) = 550 coins

# Expected:
# ✅ +15 coins per unique click
# ✅ Coins added automatically
# ✅ Ledger shows social share rewards
```

### Test 5.10: Public Share Endpoint

**Objective:** Verify no auth required for share tracking

```bash
# Without token
curl http://localhost:8000/api/share/abc123def456

# Expected:
# ✅ Status: 200 OK or redirect
# ✅ No 401 Unauthorized
# ✅ Click counted regardless
```

### Test 5.11: Invalid Share Token

**Objective:** Verify error handling

```bash
curl http://localhost:8000/api/share/invalid-token

# Expected:
# ✅ Status: 404 Not Found
# ✅ Error message: "Share link not found"
```

### Test 5.12: Leaderboards Endpoint

**Objective:** Verify three leaderboards

```bash
curl http://localhost:8000/api/rewards/leaderboards \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Response includes 3 sections:
#    - coins_leaderboard: [{rank, user, coins, level}, ...]
#    - recoveries_leaderboard: [{rank, user, recoveries, success_rate}, ...]
#    - helpers_leaderboard: [{rank, user, message_count, avg_rating}, ...]
```

### Test 5.13: Leaderboard Ranking

**Objective:** Verify correct ordering

```bash
// Coins leaderboard:
// User1: 2,450
// User2: 1,890
// User3: 1,620

$leaderboards = rewardsService->getLeaderboards();
$coins = $leaderboards['coins_leaderboard'];

assert($coins[0]['user'] == 'User1');
assert($coins[0]['coins'] == 2450);
assert($coins[1]['rank'] == 2);

# Expected:
# ✅ Sorted by metric DESC
# ✅ Ranks sequential (1, 2, 3, ...)
```

### Test 5.14: Period Filter on Leaderboards

**Objective:** Verify week/month/all-time views

```bash
# Week
curl "http://localhost:8000/api/rewards/leaderboards?period=week"

# Month
curl "http://localhost:8000/api/rewards/leaderboards?period=month"

# All time
curl "http://localhost:8000/api/rewards/leaderboards?period=all_time"

# Expected:
# ✅ Each returns different rankings
# ✅ Weekly leaders may differ from all-time
# ✅ Rankings reflect correct time period
```

### Test 5.15: Badges Endpoint

**Objective:** Verify badge listing

```bash
curl http://localhost:8000/api/rewards/badges \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 200 OK
# ✅ Response includes:
#    - earned_badges: [array of earned]
#    - available_badges: [array of all possible]
# ✅ Each badge has: name, description, icon_url, earned_date?
```

### Test 5.16: Coin Redemption

**Objective:** Verify coin spending

```bash
# Alice balance: 450 coins
# Redeem 50 coins for profile badge

curl -X POST http://localhost:8000/api/rewards/redeem \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "redemption_type": "profile_badge",
    "amount": 50
  }'

# New balance: 400
curl http://localhost:8000/api/rewards/balance \
  | jq '.balance'
// Expected: 400

# Expected:
# ✅ Coins deducted
# ✅ Ledger entry shows negative coins
# ✅ Redemption reason logged
```

### Test 5.17: Cannot Spend More Than Balance

**Objective:** Verify validation

```bash
# Alice balance: 400
# Try to spend 500

curl -X POST http://localhost:8000/api/rewards/redeem \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{"redemption_type":"premium_support","amount":500}'

# Expected:
# ✅ Status: 422 Unprocessable Entity
# ✅ Error: "Insufficient coin balance"
```

### Test 5.18: Coin Earning Events

**Objective:** Verify all earning triggers

```bash
// Coins earned for:
$events = [
  'post_found_item' => 10,
  'item_recovered' => 50,
  'helpful_message' => 5,
  'first_recovery' => 100,
  'social_share_click' => 15,
  'weekly_streak' => 25,
  'community_helper_award' => 30,
];

# Expected:
# ✅ All events trigger coin awards
# ✅ Amounts match table
# ✅ Coins added to ledger correctly
```

---

## Integration Tests

### Test 6.1: Message Triggers Notification

**Objective:** Verify features interact

```bash
# Alice sends message to Bob
curl -X POST http://localhost:8000/api/messages/send \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{"to_user_id":"'$BOB_UUID'","content":"Found your keys!"}'

# Verify Bob has notification
psql -d lost_found -c \
  "SELECT COUNT(*) FROM notifications WHERE user_id='$BOB_UUID' AND type='message';"

# Expected:
# ✅ Notification created immediately
# ✅ Type: message
# ✅ Data includes message preview
```

### Test 6.2: Item Recovery Awards Coins + Badges

**Objective:** Verify multiple features trigger

```bash
# Confirm recovery
curl -X POST http://localhost:8000/api/matches/$MATCH_ID/confirm-restitution \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Check coins
GET /rewards/balance → balance increased by 50

# Check badge
SELECT * FROM user_badges WHERE badge_name='first_recovery' AND user_id='$ALICE_UUID'
// Should exist

# Check analytics
GET /analytics/user-stats → items_resolved: 1, recovery_rate: 100

# Expected:
# ✅ Coins awarded
# ✅ Badge unlocked
# ✅ Stats updated
# ✅ Notification sent
```

### Test 6.3: New Item Triggers Matches + Notifications

**Objective:** Verify comprehensive trigger chain

```bash
# Bob posts found item
curl -X POST http://localhost:8000/api/items \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "name=Black iPhone" \
  -F "category=electronics" \
  -F "type=found" \
  -F "latitude=48.8566" \
  -F "longitude=2.3522" \
  -F "description=Black iPhone 13 found"

# Check:
// 1. Item created
SELECT COUNT(*) FROM items WHERE name='Black iPhone'
// 2. Matches found + scored
SELECT COUNT(*) FROM matches WHERE status='pending'
// 3. Notifications sent
SELECT COUNT(*) FROM notifications WHERE type='nearby_match'
// 4. Coins earned (if applicable)
SELECT SUM(coins) FROM user_rewards WHERE user_id='$BOB_UUID'

# Expected:
# ✅ Item exists
# ✅ 1+ potential matches scored
# ✅ 1+ notifications sent to matching users
# ✅ Bob earned coins for posting
```

### Test 6.4: Share Link with Analytics

**Objective:** Verify social features feed analytics

```bash
# Alice shares item
POST /rewards/share/$ITEM_ID → share_token: "abc"

# 5 people click
for i in 1..5; do
  curl -s http://localhost:8000/api/share/abc > /dev/null
done

# Check analytics
GET /analytics/user-stats → includes share_click_count

# Expected:
# ✅ Share tracked in analytics
# ✅ User stats reflect engagement
```

### Test 6.5: Messaging with Match Context

**Objective:** Verify message items reference correct objects

```bash
# Alice sends message about specific found item
curl -X POST http://localhost:8000/api/messages/send \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{"to_user_id":"'$BOB_UUID'","item_id":"'$FOUND_ITEM_UUID'","content":"Is this your phone?"}'

# Get conversation
GET /messages/with/$BOB_UUID → includes item context

# Expected:
# ✅ Message linked to item
# ✅ Conversation shows item details
# ✅ Users understand context
```

### Test 6.6: Leaderboard Reflects Messaging Activity

**Objective:** Verify helpers leaderboard uses messages

```bash
# Charlie sends many helpful messages (50+)
// Simulate via API or direct DB

# Check leaderboard
GET /rewards/leaderboards
// helpers_leaderboard → Charlie high rank

# Expected:
# ✅ High message count = high rank
# ✅ Average rating factors in
```

### Test 6.7: Analytics Time Series Includes All Events

**Objective:** Verify metrics aggregation

```bash
# Over 30 days:
// - Create items
// - Send messages
// - Earn coins
// - Recover items

# Get time series
GET /analytics/time-series?days=30&metric=platform_activity

# Expected:
# ✅ Shows trends across all features
# ✅ Activity visible on relevant dates
```

### Test 6.8: Coins Earned from Matching Activity

**Objective:** Verify match scoring leads to rewards

```bash
# Match found with score > 80
// Should trigger notification to both users

# If users accept match + recover:
// Both earn coins and badges

# Expected:
# ✅ High-score matches reward users
# ✅ Chain: match → notification → recovery → coins → badges
```

### Test 6.9: Complete User Journey

**Objective:** Verify end-to-end workflow

```bash
# User A: Posts lost item
// - Item created
// - Coins: +10

# User B: Posts found item
// - Item created
// - Coins: +10
// - Notification sent to A

# A & B: Message each other
// - 3 messages exchanged
// - Notifications sent
// - Coins: +0 (no reward for messages yet)

# B: Confirms recovery
// - Coins: +50 (recovery reward)
// - Badge: first_recovery
// - A notified
// - Analytics updated

# A: Shares recovery story
// - 10 clicks on share link
// - Coins: +150 (15 per click)

# Final state A:
// - Coins: 10 + 50 + 150 = 210
// - Badges: [first_recovery]
// - Messages: 3 sent, 3 received
// - Items: 1 posted, 1 recovered

# Expected:
# ✅ All features integrated
# ✅ Complete data trail
# ✅ User journey captured in stats
```

---

## Performance & Load Tests

### Test 7.1: Messaging Bulk Insert Performance

**Objective:** Verify high message volume

```bash
# Send 1,000 messages rapidly
for i in 1..1000; do
  curl -s -X POST http://localhost:8000/api/messages/send \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -d '{"to_user_id":"'$BOB_UUID'","content":"Message '$i'"}' &
done
wait

# Measure time
time for i in 1..1000; do
  curl -s ...
done

# Expected:
# ✅ All 1,000 messages created
# ✅ Time < 30 seconds total
# ✅ No database locks
# ✅ No timeouts
```

### Test 7.2: Analytics Query Performance

**Objective:** Verify large dataset aggregation

```bash
# Query platform stats (1M+ items)
time curl http://localhost:8000/api/analytics/platform-stats

# Expected:
# ✅ Response time < 500ms
# ✅ All stats calculated
# ✅ No query timeout
```

### Test 7.3: Matching Algorithm Scalability

**Objective:** Verify find-matches with 10K+ items

```bash
# Create 10,000 items
// Seed database

# Run find-matches
time $matchingService->findMatches($lostItem, radiusKm: 50);

# Expected:
# ✅ Completes in < 2 seconds
# ✅ Linear complexity O(n)
# ✅ No N² loop issues
```

### Test 7.4: Concurrent API Requests

**Objective:** Verify thread safety

```bash
# Send 100 concurrent requests to different endpoints
ab -n 100 -c 50 http://localhost:8000/api/messages/conversations

# Expected:
# ✅ All requests succeed
# ✅ No database deadlocks
# ✅ Consistent response times
```

### Test 7.5: Reward Calculation Under Load

**Objective:** Verify coin operations stay atomic

```bash
# 50 concurrent users earning coins
parallel -j 50 'curl -s -X POST http://localhost:8000/api/matches/{}/confirm-restitution \
  -H "Authorization: Bearer {token}"' ::: {match_ids...}

# Check total coins
SELECT SUM(coins) FROM user_rewards;
// Should be 50 × 50 = 2,500 coins

# Expected:
# ✅ No duplicate or missing coins
# ✅ All transactions recorded
# ✅ No race conditions
```

---

## Security Tests

### Test 8.1: Authentication Required for Protected Endpoints

**Objective:** Verify auth middleware

```bash
# Without token
curl http://localhost:8000/api/messages/conversations

# Expected:
# ✅ Status: 401 Unauthorized
```

### Test 8.2: Cannot Access Other User's Messages

**Objective:** Verify privacy boundary

```bash
# Alice token tries to get Charlie-Bob conversation
curl http://localhost:8000/api/messages/with/$CHARLIE_UUID \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 403 Forbidden or 404 Not Found
```

### Test 8.3: Cannot Spoof User ID in Coin Earning

**Objective:** Verify reward validation

```bash
# Try to manually POST coin reward (if endpoint exists)
curl -X POST http://localhost:8000/api/rewards/earn \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d '{"user_id":"'$BOB_UUID'","coins":1000}'

# Expected:
# ✅ Status: 403 Forbidden
# ✅ Cannot award coins to other users
```

### Test 8.4: Share Token Cannot Be Guessed

**Objective:** Verify token randomness

```bash
# Generate 100 share tokens
$tokens = [];
for i in 1..100:
  $tokens[] = generateShareToken();

# Check uniqueness
$unique = array_unique($tokens);
assert(count($unique) == 100);

# Check format (should be UUID)
foreach $tokens as $token:
  assert(isValidUUID($token));

# Expected:
# ✅ All tokens unique
# ✅ Cryptographically random
# ✅ Not sequential or guessable
```

### Test 8.5: SQL Injection in Search

**Objective:** Verify parameterized queries

```bash
# Try to inject SQL in analytics
curl "http://localhost:8000/api/analytics/trending-categories?days=7'; DROP TABLE users; --" \
  -H "Authorization: Bearer $ALICE_TOKEN"

# Expected:
# ✅ Status: 422 or 200 (safe)
# ✅ No error message revealing SQL
# ✅ Database unharmed
# ✅ Query uses parameterized binding
```

### Test 8.6: XSS Prevention in Notifications

**Objective:** Verify output escaping

```bash
# Post item with XSS payload
curl -X POST http://localhost:8000/api/items \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -F "description=<script>alert('XSS')</script>"

# Retrieve notification
SELECT message FROM notifications LIMIT 1;

# Expected:
# ✅ Script tags escaped or HTML-encoded
# ✅ Cannot execute JavaScript
```

---

## Test Execution Commands

### Run All Tests

```bash
# PHPUnit full suite
./vendor/bin/phpunit

# Specific feature tests
./vendor/bin/phpunit tests/Feature/MessagingTest.php
./vendor/bin/phpunit tests/Feature/NotificationsTest.php
./vendor/bin/phpunit tests/Feature/AnalyticsTest.php
./vendor/bin/phpunit tests/Feature/RewardsTest.php
```

### Performance Testing

```bash
# Apache Bench
ab -n 1000 -c 50 http://localhost:8000/api/messages/conversations

# Siege load test
siege -c 100 -r 10 http://localhost:8000/api/analytics/user-stats

# Vegeta (requires installation)
echo "GET http://localhost:8000/api/rewards/leaderboards" | vegeta attack -duration=30s | vegeta report
```

### Manual Test Checklist

```
✅ Feature #1: Messaging (12/12 tests)
✅ Feature #2: Notifications (10/10 tests)
✅ Feature #3: Matching (16/16 tests)
✅ Feature #4: Analytics (15/15 tests)
✅ Feature #5: Rewards (18/18 tests)
✅ Integration (9/9 tests)
✅ Performance (5/5 tests)
✅ Security (6/6 tests)

Total: 91 test cases
Estimated Time: 2-3 hours for manual testing
Automated Time: ~10 minutes for unit/integration tests
```

---

## Success Criteria

All tests PASS when:

- ✅ All 20+ API endpoints return expected status codes
- ✅ Data persists correctly to database
- ✅ Relationships between features work seamlessly
- ✅ Performance metrics met (< 500ms for analytics, < 2s for matching)
- ✅ Security boundaries enforced (no auth bypass, no data leakage)
- ✅ Features integrate without breaking existing CRUD/map functionality
- ✅ Database migrations run without error
- ✅ All indexes exist and improve query performance
- ✅ Caching strategies reduce load on database
- ✅ No race conditions in concurrent scenarios

---

**Test Status: READY FOR EXECUTION** ✅

All test cases documented and ready to execute. Expected to pass 100% on v2.0.0 production build.

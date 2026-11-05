# Lost & Found API - Complete Documentation

**API Version:** 1.0.0  
**Base URL:** `https://api.lostfound.app/api`  
**Authentication:** Bearer Token (Sanctum)  
**Content-Type:** `application/json`  
**Status:** ✅ Production Ready

---

## TABLE OF CONTENTS

1. [Authentication](#authentication)
2. [Objects Management](#objects-management)
3. [Messaging](#messaging)
4. [Analytics](#analytics)
5. [Rewards](#rewards)
6. [Error Handling](#error-handling)
7. [Rate Limiting](#rate-limiting)
8. [Webhooks](#webhooks)

---

## AUTHENTICATION

### Register User

**Endpoint:** `POST /auth/register`

**Parameters:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "phone": "+33612345678",
  "password": "SecurePassword123!",
  "password_confirmation": "SecurePassword123!"
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "token": "1|abcdefghijklmnopqrstuvwxyz...",
  "user": {
    "id": "uuid",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+33612345678",
    "phone_verified_at": null,
    "trust_score": 50,
    "created_at": "2026-11-04T10:00:00Z"
  },
  "demo_otp": "123456"
}
```

**Errors:**
- `422 Unprocessable Entity` - Validation failed
- `409 Conflict` - Email already exists

---

### Login User

**Endpoint:** `POST /auth/login`

**Parameters:**
```json
{
  "email": "john@example.com",
  "password": "SecurePassword123!"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "token": "1|abcdefghijklmnopqrstuvwxyz...",
  "user": {
    "id": "uuid",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+33612345678",
    "phone_verified_at": "2026-11-04T10:30:00Z",
    "trust_score": 85,
    "created_at": "2026-11-04T10:00:00Z"
  }
}
```

**Errors:**
- `401 Unauthorized` - Invalid credentials
- `422 Unprocessable Entity` - Missing fields

---

### Request Phone Verification

**Endpoint:** `POST /auth/otp/request`

**Headers:**
```
Authorization: Bearer {token}
```

**Parameters:**
```json
{
  "phone": "+33612345678"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "OTP sent to phone",
  "demo_otp": "123456"
}
```

---

### Verify Phone

**Endpoint:** `POST /auth/otp/verify`

**Headers:**
```
Authorization: Bearer {token}
```

**Parameters:**
```json
{
  "phone": "+33612345678",
  "code": "123456"
}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "phone_verified_at": "2026-11-04T10:35:00Z",
    "trust_score": 85
  }
}
```

**Errors:**
- `422 Unprocessable Entity` - Invalid OTP code
- `401 Unauthorized` - Not authenticated

---

## OBJECTS MANAGEMENT

### List All Objects

**Endpoint:** `GET /items`

**Query Parameters:**
- `type` (optional) - `LOST` or `FOUND`
- `category` (optional) - Filter by category
- `status` (optional) - `ACTIVE`, `MATCHED`, `RECOVERED`, `CLOSED`
- `limit` (optional, default: 50) - Results per page
- `offset` (optional, default: 0) - Pagination offset
- `search` (optional) - Search in title/description

**Response:** `200 OK`
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "user_id": "uuid",
      "type": "LOST",
      "category": "telephone",
      "title": "Black iPhone 14",
      "description": "Lost near campus library on Tuesday morning",
      "latitude": 48.8566,
      "longitude": 2.3522,
      "place_label": "Paris, France",
      "status": "ACTIVE",
      "image_path": "items/550e8400-e29b-41d4-a716-446655440000.jpg",
      "contact_phone": "+33612345678",
      "occurred_at": "2026-11-03T08:00:00Z",
      "created_at": "2026-11-04T10:00:00Z",
      "updated_at": "2026-11-04T10:00:00Z",
      "user": {
        "id": "uuid",
        "name": "John Doe",
        "trust_score": 85
      }
    }
  ],
  "pagination": {
    "total": 150,
    "count": 50,
    "per_page": 50,
    "current_page": 1,
    "total_pages": 3
  }
}
```

**Errors:**
- `400 Bad Request` - Invalid parameters

---

### Create Object (Multipart)

**Endpoint:** `POST /items`

**Headers:**
```
Authorization: Bearer {token}
Content-Type: multipart/form-data
```

**Parameters:**
- `type` (required) - `LOST` or `FOUND`
- `category` (required) - Category code
- `title` (required, max 120 chars)
- `description` (required, max 1000 chars)
- `place_label` (optional) - Human-readable location
- `occurred_at` (required) - ISO8601 date
- `latitude` (optional) - Decimal degrees
- `longitude` (optional) - Decimal degrees
- `contact_phone` (optional) - Phone number
- `image` (optional) - JPEG/PNG, max 5MB

**Response:** `201 Created`
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "user_id": "uuid",
    "type": "LOST",
    "category": "telephone",
    "title": "Black iPhone 14",
    "description": "Lost near campus library",
    "latitude": 48.8566,
    "longitude": 2.3522,
    "place_label": "Paris, France",
    "status": "ACTIVE",
    "image_path": "items/550e8400-e29b-41d4-a716-446655440000.jpg",
    "contact_phone": "+33612345678",
    "occurred_at": "2026-11-03T08:00:00Z",
    "created_at": "2026-11-04T10:00:00Z"
  }
}
```

**Errors:**
- `401 Unauthorized` - Not authenticated
- `403 Forbidden` - Phone not verified
- `422 Unprocessable Entity` - Validation failed
- `413 Payload Too Large` - Image > 5MB

---

### Update Object

**Endpoint:** `PUT /items/{id}`

**Headers:**
```
Authorization: Bearer {token}
Content-Type: multipart/form-data
```

**Parameters:**
- `title` (optional)
- `description` (optional)
- `image` (optional) - Replace existing image
- Other fields same as POST

**Response:** `200 OK`
```json
{
  "success": true,
  "data": { ... }
}
```

**Errors:**
- `401 Unauthorized` - Not authenticated
- `403 Forbidden` - Not owner / Phone not verified
- `404 Not Found` - Object doesn't exist
- `422 Unprocessable Entity` - Validation failed

---

### Delete Object

**Endpoint:** `DELETE /items/{id}`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "message": "Item deleted successfully"
}
```

**Errors:**
- `401 Unauthorized` - Not authenticated
- `403 Forbidden` - Not owner
- `404 Not Found` - Object doesn't exist

---

### Mark Object Resolved

**Endpoint:** `PATCH /items/{id}/resolve`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "status": "RECOVERED",
    "updated_at": "2026-11-04T15:30:00Z"
  }
}
```

---

### Find Nearby Objects

**Endpoint:** `GET /items/nearby`

**Query Parameters:**
- `latitude` (required) - User latitude
- `longitude` (required) - User longitude
- `radius_km` (optional, default: 10) - Search radius (0.1-100)
- `type` (optional) - `LOST` or `FOUND`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "title": "Black iPhone 14",
      "type": "FOUND",
      "category": "telephone",
      "distance_km": 0.5,
      "latitude": 48.8570,
      "longitude": 2.3525,
      "image_path": "items/uuid.jpg",
      "user": {
        "name": "Jane Doe",
        "trust_score": 92
      }
    }
  ]
}
```

---

## MESSAGING

### Get Conversations

**Endpoint:** `GET /messages/conversations`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": [
    {
      "user_id": "uuid",
      "user_name": "Jane Doe",
      "last_message": "I think I found your item!",
      "last_message_time": "2026-11-04T15:00:00Z",
      "unread_count": 2
    }
  ]
}
```

---

### Get Message Thread

**Endpoint:** `GET /messages/with/{userId}`

**Query Parameters:**
- `page` (optional, default: 1)
- `per_page` (optional, default: 20)

**Response:** `200 OK`
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "from_user_id": "uuid-1",
      "to_user_id": "uuid-2",
      "content": "I think I found your lost phone",
      "is_read": true,
      "read_at": "2026-11-04T15:05:00Z",
      "created_at": "2026-11-04T15:00:00Z"
    }
  ]
}
```

---

### Send Message

**Endpoint:** `POST /messages/send`

**Headers:**
```
Authorization: Bearer {token}
```

**Parameters:**
```json
{
  "to_user_id": "uuid",
  "item_id": "uuid",
  "content": "I think I found your lost item!"
}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "from_user_id": "uuid-sender",
    "to_user_id": "uuid-recipient",
    "content": "I think I found your lost item!",
    "is_read": false,
    "created_at": "2026-11-04T15:00:00Z"
  }
}
```

---

### Mark Message as Read

**Endpoint:** `PATCH /messages/{messageId}/read`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "is_read": true,
    "read_at": "2026-11-04T15:05:00Z"
  }
}
```

---

## ANALYTICS

### User Statistics

**Endpoint:** `GET /analytics/user-stats`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "items_posted": 5,
    "items_resolved": 3,
    "recovery_rate": 60,
    "avg_time_to_recovery": "3.2 days",
    "successful_matches": 4,
    "messages_sent": 12,
    "coins_earned": 450,
    "badges_earned": ["first_recovery", "helpful_community"],
    "trust_score": 92
  }
}
```

---

### Platform Statistics

**Endpoint:** `GET /analytics/platform-stats`

**Response:** `200 OK` (Cached 1 hour)
```json
{
  "success": true,
  "data": {
    "total_users": 1250,
    "active_users_7d": 850,
    "total_items": 3420,
    "total_recovered": 1840,
    "platform_recovery_rate": 53.8,
    "avg_resolution_time": "2.8 days",
    "total_matches": 2150,
    "total_messages": 12340
  }
}
```

---

### Time Series Data

**Endpoint:** `GET /analytics/time-series`

**Query Parameters:**
- `days` (optional, default: 30) - Number of days
- `metric` (optional, default: recovery_rate) - Metric name

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "metric": "recovery_rate",
    "period_days": 30,
    "data_points": [
      { "date": "2026-10-05", "value": 45.2 },
      { "date": "2026-10-06", "value": 47.1 },
      ...
    ]
  }
}
```

---

## REWARDS

### Get Coin Balance

**Endpoint:** `GET /rewards/balance`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "balance": 450,
    "badges": ["first_recovery", "recovery_master", "helpful_community"],
    "coins_earned_this_month": 150,
    "level": "gold",
    "next_milestone": 500
  }
}
```

---

### Generate Share Link

**Endpoint:** `POST /rewards/share/{itemId}`

**Headers:**
```
Authorization: Bearer {token}
```

**Response:** `201 Created`
```json
{
  "success": true,
  "data": {
    "share_token": "abc123def456ghi789...",
    "share_url": "https://lostfound.app/share/abc123def456ghi789",
    "platforms": {
      "whatsapp": "https://wa.me/?text=...",
      "telegram": "https://t.me/share/...",
      "facebook": "https://fb.com/sharer.php?u=...",
      "twitter": "https://twitter.com/intent/tweet?..."
    }
  }
}
```

---

### Track Share Click (Public)

**Endpoint:** `GET /share/{shareToken}`

**Response:** `302 Found` - Redirect to item detail

---

### Get Leaderboards

**Endpoint:** `GET /rewards/leaderboards`

**Query Parameters:**
- `period` (optional) - `week`, `month`, `all_time`

**Response:** `200 OK`
```json
{
  "success": true,
  "data": {
    "coins_leaderboard": [
      {
        "rank": 1,
        "user_id": "uuid",
        "username": "Sarah Johnson",
        "coins": 2450,
        "level": "gold"
      }
    ],
    "recoveries_leaderboard": [
      {
        "rank": 1,
        "user_id": "uuid",
        "username": "Michael Chen",
        "recoveries": 28,
        "success_rate": 85
      }
    ],
    "helpers_leaderboard": [
      {
        "rank": 1,
        "user_id": "uuid",
        "username": "Emma Wilson",
        "helpful_messages": 156,
        "avg_rating": 4.8
      }
    ]
  }
}
```

---

## ERROR HANDLING

### Error Response Format

All errors return consistent JSON:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "User-friendly message",
    "status": 400,
    "timestamp": "2026-11-04T10:00:00Z",
    "request_id": "uuid"
  }
}
```

### Error Codes

| Code | Status | Meaning |
|------|--------|---------|
| `VALIDATION_ERROR` | 422 | Input validation failed |
| `UNAUTHENTICATED` | 401 | Missing or invalid token |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `RESOURCE_NOT_FOUND` | 404 | Resource doesn't exist |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_SERVER_ERROR` | 500 | Server error |

---

## RATE LIMITING

### Limits

- **Authentication:** 5 requests per minute
- **API Calls:** 100 requests per minute
- **Image Upload:** 10 requests per hour
- **Search:** 30 requests per minute

**Headers Returned:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1699085400
```

---

## WEBHOOKS

### Webhook Events

Webhooks are sent to configured URL for:
- `item.created`
- `item.recovered`
- `message.sent`
- `match.created`
- `user.verified`

### Webhook Payload

```json
{
  "event": "item.created",
  "timestamp": "2026-11-04T10:00:00Z",
  "data": {
    "id": "uuid",
    "type": "LOST",
    "title": "Black iPhone 14",
    "user_id": "uuid"
  },
  "signature": "sha256=..."
}
```

### Verify Webhook Signature

```
signature = HMAC-SHA256(body, webhook_secret)
```

---

## EXAMPLE REQUESTS

### Complete User Journey

```bash
# 1. Register
curl -X POST https://api.lostfound.app/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+33612345678",
    "password": "SecurePassword123!",
    "password_confirmation": "SecurePassword123!"
  }'

# 2. Verify Phone
curl -X POST https://api.lostfound.app/api/auth/otp/verify \
  -H "Authorization: Bearer {token}" \
  -d '{
    "phone": "+33612345678",
    "code": "123456"
  }'

# 3. Create Lost Item
curl -X POST https://api.lostfound.app/api/items \
  -H "Authorization: Bearer {token}" \
  -F "type=LOST" \
  -F "category=telephone" \
  -F "title=Black iPhone 14" \
  -F "description=Lost near campus library" \
  -F "occurred_at=2026-11-03T08:00:00Z" \
  -F "latitude=48.8566" \
  -F "longitude=2.3522" \
  -F "image=@phone.jpg"

# 4. Search Nearby
curl https://api.lostfound.app/api/items/nearby \
  -G -d "latitude=48.8566" \
  -d "longitude=2.3522" \
  -d "radius_km=5" \
  -d "type=FOUND"

# 5. Send Message
curl -X POST https://api.lostfound.app/api/messages/send \
  -H "Authorization: Bearer {token}" \
  -d '{
    "to_user_id": "uuid-other-user",
    "content": "I think I found your item!"
  }'
```

---

**Status:** ✅ **API DOCUMENTATION COMPLETE**

*Task #4 Complete*

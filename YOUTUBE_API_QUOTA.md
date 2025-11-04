# YouTube API Quota Guide

## ⚠️ Critical Information: You Can Only Upload ~6 Videos Per Day

**TL;DR:** YouTube Data API v3 has a **10,000 units/day quota limit** for new projects. Each video upload costs **1,600 units**, meaning you can only upload about **6 videos per day** before hitting the quota limit. To upload your 80+ recordings, you'll need to either:
1. **Request a quota increase** (requires phone + ID verification, 3-5 day approval)
2. **Use browser manual upload** (no API quota used, but limited to 15 videos at once)
3. **Spread uploads over multiple days** (6 videos/day)

---

## Understanding YouTube API Quotas

### Default Quota Allocation

- **Daily Quota**: 10,000 units per project
- **Reset Time**: Midnight Pacific Time (PST/PDT)
- **Scope**: Per Google Cloud project (not per user)
- **Applies To**: All API requests, including failed/invalid ones

### Quota Costs by Operation

| Operation | Quota Cost | Example |
|-----------|------------|---------|
| **Video Upload** | **1,600 units** | `videos.insert()` |
| Video Update | 50 units | Change title/description |
| Video Delete | 50 units | Remove video |
| Search Query | 100 units | Search for videos |
| List Videos | 1 unit | Get video details |
| List Playlists | 1 unit | Get playlists |
| Comment Insert | 50 units | Post comment |
| Comment List | 1 unit | Read comments |

**Source**: [YouTube Data API v3 - Quota Calculator](https://developers.google.com/youtube/v3/determine_quota_cost)

### Upload Calculation for This Project

With 80+ Ebiten example recordings:

```
Daily quota:    10,000 units
Upload cost:     1,600 units per video
─────────────────────────────
Max uploads/day: 10,000 ÷ 1,600 = 6.25 videos/day

To upload 80 videos: 80 ÷ 6 = ~14 days
```

**Reality Check**: After uploading 6 videos, the 7th upload will fail with:
```
HTTP 403: quotaExceeded
Daily Limit Exceeded. The quota will be reset at midnight Pacific Time (PT).
```

---

## What Happens When You Exceed Quota

### Immediate Effects

1. **API Requests Blocked**: All requests return `403 quotaExceeded` error
2. **No Degradation**: Service doesn't slow down, it completely stops
3. **Automatic Reset**: Quota resets at midnight PT (not 24 hours from first use)
4. **No Rollover**: Unused quota doesn't carry over to next day

### Error Response Example

```json
{
  "error": {
    "code": 403,
    "message": "The request cannot be completed because you have exceeded your quota.",
    "errors": [{
      "domain": "youtube.quota",
      "reason": "quotaExceeded",
      "message": "The request cannot be completed because you have exceeded your quota."
    }]
  }
}
```

### What the Tool Shows

```bash
$ make upload-youtube FILE=video7.avi
Uploading video7.avi to YouTube...
Title: Ebiten Example: video7
Error: Request failed with status code: 403
ERROR: quotaExceeded - Daily Limit Exceeded
```

---

## Verification Requirements

### Why Google Requires Verification

To prevent API abuse, Google requires verification at various stages:

### 1. OAuth Consent Screen Verification (Required for Public Apps)
- **When**: Publishing OAuth consent screen from "Testing" to "Production"
- **Requires**: Domain ownership verification
- **Not needed for**: Personal use with test users

### 2. Phone Verification (YouTube Channel Feature)
- **When**: Accessing intermediate YouTube channel features
- **Requires**: SMS or voice call to phone number
- **Purpose**: Prevent spam/bot accounts

### 3. ID/Passport Verification (Quota Increase Requests)
- **When**: Requesting quota increases above default
- **Requires**: Government-issued photo ID or passport
- **Purpose**: Verify identity for compliance audit
- **Processing Time**: Manual review, can take days

### 4. Compliance Audit (Quota Increase Required)
- **When**: Requesting quota >10,000 units/day
- **Requires**:
  - Demonstration of YouTube API Terms of Service compliance
  - Clear explanation of API usage
  - Privacy policy and terms of service
  - Data handling practices documentation
- **Submission**: Via [YouTube API Services - Audit and Quota Extension Form](https://support.google.com/youtube/contact/yt_api_form)

---

## Requesting Quota Increases

### Prerequisites

Before requesting an increase:

1. ✅ Project must be using the quota (can't request increase before hitting limit)
2. ✅ OAuth consent screen must be configured
3. ✅ Clear justification for increased quota
4. ✅ Compliance with YouTube API Terms of Service
5. ✅ Valid phone number and government ID ready

### Method 1: Google Cloud Console (Simple Requests)

1. Go to [Google Cloud Console - Quotas](https://console.cloud.google.com/iam-admin/quotas)
2. Filter for "YouTube Data API v3"
3. Select "Queries per day" quota
4. Click "Edit Quotas"
5. Enter requested quota (e.g., 100,000 units/day)
6. Provide justification
7. Submit request

### Method 2: YouTube API Services Audit Form (Large Requests)

For significant quota increases or commercial use:

1. Complete compliance audit: [YouTube API Services Audit Form](https://support.google.com/youtube/contact/yt_api_form)
2. Provide detailed usage explanation
3. Document compliance with [YouTube API Terms of Service](https://developers.google.com/youtube/terms/api-services-terms-of-service)
4. Include privacy policy and data handling practices
5. Wait 3-5 business days for review

### What to Include in Your Request

**For this project (uploading Ebiten example recordings):**

```
Project: ebiten-test
Requested Quota: 100,000 units/day
Justification:
- Educational/demo project showcasing Ebiten game engine examples
- Need to upload 80+ short gameplay recordings (10 seconds each)
- Current limit: 6 videos/day would take 14+ days
- Videos are original content, no copyright issues
- Personal use only, not commercial

Usage Pattern:
- One-time bulk upload of 80 videos (128,000 units)
- Minimal API usage after initial upload
- No automated/scripted abuse
```

### Approval Timeline

- **Simple increases**: 1-2 business days
- **Large increases**: 3-5 business days
- **Rejected requests**: Can resubmit with more details

### If Request is Denied

Common reasons and fixes:

| Reason | Solution |
|--------|----------|
| Insufficient justification | Provide more detailed use case |
| Doesn't comply with ToS | Review and address compliance issues |
| Suspected abuse pattern | Explain legitimate use case clearly |
| Incomplete OAuth setup | Complete consent screen configuration |

---

## Workarounds for Quota Limits

### Option 1: Manual Browser Upload (Recommended for Initial Batch)

**Pros:**
- ✅ No API quota used
- ✅ No phone/ID verification required
- ✅ Fast for small batches

**Cons:**
- ❌ Limited to 15 videos at once (YouTube Studio limit)
- ❌ Manual process (drag-and-drop)
- ❌ Repetitive for 80+ videos

**How to use:**
```bash
make upload-all-browser  # Opens YouTube Studio
# Drag and drop up to 15 .avi files at once
# Repeat 6 times for 80+ videos
```

### Option 2: Spread Uploads Over Multiple Days

**Pros:**
- ✅ No quota increase needed
- ✅ Works within free tier
- ✅ Automated once set up

**Cons:**
- ❌ Takes 14 days for 80 videos
- ❌ Requires running script daily

**How to use:**
```bash
# Day 1
make upload-youtube FILE=video1.avi
make upload-youtube FILE=video2.avi
# ... up to 6 videos

# Day 2
make upload-youtube FILE=video7.avi
# ... 6 more videos

# Continue for 14 days
```

### Option 3: Request Quota Increase (Best for Automation)

**Pros:**
- ✅ Upload all videos at once
- ✅ Future-proof for more content
- ✅ Fully automated workflow

**Cons:**
- ❌ Requires phone + ID verification
- ❌ 3-5 day approval wait
- ❌ Not guaranteed approval

**How to use:**
1. Request quota increase (see section above)
2. Wait for approval
3. Run: `make upload-all-youtube`

---

## Best Practices for Managing Quotas

### 1. Monitor Your Quota Usage

Check quota usage in Google Cloud Console:
- Go to [APIs & Services > Dashboard](https://console.cloud.google.com/apis/dashboard)
- Select "YouTube Data API v3"
- View "Queries per day" graph

### 2. Optimize API Calls

- **Batch operations**: Use `part` parameter to get only needed data
- **Cache results**: Store video IDs/metadata locally
- **Minimize searches**: Expensive at 100 units each
- **Use list operations**: Cheap at 1 unit each

### 3. Handle Quota Errors Gracefully

The `youtubeuploader` tool automatically handles quota errors:
- Detects `403 quotaExceeded` response
- Shows clear error message
- Stops batch uploads to prevent waste

### 4. Plan Upload Strategy

For this project's 80+ videos:

**Best approach:**
1. **Week 1**: Request quota increase + verify ID
2. **Week 2**: Once approved, batch upload all videos
3. **Fallback**: Manual browser upload (6 batches of 15 videos)

### 5. Cost-Benefit Analysis

| Strategy | Time | Effort | Cost |
|----------|------|--------|------|
| Manual browser upload | 30 min | Medium | $0 |
| Daily API uploads (14 days) | 14 days | Low (automated) | $0 |
| Quota increase + batch | 1 hour (after approval) | Low | $0 |

**Recommendation**: If you plan to upload more content regularly, request the quota increase. For one-time uploads, manual browser upload is fastest.

---

## Quota Increase Success Rate

Based on community reports:

- **Approved**: ~70% of legitimate requests
- **Denied**: ~20% (usually fixable with more details)
- **Ignored**: ~10% (resubmit after 1 week)

**Keys to approval:**
- Clear, honest use case explanation
- Compliance documentation
- Professional presentation
- Legitimate need (not abuse)

---

## Additional Resources

- [YouTube Data API Quota Calculator](https://developers.google.com/youtube/v3/determine_quota_cost)
- [YouTube API Services Terms of Service](https://developers.google.com/youtube/terms/api-services-terms-of-service)
- [Quota Increase Request Form](https://support.google.com/youtube/contact/yt_api_form)
- [Google Cloud Quotas Documentation](https://cloud.google.com/docs/quota)

---

## Summary

**Default Quota Reality:**
- 10,000 units/day = **6 videos/day maximum**
- Quota resets midnight Pacific Time
- Exceeding quota = complete API block until reset

**To Upload 80+ Videos:**
1. **Fast (30 min)**: Manual browser upload in batches of 15
2. **Patient (14 days)**: Automated daily uploads of 6 videos
3. **Professional (3-5 day wait)**: Request quota increase, then batch upload

**Verification Requirements:**
- Phone verification for channel features
- ID/Passport for quota increases
- Compliance audit for large increases

**Bottom Line**: YouTube's quota system is designed to prevent abuse, but it creates friction for legitimate users. Plan accordingly and choose the strategy that best fits your timeline and use case.

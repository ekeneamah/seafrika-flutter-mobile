# FFmpeg Installation Guide for Video Upload Feature

## Overview
The video upload feature (Task #15) requires ffmpeg to be installed on the server for thumbnail extraction and video processing.

## Installation Instructions

### Local Development (Windows)

1. **Download FFmpeg**:
   - Go to https://www.gyan.dev/ffmpeg/builds/
   - Download "ffmpeg-release-essentials.zip"

2. **Extract and Add to PATH**:
   ```powershell
   # Extract to C:\ffmpeg
   # Add C:\ffmpeg\bin to system PATH
   $env:Path += ";C:\ffmpeg\bin"
   ```

3. **Verify Installation**:
   ```bash
   ffmpeg -version
   ffprobe -version
   ```

### Production (Google Cloud Run)

Add to your `Dockerfile`:

```dockerfile
# Install ffmpeg
RUN apt-get update && \
    apt-get install -y ffmpeg && \
    rm -rf /var/lib/apt/lists/*
```

### Production (App Engine)

Add to `app.yaml`:

```yaml
runtime: nodejs20

# Install ffmpeg via custom runtime
build_env_variables:
  GOOGLE_BUILDABLE: "true"

# Or use flexible environment with custom Dockerfile
env: flex
runtime: custom
```

## Testing FFmpeg Installation

```bash
# Test thumbnail extraction
ffmpeg -i test-video.mp4 -ss 00:00:01 -vframes 1 -s 640x360 thumbnail.jpg

# Test video metadata
ffprobe test-video.mp4
```

## Video Upload Constraints

- **Max Duration**: 10 seconds
- **Max File Size**: 50MB
- **Allowed Formats**: MP4, MOV, AVI
- **Thumbnail**: Generated at 1s or 10% of duration (640x360px)
- **Moderation**: Thumbnail scanned via Google Vision API

## Troubleshooting

### Error: "ffmpeg: command not found"
- FFmpeg is not installed or not in PATH
- Install ffmpeg and restart backend server

### Error: "Failed to extract thumbnail"
- Video file may be corrupted
- Video codec may not be supported
- Check ffmpeg logs for details

### Error: "Video duration exceeds 10 seconds"
- User uploaded video longer than 10s
- Frontend validation should catch this, but backend enforces it

## Dependencies

```json
{
  "fluent-ffmpeg": "^2.1.3",
  "@types/fluent-ffmpeg": "^2.1.24"
}
```

## Backend Endpoint

```
POST /api/attachments/video/upload
Content-Type: multipart/form-data

Body:
- video: File (binary)
- conversationId: string

Response:
{
  "success": true,
  "video": {
    "url": "https://...",
    "thumbnailUrl": "https://...",
    "metadata": {
      "duration": 8.5,
      "width": 1920,
      "height": 1080,
      "size": 15728640,
      "format": "mp4",
      "bitrate": 2000000,
      "fps": 30
    }
  },
  "moderation": {
    "isSafe": true,
    "reasons": [],
    "scores": {}
  }
}
```

## Security

✅ Magic bytes validation (prevents file type spoofing)
✅ Duration validation (max 10s)
✅ File size validation (max 50MB)
✅ Google Vision API moderation (thumbnail)
✅ Backend-only upload (frontend cannot bypass validation)

---

**Last Updated**: October 19, 2025
**Feature**: Task #15 - Video Upload with Thumbnail Generation

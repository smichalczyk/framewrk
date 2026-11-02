# Changelog

## 1.3.4

- Speed up Aura uploads by removing unnecessary queue waits and fixed pauses. A repeat test of 15 photos across 69 frame deliveries completed in 59 seconds, down from 8 minutes 27 seconds; results depend on your library and connection.
- Upload to Aura and Nixplay concurrently while keeping requests within each service ordered and memory use bounded.
- Give each Framewrk installation its own persistent Aura device identity, preventing repeated authentication failures caused by a shared device identifier.
- Confirm Aura registers each uploaded asset before recording delivery, and improve authentication diagnostics without exposing credentials.
- Preserve cancellation, retry, and per-frame delivery tracking during concurrent uploads.

## 1.3.3

- Group Direct sends by delivery outcome, showing each frame once and explaining orientation skips with concise landscape-only or portrait-only labels.
- Open the Framewrk iPhone and iPad public beta: [Join on TestFlight](https://testflight.apple.com/join/HZ7kN8k9). Requires iOS/iPadOS 18+, your own Framewrk server over HTTPS, and an Aura or Nixplay account with a configured destination. PhotoPrism and Immich are optional for direct sends.
- Add beta setup requirements and feedback instructions to the website and public documentation.

## 1.3.2

- Identify Direct sends by their destination frames instead of photo filenames, and label the received time.

## 1.3.1

- Use the selected PhotoPrism primary image for library sync, preventing another file in a JPEG/RAW stack from supplying a developed RAW preview.

- Remove individual synced photos from Nixplay albums when they no longer match source or orientation rules. Existing uploads without remote IDs are supported.
- Verify removal before clearing tracking records, and preserve records when Nixplay returns an invalid listing or does not remove the photo.
- Correct removal support descriptions in the console, documentation, and website.

## 1.3.0

- Reuse service connections and resized images across bounded direct-send
  batches. Independent frame services can transfer concurrently, with ordered
  uploads within each service and the existing duplicate/retry protections.
- Enforce each frame's portrait/landscape rules for direct uploads, including
  EXIF rotation. Show skipped destinations in the server console.
- Add an optional, isolated review account with simulated destinations. It uses
  real server authentication, photo ingestion, resizing, previews, and durable
  jobs, without forwarding review photos to frame services.
- Simplify iOS Recent to confirm server receipt, remove filenames and per-frame
  delivery controls, and add optional account usernames. Add Select all and
  Deselect all to the app and Share Extension.

## 1.2.0

- Add direct photo uploads to Aura and Nixplay without a photo library. Durable
  jobs, per-frame delivery status, retry handling, and duplicate protection keep
  explicit sends independent of PhotoPrism and Immich cleanup.
- Add the Framewrk iPhone/iPad app and Photos Share Extension, with background
  uploads, frame selection, delivery history, and secure device tokens.
- Add Direct sends and connected devices to the console. Include direct photos
  in Wall previews and counts, and support revoking a phone without changing
  frame-service credentials.
- Bound uploaded image size, queue storage, image retention, and vendor request
  timeouts. Disclose Nixplay albums shared by multiple frames.

## 1.1.2

- Fix Sync Now sometimes showing no progress or feedback at all. The status
  the console polls now flips to "running" the instant the sync worker
  claims the job, instead of after its first database write, so a poll
  right after clicking can no longer land in between and fall back to a
  slow refresh for the rest of the run.
- Fix the dashboard not refreshing after clicking Sync Now when there was
  nothing new to sync. The Wall, Frames, and run history now update
  reliably even when a sync completes very quickly.

## 1.1.1

- Restore the browser CSRF cookie whenever an authenticated console session is
  loaded. Reloading now repairs a stale sign-in token after an update instead
  of rejecting actions with an expired-request message.

## 1.1.0

- Add Immich as a photo source alongside PhotoPrism. Configure its URL and API
  key in the console, then use either source or both at once.
- Support Immich 3.1 and newer; refuse unsupported older servers before a sync
  starts.
- Apply the shared Quality rule to Immich's optional star rating. Enable it in
  Immich under **User Settings → Features → Rating**; `0` disables the rating
  filter and `1` through `5` select that rating and above.
- Resize one downloaded Immich original for every frame size that needs it,
  reducing repeat downloads during a sync.

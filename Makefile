# Makefile

## Use the Comments to generate rthe help as per smart Makefile usage.

.DEFAULT_GOAL := help

LOCAL_EXAMPLE_PATH:=$(PWD)/examples

OFFICAL_GAME=gamepad
OFFICAL_EXAMPLE_PATH:=$(PWD)/ebiten/examples/

# Recording variables
RECORDING_DIR:=$(PWD)/recordings
TAPE_FILE:=demo.tape
VIDEO_TITLE:=Ebiten Demo
VIDEO_DESC:=Ebiten game recording

# Google Cloud / YouTube variables
GCLOUD_PROJECT_ID:=ebiten-test
FILE?=demo.avi

.PHONY: help
help:
	@echo "Ebiten Test Makefile"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "; section = ""} \
		/^##@/ { section = substr($$0, 5); printf "\n\033[1m%s\033[0m\n", section; next } \
		/^[a-zA-Z_-]+:.*?## / { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } \
		/^##[^@]/ && NR > 1 && section == "" { printf "\n\033[1m%s\033[0m\n", substr($$0, 4) }' Makefile

##@ Utilities

.PHONY: print
print: ## Print Makefile variables
	@echo "Makefile Variables:"
	@echo "  LOCAL_EXAMPLE_PATH   = $(LOCAL_EXAMPLE_PATH)"
	@echo "  OFFICAL_GAME         = $(OFFICAL_GAME)"
	@echo "  OFFICAL_EXAMPLE_PATH = $(OFFICAL_EXAMPLE_PATH)"
	@echo "  RECORDING_DIR        = $(RECORDING_DIR)"
	@echo "  TAPE_FILE            = $(TAPE_FILE)"
	@echo "  VIDEO_TITLE          = $(VIDEO_TITLE)"
	@echo "  VIDEO_DESC           = $(VIDEO_DESC)"
	@echo "  GCLOUD_PROJECT_ID    = $(GCLOUD_PROJECT_ID)"
	@echo "  FILE                 = $(FILE)"
	@echo ""
	@echo "Recording Script:"
	@echo "  scripts/record-example.sh - Auto-patch and record any example"

##@ Local Examples

.PHONY: local-run
local-run: ## Run local basic example
	cd $(LOCAL_EXAMPLE_PATH)/basic && go run .

.PHONY: recording-run
recording-run: ## Run recording example (Press R to record)
	cd $(LOCAL_EXAMPLE_PATH)/recording && go run .

.PHONY: recording-demo
recording-demo: ## Auto-record 10 seconds of gameplay to AVI
	@mkdir -p $(RECORDING_DIR)
	@echo "Starting auto-recording demo (10 seconds)..."
	cd $(LOCAL_EXAMPLE_PATH)/recording && AUTO_RECORD=1 RECORD_DURATION=10s RECORD_OUTPUT=../../recordings/demo.avi go run .
	@echo "Recording saved to recordings/demo.avi"
	@ls -lh recordings/demo.avi

##@ Official Ebiten Examples

.PHONY: offical-clone
offical-clone: ## Clone official ebiten repository
	@if [ ! -d "ebiten" ]; then \
		git clone https://github.com/joeblew99/ebiten.git; \
	fi

.PHONY: offical-clone-update
offical-clone-update: ## Update official ebiten repository
	@if [ -d "ebiten/.git" ]; then \
		git -C ebiten pull --ff-only; \
	else \
		echo "ERROR: ebiten repo missing. Run 'make offical-clone' first."; \
		exit 1; \
	fi

.PHONY: offical-run
offical-run: offical-clone ## Run official example (usage: make offical-run OFFICAL_GAME=flappy)
	cd ebiten/examples/$(OFFICAL_GAME) && go run .

.PHONY: offical-list
offical-list: offical-clone ## List all available official examples
	@echo "Available games in ebiten/examples/:"
	@ls -1 ebiten/examples/ | grep -v '^\.' | sort

.PHONY: record-offical
record-offical: offical-clone ## Record official example (usage: make record-offical GAME=flappy DURATION=10s)
	@if [ -z "$(GAME)" ]; then \
		echo "ERROR: GAME parameter required"; \
		echo "Usage: make record-offical GAME=flappy DURATION=10s"; \
		exit 1; \
	fi
	@DURATION=$${DURATION:-10s}; \
	./scripts/record-example.sh $(GAME) $$DURATION

.PHONY: record-flappy
record-flappy: offical-clone ## Quick: Record flappy bird for 10 seconds
	./scripts/record-example.sh flappy 10s

.PHONY: record-blocks
record-blocks: offical-clone ## Quick: Record blocks game for 10 seconds
	./scripts/record-example.sh blocks 10s

.PHONY: record-2048
record-2048: offical-clone ## Quick: Record 2048 game for 10 seconds
	./scripts/record-example.sh 2048 10s

.PHONY: record-all-games
record-all-games: offical-clone ## Record all 86 official examples (10s each, sequential, resume-able)
	@mkdir -p $(RECORDING_DIR)
	@echo "==> Starting batch recording of all examples..."
	@total=$$(ls ebiten/examples/ | grep -v '^\.' | wc -l | tr -d ' '); \
	count=0; \
	for game in $$(ls ebiten/examples/ | grep -v '^\.' | sort); do \
		count=$$((count + 1)); \
		if [ -f "$(RECORDING_DIR)/$$game.avi" ]; then \
			echo "[$$count/$$total] SKIP: $$game (already exists)"; \
		else \
			echo "[$$count/$$total] Recording: $$game..."; \
			./scripts/record-example.sh $$game 10s || echo "  ⚠️  FAILED: $$game"; \
		fi \
	done; \
	echo ""; \
	echo "==> Batch recording complete!"; \
	successful=$$(ls -1 $(RECORDING_DIR)/*.avi 2>/dev/null | wc -l | tr -d ' '); \
	echo "    Successful: $$successful recordings"; \
	echo "    Total games: $$total"

##@ Recording & Upload Tools

.PHONY: install-vhs
install-vhs: ## Install VHS terminal recorder
	@echo "Installing VHS..."
	go install github.com/charmbracelet/vhs@latest
	@echo "VHS installed successfully!"

.PHONY: install-recording-deps
install-recording-deps: ## Install VHS dependencies (ffmpeg, ttyd)
	@echo "Installing VHS dependencies..."
	# brew install ffmpeg ttyd
	@echo "NOTE: brew install commented out. Install manually: brew install ffmpeg ttyd"
	@echo "Dependencies installation skipped!"

.PHONY: install-youtube-uploader
install-youtube-uploader: ## Install YouTube uploader tool
	@echo "Installing YouTube uploader..."
	go install github.com/porjo/youtubeuploader/cmd/youtubeuploader@latest
	@echo "YouTube uploader installed successfully!"
	@echo "Setup: Place client_secrets.json in project root for OAuth"

.PHONY: install-all-tools
install-all-tools: install-vhs install-recording-deps install-youtube-uploader ## Install all recording and upload tools

.PHONY: check-tools
check-tools: ## Check if recording and upload tools are installed
	@echo "Checking installed tools..."
	@which vhs >/dev/null 2>&1 && echo "✓ VHS installed" || echo "✗ VHS not installed (run: make install-vhs)"
	@which youtubeuploader >/dev/null 2>&1 && echo "✓ YouTube uploader installed" || echo "✗ YouTube uploader not installed (run: make install-youtube-uploader)"
	@which ffmpeg >/dev/null 2>&1 && echo "✓ ffmpeg installed" || echo "✗ ffmpeg not installed (optional for VHS)"
	@which ttyd >/dev/null 2>&1 && echo "✓ ttyd installed" || echo "✗ ttyd not installed (optional for VHS)"
	@[ -f "client_secrets.json" ] && echo "✓ client_secrets.json found" || echo "✗ client_secrets.json missing (required for YouTube upload)"

.PHONY: youtube-setup-help
youtube-setup-help: ## Show YouTube OAuth setup instructions with direct links
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║                                                                  ║"
	@echo "║  YouTube OAuth Setup - Project: $(GCLOUD_PROJECT_ID)"
	@echo "║                                                                  ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Step 1: Enable YouTube Data API v3"
	@echo "  → https://console.cloud.google.com/apis/library/youtube.googleapis.com?project=$(GCLOUD_PROJECT_ID)"
	@echo "  Click 'Enable' button"
	@echo "  After enabling, you'll see: https://console.cloud.google.com/apis/api/youtube.googleapis.com/metrics?project=$(GCLOUD_PROJECT_ID)"
	@echo ""
	@echo "Step 2: Configure OAuth Consent Screen"
	@echo "  → https://console.cloud.google.com/auth/overview/create?project=$(GCLOUD_PROJECT_ID)"
	@echo "  1. App Information:"
	@echo "     - App name: YouTube Uploader"
	@echo "     - User support email: (select your email from dropdown)"
	@echo "     - Developer contact: (enter your email)"
	@echo "     - Click 'Save and Continue'"
	@echo "  2. Scopes - Just click 'Save and Continue' (no changes needed)"
	@echo "  3. Test users:"
	@echo "     - Click '+ Add Users'"
	@echo "     - Enter your Gmail address"
	@echo "     - Click 'Add'"
	@echo "     - Click 'Save and Continue'"
	@echo "  4. Summary - Click 'Back to Dashboard'"
	@echo ""
	@echo "Step 3: Create OAuth 2.0 Client ID"
	@echo "  → https://console.cloud.google.com/auth/clients/create?project=$(GCLOUD_PROJECT_ID)"
	@echo "  1. Application type: Select 'Web application'"
	@echo "  2. Name: YouTube Uploader CLI"
	@echo "  3. Authorized redirect URIs:"
	@echo "     - Click '+ Add URI'"
	@echo "     - Enter: http://localhost:8080/oauth2callback"
	@echo "  4. Click 'Create'"
	@echo "  5. ⚠️  IMPORTANT: Download JSON file NOW (starting June 2025,"
	@echo "     you cannot view/download the secret after closing the dialog)"
	@echo "  6. Click 'Download JSON' or download icon"
	@echo "  7. Save as 'client_secrets.json' in: $(PWD)"
	@echo ""
	@echo "Step 4: Verify Setup"
	@echo "  $$ make youtube-check-oauth"
	@echo ""
	@echo "⚠️  CRITICAL: YouTube API Quota Limits"
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "  Daily Quota:     10,000 units"
	@echo "  Upload Cost:     1,600 units per video"
	@echo "  Max Uploads/Day: 6 videos"
	@echo ""
	@echo "  For 80+ videos, you'll hit the quota limit quickly!"
	@echo ""
	@echo "  Options:"
	@echo "    1. Manual browser upload (no quota) - make upload-all-browser"
	@echo "    2. Request quota increase (3-5 days) - see YOUTUBE_API_QUOTA.md"
	@echo "    3. Daily uploads (14 days for 80 videos)"
	@echo ""
	@echo "  📖 Read YOUTUBE_API_QUOTA.md for full details"
	@echo "════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Step 5: Test Upload"
	@echo "  $$ make recording-demo    # Create test recording"
	@echo "  $$ make upload-youtube    # Upload to YouTube"
	@echo ""
	@echo "💡 Tip: Run 'make youtube-setup' for interactive guided setup"
	@echo ""
	@echo "Note: You can change project ID with: make GCLOUD_PROJECT_ID=your-project ..."

.PHONY: youtube-create-secrets
youtube-create-secrets: ## Manually create client_secrets.json (if download fails)
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║  Create client_secrets.json manually                            ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "⚠️  WARNING: Starting June 2025, Google will hide the client secret"
	@echo "after you close the creation dialog. If you closed it without"
	@echo "downloading, you'll need to DELETE the old client and create a new one."
	@echo ""
	@echo "If the 'Download JSON' button didn't work, use this helper."
	@echo ""
	@echo "Step 1: Open the credentials page:"
	@open "https://console.cloud.google.com/apis/credentials?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  xdg-open "https://console.cloud.google.com/apis/credentials?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  start "https://console.cloud.google.com/apis/credentials?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  echo "→ https://console.cloud.google.com/apis/credentials?project=$(GCLOUD_PROJECT_ID)"
	@echo ""
	@echo "Step 2: Click on 'YouTube Uploader CLI' to view details"
	@echo "Step 3: Copy the Client ID and Client Secret values"
	@echo ""
	@read -p "Press Enter when ready to paste values..."
	@echo ""
	@read -p "Paste Client ID: " client_id; \
	read -p "Paste Client Secret: " client_secret; \
	if [ -z "$$client_id" ] || [ -z "$$client_secret" ]; then \
		echo ""; \
		echo "✗ Error: Both Client ID and Client Secret are required"; \
		exit 1; \
	fi; \
	echo "{" > client_secrets.json; \
	echo "  \"web\": {" >> client_secrets.json; \
	echo "    \"client_id\": \"$$client_id\"," >> client_secrets.json; \
	echo "    \"project_id\": \"$(GCLOUD_PROJECT_ID)\"," >> client_secrets.json; \
	echo "    \"auth_uri\": \"https://accounts.google.com/o/oauth2/auth\"," >> client_secrets.json; \
	echo "    \"token_uri\": \"https://oauth2.googleapis.com/token\"," >> client_secrets.json; \
	echo "    \"auth_provider_x509_cert_url\": \"https://www.googleapis.com/oauth2/v1/certs\"," >> client_secrets.json; \
	echo "    \"client_secret\": \"$$client_secret\"," >> client_secrets.json; \
	echo "    \"redirect_uris\": [" >> client_secrets.json; \
	echo "      \"http://localhost:8080/oauth2callback\"" >> client_secrets.json; \
	echo "    ]" >> client_secrets.json; \
	echo "  }" >> client_secrets.json; \
	echo "}" >> client_secrets.json; \
	echo ""; \
	echo "✓ Created client_secrets.json"; \
	echo ""; \
	$(MAKE) youtube-check-oauth

.PHONY: youtube-check-oauth
youtube-check-oauth: ## Validate OAuth setup and test YouTube connection
	@echo "Checking YouTube OAuth setup..."
	@echo ""
	@echo "1. Checking client_secrets.json..."
	@if [ ! -f "client_secrets.json" ]; then \
		echo "  ✗ client_secrets.json not found"; \
		echo "  Run: make youtube-setup-help"; \
		exit 1; \
	else \
		echo "  ✓ client_secrets.json exists"; \
	fi
	@echo ""
	@echo "2. Validating JSON format..."
	@if ! python3 -m json.tool client_secrets.json > /dev/null 2>&1; then \
		echo "  ✗ Invalid JSON format"; \
		exit 1; \
	else \
		echo "  ✓ Valid JSON"; \
	fi
	@echo ""
	@echo "3. Checking required fields..."
	@if ! grep -q '"client_id"' client_secrets.json; then \
		echo "  ✗ Missing client_id"; \
		exit 1; \
	else \
		echo "  ✓ client_id present"; \
	fi
	@if ! grep -q '"client_secret"' client_secrets.json; then \
		echo "  ✗ Missing client_secret"; \
		exit 1; \
	else \
		echo "  ✓ client_secret present"; \
	fi
	@if ! grep -q '"redirect_uris"' client_secrets.json; then \
		echo "  ✗ Missing redirect_uris"; \
		exit 1; \
	else \
		echo "  ✓ redirect_uris present"; \
	fi
	@echo ""
	@echo "4. Checking redirect URI..."
	@if ! grep -q 'localhost:8080' client_secrets.json; then \
		echo "  ⚠️  Warning: redirect URI should include localhost:8080"; \
	else \
		echo "  ✓ Correct redirect URI (localhost:8080)"; \
	fi
	@echo ""
	@echo "5. Checking youtubeuploader tool..."
	@if ! which youtubeuploader >/dev/null 2>&1; then \
		echo "  ✗ youtubeuploader not installed"; \
		echo "  Run: make install-youtube-uploader"; \
		exit 1; \
	else \
		echo "  ✓ youtubeuploader installed at $$(which youtubeuploader)"; \
	fi
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║  ✓ OAuth setup is valid!                                        ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Create a test recording:  make recording-demo"
	@echo "  2. Upload to YouTube:        make upload-youtube"
	@echo ""
	@echo "Note: First upload will open browser for authorization"

.PHONY: youtube-setup
youtube-setup: ## Interactive YouTube OAuth setup (opens URLs, validates)
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║                                                                  ║"
	@echo "║  Interactive YouTube OAuth Setup                                ║"
	@echo "║  Project: $(GCLOUD_PROJECT_ID)"
	@echo "║                                                                  ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "This wizard will guide you through 3 steps:"
	@echo "  1. Enable YouTube Data API v3"
	@echo "  2. Configure OAuth Consent Screen"
	@echo "  3. Create OAuth 2.0 Client ID"
	@echo ""
	@read -p "Press Enter to start..."
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "Step 1 of 3: Enable YouTube Data API v3"
	@echo "════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Opening: YouTube Data API v3 Library..."
	@echo "→ https://console.cloud.google.com/apis/library/youtube.googleapis.com?project=$(GCLOUD_PROJECT_ID)"
	@echo ""
	@(open "https://console.cloud.google.com/apis/library/youtube.googleapis.com?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  xdg-open "https://console.cloud.google.com/apis/library/youtube.googleapis.com?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  start "https://console.cloud.google.com/apis/library/youtube.googleapis.com?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  echo "Please manually open the URL above")
	@echo ""
	@echo "Actions:"
	@echo "  1. Click the 'Enable' button"
	@echo "  2. Wait for API to be enabled (takes a few seconds)"
	@echo ""
	@read -p "Press Enter when done..."
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "Step 2 of 3: Configure OAuth Consent Screen"
	@echo "════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Opening: OAuth Consent Screen..."
	@echo "→ https://console.cloud.google.com/auth/overview/create?project=$(GCLOUD_PROJECT_ID)"
	@echo ""
	@(open "https://console.cloud.google.com/auth/overview/create?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  xdg-open "https://console.cloud.google.com/auth/overview/create?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  start "https://console.cloud.google.com/auth/overview/create?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  echo "Please manually open the URL above")
	@echo ""
	@echo "Actions:"
	@echo "  1. App Information:"
	@echo "     - App name: YouTube Uploader"
	@echo "     - User support email: (select from dropdown)"
	@echo "     - Developer contact: (your email)"
	@echo "     - Click 'Save and Continue'"
	@echo "  2. Scopes - Just click 'Save and Continue' (no changes needed)"
	@echo "  3. Test users:"
	@echo "     - Click '+ Add Users'"
	@echo "     - Enter your Gmail address"
	@echo "     - Click 'Add'"
	@echo "     - Click 'Save and Continue'"
	@echo "  4. Summary - Click 'Back to Dashboard'"
	@echo ""
	@read -p "Press Enter when done..."
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "Step 3 of 3: Create OAuth 2.0 Client ID"
	@echo "════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Opening: Create OAuth Client ID..."
	@echo "→ https://console.cloud.google.com/auth/clients/create?project=$(GCLOUD_PROJECT_ID)"
	@echo ""
	@(open "https://console.cloud.google.com/auth/clients/create?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  xdg-open "https://console.cloud.google.com/auth/clients/create?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  start "https://console.cloud.google.com/auth/clients/create?project=$(GCLOUD_PROJECT_ID)" 2>/dev/null || \
	  echo "Please manually open the URL above")
	@echo ""
	@echo "Actions:"
	@echo "  1. Application type: Select 'Web application'"
	@echo "  2. Name: YouTube Uploader CLI"
	@echo "  3. Authorized redirect URIs:"
	@echo "     - Click '+ Add URI'"
	@echo "     - Enter: http://localhost:8080/oauth2callback"
	@echo "  4. Click 'Create'"
	@echo "  5. ⚠️  IMPORTANT: Download JSON file NOW!"
	@echo "     Starting June 2025, you cannot view/download the secret"
	@echo "     after closing the dialog. Download it immediately!"
	@echo "  6. Click 'Download JSON' button in the popup"
	@echo "  7. Save the file as: client_secrets.json"
	@echo "  8. Move it to: $(PWD)"
	@echo ""
	@read -p "Press Enter when you've saved client_secrets.json..."
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "Step 4 of 4: ⚠️  YouTube API Quota Limits"
	@echo "════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "IMPORTANT: YouTube Data API has strict quota limits:"
	@echo ""
	@echo "  Daily Quota:     10,000 units"
	@echo "  Upload Cost:     1,600 units per video"
	@echo "  Max Uploads/Day: 6 videos"
	@echo ""
	@echo "For 80+ recordings, you'll hit the limit quickly!"
	@echo ""
	@echo "Your options:"
	@echo "  1. Manual browser upload (fastest, no quota)"
	@echo "     → make upload-all-browser"
	@echo ""
	@echo "  2. Request quota increase (best for automation)"
	@echo "     → Requires phone + ID/passport verification"
	@echo "     → 3-5 day approval time"
	@echo "     → See YOUTUBE_API_QUOTA.md for details"
	@echo ""
	@echo "  3. Daily API uploads (slowest, 14 days for 80 videos)"
	@echo "     → Upload 6 videos/day automatically"
	@echo ""
	@echo "📖 Read YOUTUBE_API_QUOTA.md for complete guide"
	@echo ""
	@read -p "Press Enter to validate setup..."
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "Validating Setup..."
	@echo "════════════════════════════════════════════════════════════════════"
	@echo ""
	@if [ -f "client_secrets.json" ]; then \
		echo "✓ client_secrets.json found"; \
		$(MAKE) youtube-check-oauth; \
	else \
		echo "✗ client_secrets.json not found in $(PWD)"; \
		echo ""; \
		echo "Please move the downloaded file to: $(PWD)/client_secrets.json"; \
		echo "Then run: make youtube-check-oauth"; \
		exit 1; \
	fi

.PHONY: gcloud-project-info
gcloud-project-info: ## Show Google Cloud project information
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║  Google Cloud Project Information                               ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Project ID: $(GCLOUD_PROJECT_ID)"
	@echo ""
	@if ! which gcloud >/dev/null 2>&1; then \
		echo "✗ gcloud CLI not installed"; \
		echo "  Run: brew install google-cloud-sdk"; \
		exit 1; \
	fi
	@echo "Fetching project details..."
	@echo ""
	@gcloud projects describe $(GCLOUD_PROJECT_ID) 2>/dev/null || \
		(echo "✗ Project not found or not accessible" && \
		 echo "  You may need to authenticate: gcloud auth login" && \
		 exit 1)
	@echo ""
	@echo "Quick Links:"
	@echo "  Console:     https://console.cloud.google.com/welcome?project=$(GCLOUD_PROJECT_ID)"
	@echo "  YouTube API: https://console.cloud.google.com/apis/api/youtube.googleapis.com/metrics?project=$(GCLOUD_PROJECT_ID)"
	@echo "  OAuth Setup: https://console.cloud.google.com/apis/credentials/consent?project=$(GCLOUD_PROJECT_ID)"

.PHONY: gcloud-delete-project
gcloud-delete-project: ## Delete Google Cloud project (WARNING: PERMANENT!)
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║  ⚠️  WARNING: DELETE GOOGLE CLOUD PROJECT                       ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Project ID: $(GCLOUD_PROJECT_ID)"
	@echo ""
	@echo "⚠️  This will PERMANENTLY delete:"
	@echo "  - All APIs and services"
	@echo "  - All OAuth credentials"
	@echo "  - All project data"
	@echo "  - The entire project $(GCLOUD_PROJECT_ID)"
	@echo ""
	@echo "This action CANNOT be undone!"
	@echo ""
	@read -p "Type the project ID '$(GCLOUD_PROJECT_ID)' to confirm deletion: " confirm; \
	if [ "$$confirm" != "$(GCLOUD_PROJECT_ID)" ]; then \
		echo ""; \
		echo "Deletion cancelled (project ID did not match)"; \
		exit 1; \
	fi
	@echo ""
	@echo "Checking if gcloud CLI is installed..."
	@if ! which gcloud >/dev/null 2>&1; then \
		echo "✗ gcloud CLI not installed"; \
		echo ""; \
		echo "Install with:"; \
		echo "  macOS:   brew install google-cloud-sdk"; \
		echo "  Linux:   curl https://sdk.cloud.google.com | bash"; \
		echo "  Windows: https://cloud.google.com/sdk/docs/install"; \
		exit 1; \
	fi
	@echo "✓ gcloud CLI found"
	@echo ""
	@echo "Deleting project $(GCLOUD_PROJECT_ID)..."
	@gcloud projects delete $(GCLOUD_PROJECT_ID) --quiet && \
		echo "" && \
		echo "╔══════════════════════════════════════════════════════════════════╗" && \
		echo "║  ✓ Project $(GCLOUD_PROJECT_ID) deleted successfully            ║" && \
		echo "╚══════════════════════════════════════════════════════════════════╝" && \
		echo "" && \
		echo "The project will be scheduled for deletion." && \
		echo "Actual deletion happens after ~30 days (recovery window)." && \
		echo "" && \
		echo "To restore within 30 days:" && \
		echo "  gcloud projects undelete $(GCLOUD_PROJECT_ID)" || \
	(echo "" && \
	 echo "✗ Failed to delete project" && \
	 echo "You may need to authenticate first: gcloud auth login" && \
	 exit 1)

##@ Recording & Upload

.PHONY: create-demo-tape
create-demo-tape: ## Create example VHS tape file
	@mkdir -p $(RECORDING_DIR)
	@echo "Creating demo tape file at $(RECORDING_DIR)/$(TAPE_FILE)..."
	@printf '%s\n' \
		'# VHS Tape File - Terminal Recording' \
		'Output demo.mp4' \
		'Output demo.gif' \
		'Set Shell "bash"' \
		'Set FontSize 28' \
		'Set Width 1200' \
		'Set Height 600' \
		'Set Theme "Dracula"' \
		'Type "echo '\''Starting Ebiten demo...'\''\"' \
		'Sleep 500ms' \
		'Enter' \
		'Sleep 2s' \
		'Type "make offical-list"' \
		'Sleep 500ms' \
		'Enter' \
		'Sleep 3s' \
		'Type "echo '\''Demo complete!'\''\"' \
		'Sleep 500ms' \
		'Enter' \
		'Sleep 2s' \
		> $(RECORDING_DIR)/$(TAPE_FILE)
	@echo "Demo tape created! Edit $(RECORDING_DIR)/$(TAPE_FILE) to customize."

.PHONY: record-vhs
record-vhs: ## Record terminal session with VHS (usage: make record-vhs TAPE_FILE=demo.tape)
	@if [ ! -f "$(RECORDING_DIR)/$(TAPE_FILE)" ]; then \
		echo "Tape file not found. Run 'make create-demo-tape' first."; \
		exit 1; \
	fi
	@echo "Recording with VHS..."
	cd $(RECORDING_DIR) && vhs $(TAPE_FILE)
	@echo "Recording complete! Check $(RECORDING_DIR)/"


.PHONY: upload-youtube
upload-youtube: ## Upload AVI recording to YouTube (usage: make upload-youtube FILE=flappy.avi)
	@if [ ! -f "$(RECORDING_DIR)/$(FILE)" ]; then \
		echo "ERROR: $(FILE) not found in $(RECORDING_DIR)/"; \
		echo "Available recordings:"; \
		ls -1 $(RECORDING_DIR)/*.avi 2>/dev/null | xargs -n1 basename || echo "  (no recordings found)"; \
		echo ""; \
		echo "Usage: make upload-youtube FILE=flappy.avi"; \
		exit 1; \
	fi
	@if [ ! -f "client_secrets.json" ]; then \
		echo "ERROR: client_secrets.json not found. Run 'make youtube-setup-help' for instructions."; \
		exit 1; \
	fi
	@BASENAME=$$(basename $(FILE) .avi); \
	TITLE="Ebiten Example: $$BASENAME"; \
	echo "Uploading $(FILE) to YouTube..."; \
	echo "Title: $$TITLE"; \
	youtubeuploader -filename "$(RECORDING_DIR)/$(FILE)" -title "$$TITLE" -description "$(VIDEO_DESC)" -secrets client_secrets.json
	@echo "Upload complete!"

.PHONY: upload-browser
upload-browser: ## Open YouTube Studio in browser (usage: make upload-browser FILE=flappy.avi)
	@if [ ! -f "$(RECORDING_DIR)/$(FILE)" ]; then \
		echo "ERROR: $(FILE) not found in $(RECORDING_DIR)/"; \
		echo "Available recordings:"; \
		ls -1 $(RECORDING_DIR)/*.avi 2>/dev/null | xargs -n1 basename || echo "  (no recordings found)"; \
		echo ""; \
		echo "Usage: make upload-browser FILE=flappy.avi"; \
		exit 1; \
	fi
	@echo "Opening YouTube upload page in browser..."
	@echo "Drag and drop this file to upload: $(RECORDING_DIR)/$(FILE)"
	@(open "https://www.youtube.com/upload" 2>/dev/null || \
	  xdg-open "https://www.youtube.com/upload" 2>/dev/null || \
	  start "https://www.youtube.com/upload" 2>/dev/null || \
	  echo "Please manually open: https://www.youtube.com/upload")
	@echo "File ready at: $(RECORDING_DIR)/$(FILE)"

.PHONY: upload-all-youtube
upload-all-youtube: ## Upload all recordings to YouTube using OAuth
	@if [ ! -f "client_secrets.json" ]; then \
		echo "ERROR: client_secrets.json not found. Run 'make youtube-setup-help' for instructions."; \
		exit 1; \
	fi
	@recordings=$$(ls -1 $(RECORDING_DIR)/*.avi 2>/dev/null); \
	if [ -z "$$recordings" ]; then \
		echo "ERROR: No recordings found in $(RECORDING_DIR)/"; \
		echo "Run 'make record-all-games' first."; \
		exit 1; \
	fi; \
	total=$$(echo "$$recordings" | wc -l | tr -d ' '); \
	quota_needed=$$((total * 1600)); \
	echo "╔══════════════════════════════════════════════════════════════════╗"; \
	echo "║  ⚠️  YouTube API Quota Warning                                  ║"; \
	echo "╚══════════════════════════════════════════════════════════════════╝"; \
	echo ""; \
	echo "  Found:           $$total recordings"; \
	echo "  Quota needed:    $$quota_needed units ($$total × 1,600)"; \
	echo "  Daily quota:     10,000 units"; \
	echo "  Max today:       6 videos"; \
	echo ""; \
	if [ $$total -gt 6 ]; then \
		echo "  ⚠️  WARNING: You can only upload 6 videos/day with default quota!"; \
		echo ""; \
		echo "  This upload will FAIL after video #6 with:"; \
		echo "    HTTP 403: quotaExceeded"; \
		echo ""; \
		echo "  Options:"; \
		echo "    1. Manual upload (no quota): make upload-all-browser"; \
		echo "    2. Request quota increase:    see YOUTUBE_API_QUOTA.md"; \
		echo "    3. Upload 6 today, rest tomorrow"; \
		echo ""; \
		read -p "  Continue anyway? [y/N] " confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo ""; \
			echo "Upload cancelled. Use 'make upload-all-browser' for quota-free upload."; \
			exit 1; \
		fi; \
	fi; \
	echo ""; \
	count=0; \
	echo "==> Uploading $$total recordings to YouTube..."; \
	for file in $$recordings; do \
		count=$$((count + 1)); \
		game=$$(basename "$$file" .avi); \
		echo "[$$count/$$total] Uploading: $$game"; \
		youtubeuploader -filename "$$file" \
			-title "Ebiten Example: $$game" \
			-description "Gameplay recording of the $$game example from Ebitengine (https://ebitengine.org)" \
			-secrets client_secrets.json || echo "  ⚠️  FAILED: $$game (quota exceeded?)"; \
	done; \
	echo ""; \
	echo "==> Batch upload complete!"

.PHONY: upload-all-browser
upload-all-browser: ## Open YouTube Studio for batch drag-and-drop upload
	@recordings=$$(ls -1 $(RECORDING_DIR)/*.avi 2>/dev/null); \
	if [ -z "$$recordings" ]; then \
		echo "ERROR: No recordings found in $(RECORDING_DIR)/"; \
		echo "Run 'make record-all-games' first."; \
		exit 1; \
	fi; \
	count=$$(echo "$$recordings" | wc -l | tr -d ' '); \
	echo "==> Opening YouTube upload page in browser..."; \
	echo "    Ready to upload: $$count recordings"; \
	echo "    Location: $(RECORDING_DIR)/"; \
	echo ""; \
	echo "You can drag-and-drop multiple files at once!"; \
	(open "https://www.youtube.com/upload" 2>/dev/null || \
	  xdg-open "https://www.youtube.com/upload" 2>/dev/null || \
	  start "https://www.youtube.com/upload" 2>/dev/null || \
	  echo "Please manually open: https://www.youtube.com/upload")

.PHONY: clean-recordings
clean-recordings: ## Delete all recordings
	@echo "Cleaning recordings..."
	rm -rf $(RECORDING_DIR)/*.mp4 $(RECORDING_DIR)/*.gif $(RECORDING_DIR)/*.webm $(RECORDING_DIR)/*.webp $(RECORDING_DIR)/*.avi
	@echo "Recordings cleaned!"



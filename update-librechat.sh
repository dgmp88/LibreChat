#!/bin/bash

# LibreChat Update Script
# Automates syncing fork's main branch with upstream and merging main into my-edits

# Ensure we're running with bash (not sh)
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# Note: We don't use 'set -e' because we want to handle errors explicitly
# with if statements to provide better error messages

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  $1"
}

# Step 1: Safety checks
print_info "Performing safety checks..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a git repository. Please run this script from the LibreChat directory."
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    print_error "You have uncommitted changes. Please commit or stash them before running this script."
    exit 1
fi

# Check if we're in a detached HEAD state
if ! git symbolic-ref -q HEAD > /dev/null; then
    print_error "You are in a detached HEAD state. Please checkout a branch first."
    exit 1
fi

print_success "Safety checks passed"

# Step 2: Setup upstream remote
print_info "Checking upstream remote..."

UPSTREAM_URL="git@github.com:danny-avila/LibreChat.git"

if git remote | grep -q "^upstream$"; then
    CURRENT_UPSTREAM=$(git remote get-url upstream)
    if [ "$CURRENT_UPSTREAM" != "$UPSTREAM_URL" ]; then
        print_warning "Upstream remote exists but points to different URL: $CURRENT_UPSTREAM"
        print_info "Updating upstream remote to: $UPSTREAM_URL"
        git remote set-url upstream "$UPSTREAM_URL"
        print_success "Upstream remote updated"
    else
        print_success "Upstream remote already configured"
    fi
else
    print_info "Adding upstream remote: $UPSTREAM_URL"
    git remote add upstream "$UPSTREAM_URL"
    print_success "Upstream remote added"
fi

# Step 3: Sync main branch
print_info "Syncing main branch with upstream..."

# Fetch from upstream
print_info "Fetching from upstream..."
if ! git fetch upstream; then
    print_error "Failed to fetch from upstream. Check your network connection and SSH keys."
    exit 1
fi
print_success "Fetched from upstream"

# Get current branch to return to it later if needed
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
print_info "Current branch: $CURRENT_BRANCH"

# Checkout main branch
print_info "Checking out main branch..."
if ! git checkout main; then
    print_error "Failed to checkout main branch. Does it exist?"
    exit 1
fi
print_success "Checked out main branch"

# Merge upstream/main into local main
print_info "Merging upstream/main into local main..."
if ! git merge upstream/main --no-edit; then
    print_error "Merge failed. Please resolve conflicts manually."
    print_info "After resolving conflicts, run: git commit"
    exit 1
fi
print_success "Merged upstream/main into local main"

# Push main to origin (fork)
print_info "Pushing main to origin (your fork)..."
if ! git push origin main; then
    print_error "Failed to push main to origin. Check your permissions and network connection."
    exit 1
fi
print_success "Pushed main to origin"

# Step 4: Update my-edits branch
print_info "Updating my-edits branch..."

# Checkout my-edits branch
print_info "Checking out my-edits branch..."
if ! git checkout my-edits; then
    print_error "Failed to checkout my-edits branch. Does it exist?"
    exit 1
fi
print_success "Checked out my-edits branch"

# Merge main into my-edits
print_info "Merging main into my-edits..."
if ! git merge main --no-edit; then
    print_error "Merge conflicts detected!"
    print_warning "Please resolve conflicts manually:"
    print_info "1. Review conflicted files: git status"
    print_info "2. Resolve conflicts in the files"
    print_info "3. Stage resolved files: git add <file>"
    print_info "4. Complete the merge: git commit"
    print_info "5. Push when ready: git push origin my-edits"
    exit 1
fi
print_success "Merged main into my-edits"

# Ask if user wants to push
echo ""
print_info "Merge completed successfully!"
read -p "Do you want to push my-edits to origin? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Pushing my-edits to origin..."
    if ! git push origin my-edits; then
        print_error "Failed to push my-edits to origin. Check your permissions and network connection."
        exit 1
    fi
    print_success "Pushed my-edits to origin"
else
    print_info "Skipping push. You can push later with: git push origin my-edits"
fi

# Ask if user wants to rebuild
echo ""
print_info "Code updated successfully!"
print_warning "Note: You may need to rebuild the client to see the updated version in the UI."
read -p "Do you want to rebuild now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Detect if using Docker
    if [ -f "deploy-compose.yml" ] || [ -f "docker-compose.yml" ]; then
        print_info "Detected Docker setup. Running: npm run update:docker"
        if ! npm run update:docker; then
            print_error "Rebuild failed. You may need to rebuild manually."
            print_info "For Docker: npm run update:docker"
            print_info "For local: npm run frontend"
        else
            print_success "Rebuild completed successfully!"
        fi
    else
        print_info "Running: npm run frontend"
        if ! npm run frontend; then
            print_error "Rebuild failed. You may need to rebuild manually with: npm run frontend"
        else
            print_success "Rebuild completed successfully!"
        fi
    fi
else
    print_info "Skipping rebuild."
    print_info "To rebuild later:"
    print_info "  - Docker: npm run update:docker"
    print_info "  - Local: npm run frontend"
fi

print_success "Update completed successfully!"



# Load environment variables from .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

.PHONY: clone-kubespray clean list-remotes add-upstream list-origin-branches list-upstream-branches list-local-branches fetch-upstream fetch-origin checkout-branch update-master-from-upstream install-docker build-and-push-docker help

# Default target
all: clone-kubespray add-upstream list-remotes fetch-origin list-origin-branches fetch-upstream list-upstream-branches list-local-branches checkout-branch

# Clone kubespray repository if kubespray-fork folder doesn't exist
clone-kubespray:
	@echo "==================== \033[1mCLONE-KUBESPRAY\033[0m ===================="
	@if [ ! -d "kubespray-fork" ]; then \
		echo "Cloning kubespray repository..."; \
		git clone https://github.com/c-romeo/kubespray.git kubespray-fork; \
		echo "Repository cloned successfully to kubespray-fork/"; \
		cd kubespray-fork && git config pull.rebase true; \
	else \
		echo "kubespray-fork directory already exists, skipping clone."; \
	fi

# Clean up - remove the kubespray-fork directory
clean:
	@echo "==================== \033[1mCLEAN\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		echo "Removing kubespray-fork directory..."; \
		rm -rf kubespray-fork; \
		echo "kubespray-fork directory removed."; \
	else \
		echo "kubespray-fork directory does not exist."; \
	fi

# List git remotes for kubespray-fork repository
list-remotes:
	@echo "==================== \033[1mLIST-REMOTES\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		echo "Git remotes for kubespray-fork:"; \
		cd kubespray-fork && git remote -v; \
	else \
		echo "kubespray-fork directory does not exist. Run 'make clone-kubespray' first."; \
	fi

# Add upstream remote to kubespray-fork repository
add-upstream:
	@echo "==================== \033[1mADD-UPSTREAM\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		cd kubespray-fork && \
		if git remote | grep -q "^upstream$$"; then \
			echo "Upstream remote already exists."; \
		else \
			echo "Adding upstream remote..."; \
			git remote add upstream https://github.com/kubernetes-sigs/kubespray.git; \
			echo "Upstream remote added successfully."; \
		fi; \
	else \
		echo "kubespray-fork directory does not exist. Run 'make clone-kubespray' first."; \
	fi

# List origin branches for kubespray-fork repository
list-origin-branches:
	@echo "==================== \033[1mLIST-ORIGIN-BRANCHES\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		echo "\033[1;32mOrigin branches for kubespray-fork:\033[0m"; \
		cd kubespray-fork && git branch -r --list 'origin/*'; \
	else \
		echo "kubespray-fork directory does not exist. Run 'make clone-kubespray' first."; \
	fi

# List upstream branches for kubespray-fork repository
list-upstream-branches:
	@echo "==================== \033[1mLIST-UPSTREAM-BRANCHES\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		cd kubespray-fork && \
		if git remote | grep -q "^upstream$$"; then \
			echo "\033[1;32mUpstream branches for kubespray-fork:\033[0m"; \
			git branch -r --list 'upstream/*'; \
		else \
			echo "Upstream remote not found. Run 'make add-upstream' first."; \
		fi; \
	else \
		echo "kubespray-fork directory does not exist. Run 'make clone-kubespray' first."; \
	fi

# List local branches for kubespray-fork repository
list-local-branches:
	@echo "==================== \033[1mLIST-LOCAL-BRANCHES\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		echo "\033[1;32mLocal branches for kubespray-fork:\033[0m"; \
		cd kubespray-fork && git branch; \
	else \
		echo "kubespray-fork directory does not exist. Run 'make clone-kubespray' first."; \
	fi

# Fetch upstream branches for kubespray-fork repository
fetch-upstream:
	@echo "==================== \033[1mFETCH-UPSTREAM\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		cd kubespray-fork && \
		if git remote | grep -q "^upstream$$"; then \
			echo "\033[1;32mFetching upstream branches...\033[0m"; \
			git fetch upstream; \
			echo "Upstream branches fetched successfully."; \
		else \
			echo "Upstream remote not found. Run 'make add-upstream' first."; \
		fi; \
	else \
		echo "kubespray-fork directory does not exist. Run 'make clone-kubespray' first."; \
	fi

# Fetch origin branches for kubespray-fork repository
fetch-origin:
	@echo "==================== \033[1mFETCH-ORIGIN\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		echo "\033[1;32mFetching origin branches...\033[0m"; \
		cd kubespray-fork && git fetch origin; \
		echo "Origin branches fetched successfully."; \
	else \
		echo "kubespray-fork directory does not exist. Run 'make clone-kubespray' first."; \
	fi

# Checkout branch by name (use BRANCH variable or default to master)
checkout-branch:
	@echo "==================== \033[1mCHECKOUT-BRANCH\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		cd kubespray-fork && \
		BRANCH_NAME=$${BRANCH:-master}; \
		CURRENT_BRANCH=$$(git branch --show-current); \
		echo "Target branch: $$BRANCH_NAME"; \
		echo "Current branch: $$CURRENT_BRANCH"; \
		if [ "$$CURRENT_BRANCH" = "$$BRANCH_NAME" ]; then \
			echo "\033[1;33mAlready on branch $$BRANCH_NAME\033[0m"; \
			if git ls-remote --heads origin $$BRANCH_NAME | grep -q "$$BRANCH_NAME"; then \
				echo "\033[1;32mFetching and pulling latest changes from origin/$$BRANCH_NAME...\033[0m"; \
				git fetch origin $$BRANCH_NAME && git pull origin $$BRANCH_NAME; \
			else \
				echo "Branch $$BRANCH_NAME does not exist on origin."; \
			fi; \
		else \
			if git show-ref --verify --quiet refs/heads/$$BRANCH_NAME; then \
				echo "\033[1;32mSwitching to existing local branch $$BRANCH_NAME...\033[0m"; \
				git checkout $$BRANCH_NAME; \
			elif git ls-remote --heads origin $$BRANCH_NAME | grep -q "$$BRANCH_NAME"; then \
				echo "\033[1;32mCreating and checking out branch $$BRANCH_NAME from origin...\033[0m"; \
				git checkout -b $$BRANCH_NAME origin/$$BRANCH_NAME; \
			else \
				echo "\033[1;31mBranch $$BRANCH_NAME not found locally or on origin.\033[0m"; \
				exit 1; \
			fi; \
		fi; \
	else \
		echo "kubespray-fork directory does not exist. Run 'make clone-kubespray' first."; \
	fi

# Update local master from upstream/master and push to origin
update-master-from-upstream:
	@echo "==================== \033[1mUPDATE-MASTER-FROM-UPSTREAM\033[0m ===================="
	@if [ -d "kubespray-fork" ]; then \
		cd kubespray-fork && \
		# Ensure upstream remote exists \
		if git remote | grep -q "^upstream$$"; then \
			echo "Upstream remote already exists."; \
		else \
			echo "Adding upstream remote..."; \
			git remote add upstream https://github.com/kubernetes-sigs/kubespray.git; \
			echo "Upstream remote added."; \
		fi; \
		echo "\033[1;32mFetching upstream...\033[0m"; \
		git fetch upstream; \
		echo "\033[1;32mFetching origin...\033[0m"; \
		git fetch origin; \
		# Ensure local master exists \
		if git show-ref --verify --quiet refs/heads/master; then \
			echo "Local branch master exists."; \
		elif git ls-remote --heads origin master | grep -q master; then \
			echo "Creating local master from origin/master..."; \
			git checkout -b master origin/master; \
		elif git ls-remote --heads upstream master | grep -q master; then \
			echo "Creating local master from upstream/master..."; \
			git checkout -b master upstream/master; \
		else \
			echo "\033[1;31mNo master branch found in origin or upstream.\033[0m"; \
			exit 1; \
		fi; \
		echo "\033[1;32mChecking out master...\033[0m"; \
		git checkout master; \
		echo "\033[1;32mFast-forwarding master to upstream/master...\033[0m"; \
		if git merge --ff-only upstream/master; then \
			echo "Master fast-forwarded to upstream/master."; \
		else \
			echo "\033[1;33mFast-forward not possible; attempting rebase onto upstream/master...\033[0m"; \
			if git rebase upstream/master; then \
				echo "Rebase successful."; \
			else \
				echo "\033[1;31mRebase failed. Please resolve conflicts and continue the rebase manually.\033[0m"; \
				exit 1; \
			fi; \
		fi; \
		echo "\033[1;32mPushing updated master to origin...\033[0m"; \
		git push origin master; \
	else \
		echo "kubespray-fork directory does not exist. Run 'make clone-kubespray' first."; \
		exit 1; \
	fi

# Install Docker using the Debian Trixie installation script
install-docker:
	@echo "==================== \033[1mINSTALL-DOCKER\033[0m ===================="
	@if [ -f "scripts/install-docker-debian-trixie.sh" ]; then \
		echo "\033[1;32mRunning Docker installation script...\033[0m"; \
		if [ "$(USER_INTERACTIVE)" = "1" ]; then \
			echo "\033[1;33mInteractive mode enabled. Root password prompts will be visible.\033[0m"; \
		fi; \
		chmod +x scripts/install-docker-debian-trixie.sh; \
		USER_INTERACTIVE=$(USER_INTERACTIVE) ./scripts/install-docker-debian-trixie.sh; \
		echo "Docker installation script completed."; \
	else \
		echo "\033[1;31mError: scripts/install-docker-debian-trixie.sh not found.\033[0m"; \
		echo "Please ensure the script exists in the scripts/ directory."; \
		if [ "$(USER_INTERACTIVE)" != "1" ]; then \
			echo "Tip: If you need interactive root prompts, use: make install-docker USER_INTERACTIVE=1"; \
		fi; \
		exit 1; \
	fi

# Build and push Docker image using the build script
build-and-push-docker:
	@echo "==================== \033[1mBUILD-AND-PUSH-DOCKER\033[0m ===================="
	@if [ -f "scripts/build-and-push-docker.sh" ]; then \
		echo "\033[1;32mRunning Docker build and push script...\033[0m"; \
		chmod +x scripts/build-and-push-docker.sh; \
		./scripts/build-and-push-docker.sh; \
		echo "Docker build and push script completed."; \
	else \
		echo "\033[1;31mError: scripts/build-and-push-docker.sh not found.\033[0m"; \
		echo "Please ensure the script exists in the scripts/ directory."; \
		exit 1; \
	fi

# Help target
help:
	@echo "==================== \033[1mHELP\033[0m ===================="
	@echo "Available targets:"
	@echo "  clone-kubespray       - Clone the kubespray repository to kubespray-fork/ (default)"
	@echo "  clean                - Remove the kubespray-fork directory"
	@echo "  list-remotes         - List git remotes for the kubespray-fork repository"
	@echo "  add-upstream          - Add upstream remote (kubernetes-sigs/kubespray) to kubespray-fork"
	@echo "  list-origin-branches  - List all origin branches for the kubespray-fork repository"
	@echo "  list-upstream-branches - List all upstream branches for the kubespray-fork repository"
	@echo "  list-local-branches   - List all local branches for the kubespray-fork repository"
	@echo "  fetch-upstream        - Fetch latest changes from upstream remote"
	@echo "  fetch-origin          - Fetch latest changes from origin remote"
	@echo "  checkout-branch       - Checkout branch by name (use BRANCH=name or defaults to master)"
	@echo "  update-master-from-upstream - Update local master from upstream/master and push to origin"
	@echo "  install-docker        - Install Docker using scripts/install-docker-debian-trixie.sh"
	@echo "                          Use USER_INTERACTIVE=1 for interactive root prompts"
	@echo "  build-and-push-docker - Build and push Docker image using scripts/build-and-push-docker.sh"
	@echo "  help                  - Show this help message"
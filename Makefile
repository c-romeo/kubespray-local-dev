.PHONY: clone-kubespray clean help

# Default target
all: clone-kubespray

# Clone kubespray repository if kubespray-fork folder doesn't exist
clone-kubespray:
	@if [ ! -d "kubespray-fork" ]; then \
		echo "Cloning kubespray repository..."; \
		git clone https://github.com/c-romeo/kubespray.git kubespray-fork; \
		echo "Repository cloned successfully to kubespray-fork/"; \
	else \
		echo "kubespray-fork directory already exists, skipping clone."; \
	fi

# Clean up - remove the kubespray-fork directory
clean:
	@if [ -d "kubespray-fork" ]; then \
		echo "Removing kubespray-fork directory..."; \
		rm -rf kubespray-fork; \
		echo "kubespray-fork directory removed."; \
	else \
		echo "kubespray-fork directory does not exist."; \
	fi

# Help target
help:
	@echo "Available targets:"
	@echo "  clone-kubespray  - Clone the kubespray repository to kubespray-fork/ (default)"
	@echo "  clean           - Remove the kubespray-fork directory"
	@echo "  help            - Show this help message"
#!/bin/bash
# Install after other coding clients that should use this

set -euo pipefail

curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
codegraph install -y
codegraph telemetry off

#!/usr/bin/env bash

# ==============================================================================
# LOCAL CI SIMULATOR
# ==============================================================================
# This script spins up disposable Ubuntu Docker containers, mounts the current
# dotfiles repository into it, and runs the same test suite that GitHub Actions
# executes. This ensures changes can be validated locally without polluting the
# host environment.

# Auto-start Docker Desktop on macOS if it's not running
if ! docker info >/dev/null 2>&1; then
  echo "⚠️  Docker daemon is not responding."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🚀 Launching Docker Desktop in the background..."
    open -a Docker
    echo "⏳ Waiting for Docker engine to initialize (this may take a few seconds)..."
    attempts=0
    while ! docker info > /dev/null 2>&1; do
      sleep 2
      (( attempts++ ))
      if (( attempts > 30 )); then
        echo "❌ ERROR: Docker Desktop failed to start after 60 seconds. Aborting."
        exit 1
      fi
    done
    echo "✅ Docker engine is ready!"
  else
    echo "❌ ERROR: Docker daemon is not running. Please start it manually."
    exit 1
  fi
fi

DOCKER_FLAGS="-i"
[ -t 0 ] && DOCKER_FLAGS="-it"

for MODE in "linux-server" "linux-client"; do
  echo ""
  echo "======================================================================="
  echo "🚀 RUNNING CI SANDBOX FOR MODE: $MODE"
  echo "======================================================================="

  docker run --rm $DOCKER_FLAGS -v "$PWD:/root/.dotfiles" -w /root/.dotfiles ubuntu:latest bash -c "
    echo '📦 Installing necessary system dependencies...'
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq sudo zsh curl git vim tmux > /dev/null
    touch /usr/local/bin/gh && chmod +x /usr/local/bin/gh

    echo '----------------------------------------'
    echo '🧪 PASS 1: Initial Bootstrap'
    echo '----------------------------------------'
    zsh ./dot.sh --mode $MODE --test || exit 1

    echo '----------------------------------------'
    echo '🧪 PASS 2: Idempotency Check'
    echo '----------------------------------------'
    zsh ./dot.sh --mode $MODE --test || exit 1

    echo '----------------------------------------'
    echo '🧪 PASS 3: Zsh Runtime Validation'
    echo '----------------------------------------'
    zsh -c 'source ~/.zshrc' || exit 1

    echo '----------------------------------------'
    echo '🧪 PASS 4: Behavioral Test Suite'
    echo '----------------------------------------'
    ./tests/run-tests.sh || exit 1
  "

  # Catch failure
  if [ $? -ne 0 ]; then
    echo ""
    echo "❌ ERROR: CI validations FAILED for mode: $MODE"
    exit 1
  fi
done

echo ""
echo "✅ SUCCESS: All local CI validations passed perfectly for all modes!"

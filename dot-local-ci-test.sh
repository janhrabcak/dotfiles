#!/usr/bin/env bash

# ==============================================================================
# LOCAL CI SIMULATOR
# ==============================================================================
# This script spins up disposable Ubuntu Docker containers, mounts the current
# dotfiles repository into it, and runs the same test suite that GitHub Actions
# executes. This ensures changes can be validated locally without polluting the
# host environment.

for MODE in "linux-server" "linux-client"; do
  echo ""
  echo "======================================================================="
  echo "🚀 RUNNING CI SANDBOX FOR MODE: $MODE"
  echo "======================================================================="

  docker run --rm -it -v "$PWD:/root/.dotfiles" -w /root/.dotfiles ubuntu:latest bash -c "
    echo '📦 Installing necessary system dependencies...'
    apt-get update -qq && apt-get install -y -qq sudo zsh curl git vim tmux > /dev/null

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

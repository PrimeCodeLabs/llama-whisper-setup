set -eo pipefail

# Define colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

trap 'echo -e "${RED}An error occurred. Exiting...${NC}" >&2' ERR

usage() {
  echo -e "${YELLOW}Usage: $0 -n <name>${NC}"
  exit 1
}

while getopts ":n:" opt; do
  case $opt in
    n)
      name="$OPTARG"
      ;;
    \?)
      echo -e "${RED}Invalid option: -$OPTARG${NC}" >&2
      usage
      ;;
    :)
      echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2
      usage
      ;;
  esac
done

if [ -z "$name" ]; then
  usage
fi

# Determine the operating system
os="$(uname)"
case $os in
  "Linux")
    os="linux"
    ;;
  "Darwin")
    os="mac"
    ;;
  *)
    echo "Unsupported operating system: $os" >&2
    exit 1
    ;;
esac

echo "Detected operating system: $os"

# Check if git-lfs is installed; if not, install it using the package manager for the respective operating system
if ! command -v git-lfs &> /dev/null; then
  echo "git-lfs not found, installing..."

  case $os in
    "linux")
      sudo apt-get update
      sudo apt-get install git-lfs
      ;;
    "mac")
      brew install git-lfs
      ;;
  esac

  git lfs install
fi

# Check if Python 3.11 is installed; if not, install it using the package manager for the respective operating system
python_version=$(python3 --version 2>&1 | awk '{print $2}')
required_version="3.11"

if ! command -v python3 &> /dev/null || ! [[ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" == "$required_version" ]]; then
  echo "Python 3.11 not found, installing..."

  case $os in
    "linux")
      sudo apt-get update
      sudo apt-get install -y software-properties-common
      sudo add-apt-repository -y ppa:deadsnakes/ppa
      sudo apt-get update
      sudo apt-get install -y python3.11
      ;;
    "mac")
      brew install python@3.11
      echo 'export PATH="/usr/local/opt/python@3.11/bin:$PATH"' >> ~/.zshrc
      source ~/.zshrc
      ;;
  esac
fi


# Check if git-lfs is installed; if not, install it using Homebrew
if ! command -v git-lfs &> /dev/null; then
  echo "git-lfs not found, installing using Homebrew..."
  brew install git-lfs
  git lfs install
fi

# Step 1
if [ ! -d "llama.cpp" ]; then
  git clone https://github.com/ggerganov/llama.cpp
fi

pushd llama.cpp

# Step 2
make

repo_url="https://huggingface.co/decapoda-research/llama-7b-hf"
file_path="tokenizer.model"
output_file="tokenizer.model"
folder_name="llama-7b-hf"


if [ ! -d "$folder_name" ]; then
  export GIT_LFS_SKIP_SMUDGE=1
  # Clone the repository without downloading LFS files automatically
  git clone "$repo_url" "$folder_name"

  # Navigate to the cloned repository directory
  pushd "$folder_name"

  # Pull the specific LFS file
  git lfs pull --include "$file_path"

  # Navigate back to the original directory
  popd
fi
# echo current directory
pwd
cp "$folder_name/$file_path" models/

# Step 4
if [ ! -d "gpt4-x-alpaca" ]; then
  git clone https://huggingface.co/chavinlo/gpt4-x-alpaca
fi
cp gpt4-x-alpaca/added_tokens.json models/

# Step 5
mkdir -p models/gpt4all
if [ ! -f "models/gpt4all/gpt4all-lora-quantized.bin" ]; then
  curl -L -o models/gpt4all/gpt4all-lora-quantized.bin https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/gpt4all-lora-quantized.bin
fi

if [ ! -f "models/gpt4all/ggml-model-q4_0.bin" ]; then
  python3 -m venv venv
  ./venv/bin/python3 -m pip install -r requirements.txt && ./venv/bin/python3 -m pip install --upgrade pip
  ./venv/bin/python3 convert.py models/gpt4all/gpt4all-lora-quantized.bin
fi

popd

# Step 6
if [ ! -d "whisper" ]; then
  git clone https://github.com/ggerganov/whisper.cpp.git whisper
fi

pushd whisper
git checkout master

# Step 6.1
if [ ! -f "models/ggml-small.en.bin" ]; then
  bash ./models/download-ggml-model.sh base.en
fi

# Step 6.2
make

# Step 6.2 (continued)
if ! command -v make &> /dev/null; then
  echo "make not found. Please ensure it is installed and in your PATH." >&2
  exit 1
fi

make talk-llama

# Step 6.3
if ! command -v ./talk-llama &> /dev/null; then
  echo "talk-llama not found. Please ensure it is built successfully." >&2
  exit 1
fi

./talk-llama -mw ./models/ggml-base.en.bin -ml ../llama.cpp/models/gpt4all/ggml-model-q4_0.bin -p "${name}" -t 8

popd
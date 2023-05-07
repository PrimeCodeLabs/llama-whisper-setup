@echo off
setlocal enabledelayedexpansion

set RED=^<ESC^>[0;31m
set GREEN=^<ESC^>[0;32m
set YELLOW=^<ESC^>[0;33m
set NC=^<ESC^>[0m

if "%~1"=="" (
  echo %YELLOW%Usage: %0 -n ^<name^>%NC%
  exit /b 1
)

if not "%~2"=="" (
  set name=%~2
) else (
  echo %RED%Option -n requires an argument.%NC%
  exit /b 1
)

:: Check if git-lfs is installed
git-lfs.exe version >nul 2>&1
if %errorlevel% neq 0 (
  echo %YELLOW%git-lfs not found, please install and add to PATH.%NC%
  exit /b 1
)

:: Check if Python 3.11 is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
  echo %YELLOW%Python 3.11 not found, please install and add to PATH.%NC%
  exit /b 1
)

:: Check if Make is installed
make --version >nul 2>&1
if %errorlevel% neq 0 (
  echo %YELLOW%Make not found, please install and add to PATH.%NC%
  exit /b 1
)

:: Clone llama.cpp if not present
if not exist llama.cpp (
  git clone https://github.com/ggerganov/llama.cpp
)

:: Build llama.cpp
cd llama.cpp
make

:: Step 3: Get the tokenizer model
set repo_url=https://huggingface.co/decapoda-research/llama-7b-hf
set file_path=tokenizer.model
set output_file=tokenizer.model
set folder_name=llama-7b-hf

if not exist %folder_name% (
  set GIT_LFS_SKIP_SMUDGE=1
  git clone %repo_url% %folder_name%
  cd %folder_name%
  git lfs pull --include %file_path%
  cd ..
)

copy %folder_name%/%file_path% models/

:: Step 4
if not exist gpt4-x-alpaca (
  git clone https://huggingface.co/chavinlo/gpt4-x-alpaca
)
copy gpt4-x-alpaca/added_tokens.json models/

:: Step 5
mkdir models/gpt4all
if not exist models/gpt4all/gpt4all-lora-quantized.bin (
  curl -L -o models/gpt4all/gpt4all-lora-quantized.bin https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/gpt4all-lora-quantized.bin
)

if not exist models/gpt4all/ggml-model-q4_0.bin (
  python -m venv venv
  venv\Scripts\python -m pip install -r requirements.txt
  venv\Scripts\python
  venv\Scripts\python -m pip install --upgrade pip
  venv\Scripts\python convert.py models/gpt4all/gpt4all-lora-quantized.bin
)

cd ..

:: Step 6
if not exist whisper (
  git clone https://github.com/ggerganov/whisper.cpp.git whisper
)

cd whisper
git checkout master

:: Step 6.1
if not exist models\ggml-small.en.bin (
  call models\download-ggml-model.cmd base.en
)

:: Step 6.2
make

:: Step 6.2 (continued)
if not exist talk-llama.exe (
  echo %RED%talk-llama not found. Please ensure it is built successfully.%NC%
  exit /b 1
)

talk-llama.exe -mw models\ggml-base.en.bin -ml ..\llama.cpp\models\gpt4all\ggml-model-q4_0.bin -p "%name%" -t 8

cd ..

endlocal

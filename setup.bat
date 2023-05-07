@echo off

SETLOCAL ENABLEDELAYEDEXPANSION

set "name="

:loop
if "%~1"=="" goto :continue
if /I "%~1"=="-n" (
    set "name=%~2"
    shift
) else (
    echo Invalid option: %~1
    exit /B 1
)
shift
goto :loop

:continue
if not defined name (
    echo Usage: %~nx0 -n ^<name^>
    exit /B 1
)

if not exist models mkdir models

if not exist "models\added_tokens.json" (
    curl -H "Accept: application/json" https://huggingface.co/chavinlo/gpt4-x-alpaca/resolve/main/added_tokens.json -o models\added_tokens.json
)

if not exist llama.cpp (
    git clone https://github.com/ggerganov/llama.cpp
)

cd llama.cpp
mingw32-make.exe
cd ..

if not exist "models\tokenizer.model" (
    set "GIT_LFS_SKIP_SMUDGE=1"
    git clone "https://huggingface.co/decapoda-research/llama-7b-hf" "llama-7b-hf"
    cd llama-7b-hf
    git lfs pull --include "tokenizer.model"
    copy "tokenizer.model" ..\models\
    cd ..
)

if not exist models\gpt4all mkdir models\gpt4all

if not exist "models\gpt4all\gpt4all-lora-quantized.bin" (
    curl -L -o models\gpt4all\gpt4all-lora-quantized.bin https://the-eye.eu/public/AI/models/nomic-ai/gpt4all/gpt4all-lora-quantized.bin
)

if not exist "models\gpt4all\ggml-model-q4_0.bin" (
    python -m venv venv
    venv\Scripts\pip.exe install -r llama.cpp\requirements.txt && venv\Scripts\pip.exe install --upgrade pip
    venv\Scripts\python.exe llama.cpp\convert.py models\gpt4all\gpt4all-lora-quantized.bin
)

if not exist whisper (
    git clone https://github.com/ggerganov/whisper.cpp.git whisper
)

cd whisper
git checkout master

if not exist "models\ggml-small.en.bin" (
    bash models\download-ggml-model.sh base.en
)

mingw32-make.exe
mingw32-make.exe talk-llama

talk-llama.exe -mw models\ggml-base.en.bin -ml ..\models\gpt4all\ggml-model-q4_0.bin -p "%name%" -t 8

cd ..

ENDLOCAL
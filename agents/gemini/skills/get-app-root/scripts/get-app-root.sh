#!/bin/bash

# 환경변수 fSnippetCli_config → 기본 경로 순으로 appRootPath 결정
if [ -n "$fSnippetCli_config" ]; then
    echo "$fSnippetCli_config"
else
    echo "$HOME/Documents/finfra/fSnippetData"
fi

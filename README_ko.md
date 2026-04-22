---
title: fSnippet Pro
description: macOS 메뉴바 스니펫 & 클립보드 관리 도구
date: 2026-03-26
---

[![en](https://img.shields.io/badge/lang-en-blue.svg)](./README.md)

<img src="./manual/app-icon.png" width="28" alt="fSnippet Icon"> [![제품 페이지](https://img.shields.io/badge/제품%20페이지-finfra.kr-blue)](https://finfra.kr/product/fSnippet/kr/index.html)

> **텍스트를 확장하세요, 강력한 스니펫 도구.**

macOS 메뉴바 스니펫 & 클립보드 관리 도구. 텍스트 스니펫을 관리하고, 클립보드 히스토리를 추적하며, 자주 사용하는 텍스트를 단축키로 빠르게 확장합니다.

## 에디션

| 에디션                    | 가격          | 인터페이스 | 설치 방법                                                       |
| :----------------------- | :----------- | :-------- | :------------------------------------------------------------- |
| **fSnippet Pro** (GUI)   | 유료          | GUI       | App Store (출시 예정)                                            |
| **fSnippetCli** (CLI)    | 무료 / 오픈소스 | CLI       | `brew install finfra/tap/fsnippetcli` ([소스코드](./cli/))      |

* **fSnippet Pro** - 직관적인 설정 화면, 시각적 스니펫 관리, 클립보드 히스토리 뷰어를 갖춘 정식 GUI 앱. Mac App Store에서 출시 예정.
* **fSnippetCli** - 완전 무료 오픈소스 CLI 버전. 모든 소스코드는 [`cli/`](./cli/) 디렉토리에 있으며 Homebrew로 설치 가능.

## 이 저장소에 대하여

이 저장소는 두 가지 역할을 함:

1. **fSnippet Pro** (GUI, 유료)의 사용자 지원 및 문서 제공
2. **fSnippetCli** (CLI, 무료)의 오픈소스 코드 저장소

## 주요 기능

* **즉시 접근** - 메뉴바에서 빠르게 접근
* **클립보드 히스토리** - 복사한 텍스트, 이미지, 링크를 모두 추적
* **빠른 스니펫 확장** - 단축키로 자주 사용하는 텍스트를 즉시 확장
* **세밀한 제어** - 앱별 제외 설정, 단축키 커스터마이징
* **간편한 관리** - 직관적인 UI로 스니펫 정리
* **텍스트 & 이미지 지원** - 텍스트와 이미지 스니펫 모두 저장
* **AI 에이전트 연동** - Claude, Gemini, MCP로 자동화

## AI 에이전트 연동

AI 에이전트로 fSnippet을 자동화하고 확장하세요. 모든 연동 방식은 내장 REST API를 기반으로 합니다.

| 플랫폼     | 연동 방식                        | 상세                                     |
| :--------- | :---------------------------- | :--------------------------------------- |
| **Claude** | Marketplace Plugin (Skill 포함) | [Claude Code에서 설치](./agents/claude/) |
| **Gemini** | Workflow를 통한 설치              | [Gemini에서 설치](./agents/gemini/)      |
| **MCP**    | Model Context Protocol 서버     | [MCP 서버 설정](./mcp/)                 |

## 시스템 요구사항

* macOS 14.0 이상

## 제품 페이지

| 언어    | 링크                                                                       |
| :------ | :------------------------------------------------------------------------- |
| English | [fSnippet - Product Page](http://finfra.kr/product/fSnippet/en/index.html) |
| 한국어  | [fSnippet - 제품 페이지](http://finfra.kr/product/fSnippet/kr/index.html)  |

## Finfra 다른 앱

| 앱                | 설명                           | 링크                                                            |
| :--------------- | :--------------------------- | :------------------------------------------------------------ |
| **fWarrange**    | 가장 완벽한 Mac 창 관리, 손쉬운 레이아웃 복원 | [제품 페이지](http://finfra.kr/product/fWarrange/kr/index.html)    |
| **fBanner**      | 클립보드를 복사하는 순간, 배너 이미지가 완성    | [제품 페이지](http://finfra.kr/product/fBanner/kr/index.html)      |
| **fBoard**       | 나만의 맞춤형 스크린 보드               | [제품 페이지](http://finfra.kr/product/fBoard/kr/index.html)       |
| **fQRGen**       | 클립보드를 복사하는 순간, QR 코드가 완성     | [제품 페이지](http://finfra.kr/product/fQRGen/kr/index.html)       |
| **fGoogleSheet** | 내 맥에서 가장 빠른 구글 시트 메뉴바 앱      | [제품 페이지](http://finfra.kr/product/fGoogleSheet/kr/index.html) |
## 문서

| 문서                                 | 설명                         |
| :--------------------------------- | :------------------------- |
| [매뉴얼](./manual/)                   | 사용자 매뉴얼 (한국어/영어)           |
| [REST API](./api/)                 | REST API 레퍼런스 & OpenAPI 명세 |
| [MCP 서버](./mcp/)                   | Model Context Protocol 서버  |
| [Claude Code 스킬](./agents/claude/) | Claude Code 플러그인           |
| [다국어 리소스](./localization/)         | 다국어 문자열 리소스 (10개 언어)       |
## 커뮤니티 & 지원

### 이슈
* [GitHub Issues](https://github.com/Finfra/fSnippet_public/issues)

### 게시판 (영어)
| 카테고리 | 링크                                                                    |
| :--- | :-------------------------------------------------------------------- |
| 공지   | [fSnippet Notice](https://finfra.kr/w1/category/fsnippet-notice/)     |
| 가이드  | [fSnippet Guide](https://finfra.kr/w1/category/fsnippet-guide/)       |
| 질문답변 | [fSnippet QnA](https://finfra.kr/w1/category/fsnippet-qna/)           |
| 피드백  | [fSnippet Feedback](https://finfra.kr/w1/category/fsnippet-feedback/) |
### 게시판 (한국어)
| 카테고리 | 링크                                                                  |
| :--- | :------------------------------------------------------------------ |
| 공지   | [fSnippet 공지](https://finfra.kr/w1/category/fsnippet-notice-kr/)    |
| 사용법  | [fSnippet 사용법](https://finfra.kr/w1/category/fsnippet-guide-kr/)    |
| 질문답변 | [fSnippet QnA](https://finfra.kr/w1/category/fsnippet-qna-kr/)      |
| 피드백  | [fSnippet 피드백](https://finfra.kr/w1/category/fsnippet-feedback-kr/) |
## 라이선스

Copyright (c) finfra.kr. All rights reserved.

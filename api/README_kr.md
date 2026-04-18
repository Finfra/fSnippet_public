---
title: fSnippet REST API 문서
description: fSnippet REST API 레퍼런스 및 사용 가이드
date: 2026-03-26
---

# 개요

fSnippet은 macOS 텍스트 스니펫 확장 도구로, 내장 NWListener 기반 경량 HTTP 서버를 통해 REST API를 제공합니다.
스니펫 검색/확장, 클립보드 히스토리, 사용 통계, 트리거 키 정보 등을 API로 조회할 수 있습니다.

| 항목      | 값                                                   |
| :------ | :-------------------------------------------------- |
| 서버 구현   | macOS 네이티브 앱 (Swift / Network.framework NWListener) |
| 기본 포트   | 3015                                                |
| API 활성화 | 기본 OFF (설정에서 명시적 활성화 필요)                            |
| 바인딩     | 기본 `127.0.0.1` (localhost 전용)                       |
> OpenAPI 3.0 스펙:
> - v1 (조회 중심): [openapi_v1.yaml](./openapi_v1.yaml)
> - v2 (설정 CRUD): [openapi_v2.yaml](./openapi_v2.yaml)

---

# 보안

- 기본적으로 모든 인터페이스에서 연결을 수락하지만, CIDR 필터로 요청을 제한합니다 (기본값 `127.0.0.1/32`, localhost 전용).
- 설정 > Advanced > "Allow External Access" 체크박스로 외부 접근을 허용할 수 있습니다.
- 외부 접근 허용 시 CIDR 필드 편집 가능 (예: `192.168.0.0/24`).
- 허용 CIDR 범위 밖의 IP 요청은 거부됩니다.

| 설정                    | 기본값            | 비고                 |
| :-------------------- | :------------- | :----------------- |
| API enabled           | **OFF**        | 설정에서 명시적 활성화 필요    |
| Port                  | `3015`         | 설정에서 변경 가능         |
| Allowed CIDR          | `127.0.0.1/32` | localhost 전용       |
| Allow external access | **OFF**        | 체크 해제 시 CIDR 필드 잠금 |
---

# 엔드포인트

# 1. 서버 상태 확인

```
GET /
```

**응답 (200)**:
```json
{
  "status": "ok",
  "app": "fSnippet",
  "version": "2.1.0",
  "port": 3015,
  "uptime_seconds": 3600,
  "snippet_count": 1937,
  "clipboard_count": 245
}
```

---

# 2. 스니펫 검색

```
GET /api/snippets/search?q={query}
```

## 요청 파라미터

| 필드       | 타입      | 필수  | 기본값 | 설명              |
| :------- | :------ | :-- | :-- | :-------------- |
| `q`      | string  | 예   | -   | 검색 쿼리           |
| `limit`  | integer | 아니오 | 20  | 최대 결과 수 (1~100) |
| `offset` | integer | 아니오 | 0   | 페이지네이션 오프셋      |
| `folder` | string  | 아니오 | -   | 폴더명으로 필터        |
## 응답

**성공 (200)**: 관련도 순으로 정렬된 스니펫 목록

**에러**:

| 상태 코드 | 원인       | 응답 예시                                                                                |
| :---- | :------- | :----------------------------------------------------------------------------------- |
| 400   | 검색 쿼리 누락 | `{"success": false, "error": {"code": "MISSING_QUERY", "message": "Missing query"}}` |
---

# 3. Abbreviation으로 스니펫 조회

```
GET /api/snippets/by-abbreviation/{abbrev}
```

| 필드       | 타입            | 필수  | 설명                                                     |
| :------- | :------------ | :-- | :----------------------------------------------------- |
| `abbrev` | string (path) | 예   | Abbreviation (URL-encoded, 예: `awsec2{right_command}`) |
**성공 (200)**: 스니펫 상세 정보 (내용, 태그, 플레이스홀더 등)

**에러**: 404 - 스니펫 없음

---

# 4. ID로 스니펫 상세 조회

```
GET /api/snippets/{id}
```

| 필드   | 타입            | 필수  | 설명                                                   |
| :--- | :------------ | :-- | :--------------------------------------------------- |
| `id` | string (path) | 예   | 스니펫 ID (URL-encoded, 예: `AWS%2Fec2%3D%3D%3DEC2.txt`) |
**성공 (200)**: 스니펫 상세 정보

**에러**: 404 - 스니펫 없음

---

# 5. 스니펫 확장

```
POST /api/snippets/expand
Content-Type: application/json
```

## 요청 파라미터

| 필드                   | 타입     | 필수  | 설명                             |
| :------------------- | :----- | :-- | :----------------------------- |
| `abbreviation`       | string | 예   | 확장할 abbreviation               |
| `placeholder_values` | object | 아니오 | 플레이스홀더 값 매핑 (키: 이름, 값: 대체 텍스트) |
## 요청 예시

```json
{
  "abbreviation": "awsec2{right_command}",
  "placeholder_values": {
    "clipboard": "i-0123456789abcdef0"
  }
}
```

## 응답

**성공 (200)**:
```json
{
  "success": true,
  "data": {
    "original_abbreviation": "awsec2{right_command}",
    "snippet_id": "AWS/ec2===EC2.txt",
    "expanded_text": "ssh ec2-user@i-0123456789abcdef0",
    "delete_count": 8,
    "placeholders_resolved": ["clipboard"]
  }
}
```

**에러**:

| 상태 코드 | 원인          |
| :---- | :---------- |
| 400   | JSON 파싱 실패  |
| 404   | 매칭되는 스니펫 없음 |
> 키보드 입력을 시뮬레이션하지 않고 텍스트 데이터만 반환합니다.

---

# 6. 클립보드 히스토리 조회

```
GET /api/clipboard/history
```

## 요청 파라미터

| 필드       | 타입      | 필수  | 기본값 | 설명                                             |
| :------- | :------ | :-- | :-- | :--------------------------------------------- |
| `limit`  | integer | 아니오 | 50  | 최대 결과 수 (1~200)                                |
| `offset` | integer | 아니오 | 0   | 페이지네이션 오프셋                                     |
| `kind`   | string  | 아니오 | -   | 콘텐츠 종류 필터 (`plain_text`, `image`, `file_list`) |
| `app`    | string  | 아니오 | -   | 소스 앱 번들 ID 필터 (예: `com.apple.Safari`)          |
| `pinned` | boolean | 아니오 | -   | 고정 항목만 필터                                      |
**성공 (200)**: 역순(최신순) 클립보드 히스토리 목록

---

# 7. 클립보드 항목 상세 조회

```
GET /api/clipboard/history/{id}
```

| 필드   | 타입             | 필수  | 설명         |
| :--- | :------------- | :-- | :--------- |
| `id` | integer (path) | 예   | 클립보드 항목 ID |
**성공 (200)**: 전체 텍스트 포함 상세 정보

**에러**: 404 - 항목 없음

---

# 8. 클립보드 히스토리 검색

```
GET /api/clipboard/search?q={query}
```

| 필드       | 타입      | 필수  | 기본값 | 설명         |
| :------- | :------ | :-- | :-- | :--------- |
| `q`      | string  | 예   | -   | 검색 쿼리      |
| `limit`  | integer | 아니오 | 50  | 최대 결과 수    |
| `offset` | integer | 아니오 | 0   | 페이지네이션 오프셋 |
**에러**: 400 - 검색 쿼리 누락

---

# 9. 폴더 목록 조회

```
GET /api/folders
```

**성공 (200)**: 규칙 정보 포함 스니펫 폴더 목록

---

# 10. 폴더 상세 (스니펫 포함)

```
GET /api/folders/{name}
```

| 필드       | 타입            | 필수  | 기본값 | 설명                |
| :------- | :------------ | :-- | :-- | :---------------- |
| `name`   | string (path) | 예   | -   | 폴더명 (URL-encoded) |
| `limit`  | integer       | 아니오 | 50  | 최대 스니펫 수          |
| `offset` | integer       | 아니오 | 0   | 페이지네이션 오프셋        |
**에러**: 404 - 폴더 없음

---

# 11. 사용 통계 (Top N)

```
GET /api/stats/top
```

| 필드      | 타입      | 필수  | 기본값 | 설명             |
| :------ | :------ | :-- | :-- | :------------- |
| `limit` | integer | 아니오 | 10  | 상위 결과 수 (1~50) |
**성공 (200)**: 가장 자주 사용된 스니펫 목록

---

# 12. 사용 이력

```
GET /api/stats/history
```

| 필드       | 타입      | 필수  | 기본값 | 설명               |
| :------- | :------ | :-- | :-- | :--------------- |
| `limit`  | integer | 아니오 | 100 | 최대 결과 수          |
| `offset` | integer | 아니오 | 0   | 페이지네이션 오프셋       |
| `from`   | string  | 아니오 | -   | 시작 날짜 (ISO 8601) |
| `to`     | string  | 아니오 | -   | 종료 날짜 (ISO 8601) |
**성공 (200)**: 시간순 사용 이력

---

# 13. 트리거 키 조회

```
GET /api/triggers
```

**성공 (200)**:
```json
{
  "success": true,
  "data": {
    "default": {
      "symbol": "{right_command}",
      "key_code": 42,
      "description": "Option+X"
    },
    "active": [...]
  }
}
```

---

# 공통 에러 응답

모든 에러는 동일한 형식을 따릅니다:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Snippet not found"
  }
}
```

| 상태 코드 | 코드                                  | 설명                              |
| :---- | :---------------------------------- | :------------------------------ |
| 400   | `MISSING_QUERY` / `INVALID_REQUEST` | 잘못된 요청 (JSON 파싱 실패, 필수 파라미터 누락) |
| 404   | `NOT_FOUND`                         | 리소스 없음                          |
---

# 사용 예시

# cURL

```bash
# 헬스 체크
curl http://localhost:3015/

# 스니펫 검색
curl "http://localhost:3015/api/snippets/search?q=docker&limit=10"

# Abbreviation으로 스니펫 조회
curl "http://localhost:3015/api/snippets/by-abbreviation/awsec2%E2%97%8A"

# 스니펫 확장
curl -X POST http://localhost:3015/api/snippets/expand \
  -H "Content-Type: application/json" \
  -d '{"abbreviation": "bb{right_command}"}'

# 플레이스홀더 포함 확장
curl -X POST http://localhost:3015/api/snippets/expand \
  -H "Content-Type: application/json" \
  -d '{"abbreviation": "awsec2{right_command}", "placeholder_values": {"clipboard": "i-0123456789abcdef0"}}'

# 클립보드 히스토리 조회
curl "http://localhost:3015/api/clipboard/history?limit=20"

# 클립보드 검색
curl "http://localhost:3015/api/clipboard/search?q=password"

# 폴더 목록
curl http://localhost:3015/api/folders

# 폴더 상세 (AWS 폴더)
curl "http://localhost:3015/api/folders/AWS"

# 사용 통계 Top 10
curl "http://localhost:3015/api/stats/top?limit=10"

# 사용 이력 (날짜 범위)
curl "http://localhost:3015/api/stats/history?from=2026-01-01T00:00:00Z&to=2026-03-18T23:59:59Z"

# 트리거 키 조회
curl http://localhost:3015/api/triggers
```

# Python

```python
import requests

BASE = "http://localhost:3015"

# 헬스 체크
resp = requests.get(f"{BASE}/")
print(resp.json())

# 스니펫 검색
resp = requests.get(f"{BASE}/api/snippets/search", params={"q": "docker", "limit": 10})
for s in resp.json()["data"]:
    print(f"{s['abbreviation']} -> {s['description']}")

# 스니펫 확장
resp = requests.post(f"{BASE}/api/snippets/expand", json={"abbreviation": "bb{right_command}"})
print(resp.json()["data"]["expanded_text"])

# 클립보드 히스토리
resp = requests.get(f"{BASE}/api/clipboard/history", params={"limit": 5})
for item in resp.json()["data"]:
    print(f"[{item['kind']}] {item['text_preview']}")
```

---

# 테스트

```bash
# 자동화 테스트 (17개 항목)
bash api/test-api.sh

# 원격 서버 테스트
bash api/test-api.sh --server=http://192.168.0.10:3015
```

테스트 항목:
1. 서버 상태 확인 (GET `/`)
2. 스니펫 검색 및 결과 검증
3. 스니펫 검색 – 쿼리 누락 (400)
4. 스니펫 확장 (POST)
5. 스니펫 확장 – 잘못된 JSON (400)
6. Abbreviation으로 스니펫 조회 – 없음 (404)
7. ID로 스니펫 조회 – 없음 (404)
8. 클립보드 히스토리 조회
9. 클립보드 검색
10. 클립보드 검색 – 쿼리 누락 (400)
11. 클립보드 상세 – 없음 (404)
12. 폴더 목록 조회
13. 폴더 상세 – 없음 (404)
14. 사용 통계 Top N
15. 사용 이력
16. 트리거 키 정보
17. 알 수 없는 경로 – 404 응답

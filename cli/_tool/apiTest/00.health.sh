#!/bin/bash
# health check는 /api/v1/ 가 아닌 루트(/) 엔드포인트
curl -s --connect-timeout 3 http://localhost:3015/ | jq .

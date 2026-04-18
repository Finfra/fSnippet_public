#!/bin/bash
# 정상: settings get (general 기본)
$CLI settings get
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC

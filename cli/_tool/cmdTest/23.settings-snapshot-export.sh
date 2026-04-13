#!/bin/bash
# 정상: settings snapshot export (stdout)
$CLI settings snapshot export
RC=$?
if [ $RC -eq 0 ]; then echo "✅ PASS (exit=$RC)"; else echo "❌ FAIL (exit=$RC)"; fi
exit $RC

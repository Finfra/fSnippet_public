#!/usr/bin/env node

/**
 * fSnippet MCP Server
 *
 * Usage:
 *   node index.js [--server=<url>]
 *
 * Arguments:
 *   --server=<url> : (옵션) fSnippet REST API 서버 주소 (기본값: http://localhost:3015)
 *
 * Environment:
 *   FSNIPPET_SERVER : fSnippet REST API 서버 주소 (--server 옵션보다 우선순위 낮음)
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// 서버 주소 결정: CLI 인자 > 환경변수 > 기본값
function getServerUrl() {
  const arg = process.argv.find((a) => a.startsWith("--server="));
  if (arg) return arg.split("=").slice(1).join("=");
  return process.env.FSNIPPET_SERVER || "http://localhost:3015";
}

const SERVER_URL = getServerUrl();

const server = new McpServer({
  name: "fsnippet-mcp",
  version: "1.0.0",
});

// 공통 fetch 헬퍼
async function apiFetch(path, options = {}) {
  const url = `${SERVER_URL}${path}`;
  const res = await fetch(url, options);
  const json = await res.json();
  return { res, json };
}

function textResult(text) {
  return { content: [{ type: "text", text }] };
}

function errorResult(message) {
  return { isError: true, content: [{ type: "text", text: message }] };
}

// Tool 1: health_check
server.tool(
  "health_check",
  "fSnippet 서버 상태를 확인합니다. 앱 버전, 포트, 가동 시간, 스니펫/클립보드 수를 반환합니다.",
  {},
  async () => {
    try {
      const { json } = await apiFetch("/");
      return textResult(JSON.stringify(json, null, 2));
    } catch (err) {
      return errorResult(`서버 연결 실패: ${err.message}\n서버 주소: ${SERVER_URL}`);
    }
  }
);

// Tool 2: search_snippets
server.tool(
  "search_snippets",
  "키워드로 스니펫을 검색합니다. 축약어, 폴더명, 태그, 설명에서 검색합니다.",
  {
    query: z.string().describe("검색 키워드"),
    limit: z
      .number()
      .default(20)
      .describe("최대 결과 수 (기본: 20, 최대: 100)"),
    folder: z.string().optional().describe("특정 폴더로 필터링"),
    offset: z.number().optional().describe("결과 시작 위치 (페이징용)"),
  },
  async ({ query, limit, folder, offset }) => {
    try {
      const params = new URLSearchParams({
        q: query,
        limit: String(limit ?? 20),
      });
      if (folder) params.set("folder", folder);
      if (offset !== undefined) params.set("offset", String(offset));
      const { res, json } = await apiFetch(
        `/api/snippets/search?${params}`
      );
      if (!res.ok) {
        return errorResult(
          `검색 실패 (${res.status}): ${json.error?.message || res.statusText}`
        );
      }
      return textResult(JSON.stringify(json, null, 2));
    } catch (err) {
      return errorResult(
        `검색 오류: ${err.message}\n서버 주소: ${SERVER_URL}`
      );
    }
  }
);

// Tool 3: get_snippet
server.tool(
  "get_snippet",
  "축약어 또는 ID로 스니펫 상세 정보를 조회합니다. 전체 내용, 플레이스홀더 정보를 포함합니다.",
  {
    abbreviation: z
      .string()
      .optional()
      .describe("스니펫 축약어 (예: bb◊, awsec2◊)"),
    id: z
      .string()
      .optional()
      .describe("스니펫 ID (예: AWS/ec2===EC2.txt)"),
  },
  async ({ abbreviation, id }) => {
    try {
      if (!abbreviation && !id) {
        return errorResult(
          "abbreviation 또는 id 중 하나를 지정해야 합니다."
        );
      }
      let path;
      if (abbreviation) {
        path = `/api/snippets/by-abbreviation/${encodeURIComponent(abbreviation)}`;
      } else {
        path = `/api/snippets/${encodeURIComponent(id)}`;
      }
      const { res, json } = await apiFetch(path);
      if (!res.ok) {
        return errorResult(
          `조회 실패 (${res.status}): ${json.error?.message || res.statusText}`
        );
      }
      return textResult(JSON.stringify(json, null, 2));
    } catch (err) {
      return errorResult(
        `조회 오류: ${err.message}\n서버 주소: ${SERVER_URL}`
      );
    }
  }
);

// Tool 4: expand_snippet
server.tool(
  "expand_snippet",
  "축약어를 전체 텍스트로 확장합니다. 플레이스홀더 값을 전달할 수 있습니다.",
  {
    abbreviation: z.string().describe("확장할 축약어 (예: bb◊)"),
    placeholder_values: z
      .record(z.string(), z.string())
      .optional()
      .describe(
        "플레이스홀더 값 매핑 (키: 플레이스홀더 이름, 값: 대체 텍스트)"
      ),
  },
  async ({ abbreviation, placeholder_values }) => {
    try {
      const body = { abbreviation };
      if (placeholder_values) body.placeholder_values = placeholder_values;
      const { res, json } = await apiFetch("/api/snippets/expand", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        return errorResult(
          `확장 실패 (${res.status}): ${json.error?.message || res.statusText}`
        );
      }
      return textResult(JSON.stringify(json, null, 2));
    } catch (err) {
      return errorResult(
        `확장 오류: ${err.message}\n서버 주소: ${SERVER_URL}`
      );
    }
  }
);

// Tool 5: clipboard_history
server.tool(
  "clipboard_history",
  "클립보드 히스토리를 조회합니다. 종류(텍스트/이미지/파일), 앱, 고정 여부로 필터링 가능합니다.",
  {
    limit: z
      .number()
      .default(50)
      .describe("최대 결과 수 (기본: 50, 최대: 200)"),
    kind: z
      .enum(["plain_text", "image", "file_list"])
      .optional()
      .describe("콘텐츠 종류 필터"),
    app: z
      .string()
      .optional()
      .describe("소스 앱 번들 ID로 필터 (예: com.apple.Safari)"),
    pinned: z.boolean().optional().describe("고정된 항목만 필터"),
    offset: z.number().optional().describe("결과 시작 위치 (페이징용)"),
  },
  async ({ limit, kind, app, pinned, offset }) => {
    try {
      const params = new URLSearchParams({
        limit: String(limit ?? 50),
      });
      if (kind) params.set("kind", kind);
      if (app) params.set("app", app);
      if (pinned !== undefined) params.set("pinned", String(pinned));
      if (offset !== undefined) params.set("offset", String(offset));
      const { res, json } = await apiFetch(
        `/api/clipboard/history?${params}`
      );
      if (!res.ok) {
        return errorResult(
          `히스토리 조회 실패 (${res.status}): ${json.error?.message || res.statusText}`
        );
      }
      return textResult(JSON.stringify(json, null, 2));
    } catch (err) {
      return errorResult(
        `히스토리 오류: ${err.message}\n서버 주소: ${SERVER_URL}`
      );
    }
  }
);

// Tool 6: clipboard_search
server.tool(
  "clipboard_search",
  "클립보드 히스토리에서 텍스트를 검색합니다.",
  {
    query: z.string().describe("검색 키워드"),
    limit: z
      .number()
      .default(50)
      .describe("최대 결과 수 (기본: 50)"),
    offset: z.number().optional().describe("결과 시작 위치 (페이징용)"),
  },
  async ({ query, limit, offset }) => {
    try {
      const params = new URLSearchParams({
        q: query,
        limit: String(limit ?? 50),
      });
      if (offset !== undefined) params.set("offset", String(offset));
      const { res, json } = await apiFetch(
        `/api/clipboard/search?${params}`
      );
      if (!res.ok) {
        return errorResult(
          `검색 실패 (${res.status}): ${json.error?.message || res.statusText}`
        );
      }
      return textResult(JSON.stringify(json, null, 2));
    } catch (err) {
      return errorResult(
        `검색 오류: ${err.message}\n서버 주소: ${SERVER_URL}`
      );
    }
  }
);

// Tool 7: list_folders
server.tool(
  "list_folders",
  "스니펫 폴더 목록을 조회합니다. 각 폴더의 prefix, suffix, 스니펫 수, 규칙 정보를 포함합니다.",
  {
    name: z
      .string()
      .optional()
      .describe(
        "특정 폴더명을 지정하면 해당 폴더의 스니펫 목록도 함께 반환"
      ),
    limit: z.number().optional().describe("스니펫 목록 최대 결과 수 (폴더 지정 시)"),
    offset: z.number().optional().describe("스니펫 목록 시작 위치 (폴더 지정 시, 페이징용)"),
  },
  async ({ name, limit, offset }) => {
    try {
      let path = "/api/folders";
      if (name) {
        const params = new URLSearchParams();
        if (limit !== undefined) params.set("limit", String(limit));
        if (offset !== undefined) params.set("offset", String(offset));
        const qs = params.toString();
        path = `/api/folders/${encodeURIComponent(name)}${qs ? `?${qs}` : ""}`;
      }
      const { res, json } = await apiFetch(path);
      if (!res.ok) {
        return errorResult(
          `폴더 조회 실패 (${res.status}): ${json.error?.message || res.statusText}`
        );
      }
      return textResult(JSON.stringify(json, null, 2));
    } catch (err) {
      return errorResult(
        `폴더 오류: ${err.message}\n서버 주소: ${SERVER_URL}`
      );
    }
  }
);

// Tool 8: get_stats
server.tool(
  "get_stats",
  "스니펫 사용 통계를 조회합니다. 가장 많이 사용된 스니펫 또는 사용 히스토리를 반환합니다.",
  {
    type: z
      .enum(["top", "history"])
      .default("top")
      .describe("통계 유형: top(상위 N개) 또는 history(사용 이력)"),
    limit: z
      .number()
      .default(10)
      .describe("결과 수 (기본: top=10, history=100)"),
    from: z
      .string()
      .optional()
      .describe("시작 날짜 (ISO 8601, history 전용)"),
    to: z
      .string()
      .optional()
      .describe("종료 날짜 (ISO 8601, history 전용)"),
    offset: z.number().optional().describe("결과 시작 위치 (페이징용, history 전용)"),
  },
  async ({ type, limit, from, to, offset }) => {
    try {
      const statsType = type ?? "top";
      const params = new URLSearchParams({
        limit: String(limit ?? 10),
      });
      if (statsType === "history") {
        if (from) params.set("from", from);
        if (to) params.set("to", to);
        if (offset !== undefined) params.set("offset", String(offset));
      }
      const { res, json } = await apiFetch(
        `/api/stats/${statsType}?${params}`
      );
      if (!res.ok) {
        return errorResult(
          `통계 조회 실패 (${res.status}): ${json.error?.message || res.statusText}`
        );
      }
      return textResult(JSON.stringify(json, null, 2));
    } catch (err) {
      return errorResult(
        `통계 오류: ${err.message}\n서버 주소: ${SERVER_URL}`
      );
    }
  }
);

// Tool 9: get_triggers
server.tool(
  "get_triggers",
  "활성 트리거 키 정보를 조회합니다. 기본 트리거 키와 활성 트리거 목록을 반환합니다.",
  {},
  async () => {
    try {
      const { res, json } = await apiFetch("/api/triggers");
      if (!res.ok) {
        return errorResult(
          `트리거 조회 실패 (${res.status}): ${json.error?.message || res.statusText}`
        );
      }
      return textResult(JSON.stringify(json, null, 2));
    } catch (err) {
      return errorResult(
        `트리거 오류: ${err.message}\n서버 주소: ${SERVER_URL}`
      );
    }
  }
);

// 서버 시작
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("MCP 서버 시작 실패:", err);
  process.exit(1);
});

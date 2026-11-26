#!/usr/bin/env node
// Claude Code hook: 권한 요청(Notification)과 작업 완료(Stop) 시 Slack Incoming Webhook으로 알림을 보냅니다.
// 알림 실패가 Claude 작업을 막지 않도록 항상 exit 0으로 종료하며, stdout에는 아무것도 출력하지 않습니다.

import { existsSync } from "node:fs";
import path from "node:path";

const MAX_SUMMARY_LENGTH = 200;
const SEND_TIMEOUT_MS = 5000;

// stdin 전체를 문자열로 읽습니다.
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}

// 프로젝트 루트의 .env를 process.env에 불러옵니다.
// 이미 설정된 환경변수는 덮어쓰지 않으며, .env가 없으면 아무 일도 하지 않습니다.
function loadProjectEnv(projectDir) {
  const envPath = path.join(projectDir, ".env");
  if (existsSync(envPath)) {
    process.loadEnvFile(envPath);
  }
}

// Slack mrkdwn에서 멘션(<!channel>)이나 링크로 해석되지 않도록 특수 문자를 이스케이프합니다.
function escapeSlack(text) {
  return text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
}

// 코드포인트 단위로 자르므로 이모지가 중간에서 깨지지 않습니다.
function truncate(text, maxLength) {
  const chars = Array.from(text);
  return chars.length > maxLength ? `${chars.slice(0, maxLength).join("")}…` : text;
}

// 한국 시간(KST) 기준 "YYYY-MM-DD HH:mm" 문자열을 만듭니다. 실행 환경의 시간대와 무관합니다.
function formatTime() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date());
  const getPart = (type) => parts.find((part) => part.type === type).value;
  return `${getPart("year")}-${getPart("month")}-${getPart("day")} ${getPart("hour")}:${getPart("minute")}`;
}

// 공통 알림 레이아웃: 프로젝트/상태/시간 헤더와 선택적 본문(요약 또는 요청 메시지)
// body는 이미 이스케이프된 문자열이어야 합니다.
function buildLayout(projectName, status, body) {
  const lines = [`프로젝트: ${projectName}`, `상태    : ${status}`, `시간    : ${formatTime()}`];
  if (body) {
    lines.push("", body);
  }
  return lines.join("\n");
}

// hook_event_name에 따라 알림 문구를 만듭니다. 지원하지 않는 이벤트면 null을 반환합니다.
function buildMessage(payload) {
  const projectName = escapeSlack(path.basename(payload.cwd ?? process.env.CLAUDE_PROJECT_DIR ?? ""));

  switch (payload.hook_event_name) {
    case "Notification":
      return buildLayout(projectName, "🔐 권한 요청", escapeSlack(payload.message ?? ""));
    case "Stop": {
      const summary = truncate((payload.last_assistant_message ?? "").trim(), MAX_SUMMARY_LENGTH);
      return buildLayout(projectName, "✅ 작업 완료", escapeSlack(summary));
    }
    default:
      return null;
  }
}

// Slack Incoming Webhook으로 메시지를 전송합니다.
async function send(webhookUrl, text) {
  const response = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text }),
    signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
  });

  if (!response.ok) {
    throw new Error(`Slack 전송 실패: HTTP ${response.status}`);
  }
}

async function main() {
  const payload = JSON.parse(await readStdin());

  // hook 프로세스는 .env를 자동으로 읽지 않으므로 직접 불러옵니다.
  // cwd는 하위 폴더일 수 있어 프로젝트 루트 변수를 우선합니다.
  loadProjectEnv(process.env.CLAUDE_PROJECT_DIR ?? payload.cwd ?? process.cwd());

  // 웹훅 URL이 없으면 알림을 끕니다. (설정하지 않은 사용자에게 영향이 없도록)
  const webhookUrl = process.env.SLACK_WEBHOOK_URL;
  if (!webhookUrl) {
    return;
  }

  const text = buildMessage(payload);
  if (!text) {
    return;
  }

  // 검증용: 실제 전송 없이 메시지를 stderr에 출력합니다.
  if (process.env.SLACK_NOTIFY_DRY_RUN === "1") {
    process.stderr.write(`${text}\n`);
    return;
  }

  await send(webhookUrl, text);
}

try {
  await main();
} catch (error) {
  // 실패 원인은 claude --debug 로그에서 확인할 수 있도록 stderr에만 남깁니다.
  process.stderr.write(`[slack-notify] ${error.message}\n`);
}

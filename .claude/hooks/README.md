# Slack 알림 hook

Claude Code가 **권한을 요청할 때**와 **작업을 마쳤을 때** Slack 채널로 알림을 보냅니다. 모바일 Slack 앱으로 받으면 자리를 비워도 진행 상황을 알 수 있습니다.

| 이벤트 | 시점 | 알림 내용 |
|---|---|---|
| `Notification` (`permission_prompt`) | 권한 승인 프롬프트가 약 6초 이상 대기할 때 | 헤더(프로젝트/상태/시간) + 요청 메시지 |
| `Stop` | Claude가 응답을 끝낼 때마다 | 헤더(프로젝트/상태/시간) + 마지막 응답 요약(200자) |

알림 형식:

```
프로젝트: web-starter-kit
상태    : ✅ 작업 완료
시간    : 2026-11-26 23:55

<요약 또는 요청 메시지>
```

시간은 한국 시간(KST) 기준입니다.

## 구성 파일

| 파일 | 커밋 | 역할 |
|---|---|---|
| `.claude/settings.json` | O | hook 이벤트 등록 |
| `.claude/hooks/slack-notify.mjs` | O | stdin JSON을 읽어 `.env`를 로드하고 Slack으로 전송 |
| `.env` | **X** (gitignore) | 웹훅 URL(`SLACK_WEBHOOK_URL`) 저장 |

> 웹훅 URL은 **`.env`에만** 입력하세요. `settings.json`이나 다른 커밋 대상 파일에 넣으면 노출됩니다.

## 설정 방법

1. **웹훅 발급**
   1. https://api.slack.com/apps 에서 `Create New App` → `From scratch`
   2. 앱 메뉴 `Incoming Webhooks` 활성화 → `Add New Webhook to Workspace`
   3. 알림받을 채널(또는 본인 DM) 선택 → 발급된 URL 복사
2. **URL 입력**: 프로젝트 루트의 `.env` 파일에 `SLACK_WEBHOOK_URL=<발급받은 URL>` 작성
3. **모바일 알림 설정**
   - 해당 채널의 알림을 "모든 새 메시지"로 설정
   - Slack 모바일 앱에서 푸시 알림 허용
   - 데스크톱 Slack을 사용 중이면 모바일 푸시가 지연될 수 있습니다
4. **Claude Code 재시작** 후 `/hooks` 명령으로 `Notification`, `Stop` 등록을 확인합니다.

## 동작 확인 (웹훅 없이)

`SLACK_NOTIFY_DRY_RUN=1`을 주면 전송하지 않고 메시지만 stderr에 출력합니다. 프로젝트 루트에서 실행하세요.

```bash
echo '{"hook_event_name":"Stop","last_assistant_message":"테스트 응답입니다","cwd":"D:/Project Folder/workspace/web-starter-kit"}' \
  | SLACK_WEBHOOK_URL=x SLACK_NOTIFY_DRY_RUN=1 node .claude/hooks/slack-notify.mjs
```

실제 전송 테스트는 `SLACK_NOTIFY_DRY_RUN`을 빼고 실행합니다. `.env`에 `SLACK_WEBHOOK_URL`이 설정된 상태여야 합니다.

> 셸 환경변수로 `SLACK_WEBHOOK_URL`을 지정하면 `.env`보다 우선합니다.

## 동작 원칙

- 웹훅 URL이 없으면 아무 일도 하지 않습니다. 스타터 킷을 복제해도 다른 사람에게 영향이 없습니다.
- 알림 실패가 Claude 작업을 막지 않도록 항상 exit 0으로 끝납니다. 실패 원인은 stderr에 남습니다.
- Slack 특수 문자(`<`, `>`, `&`)는 이스케이프됩니다. 응답 본문의 `<!channel>` 같은 문자열로 전체 멘션이 울리지 않습니다.

## 문제 해결

- 알림이 오지 않으면 `claude --debug`로 실행해 hook 로그를 확인합니다. hook 실패는 화면에 표시되지 않습니다.
- 스크립트가 `.env`를 직접 읽으므로 Claude Code의 환경변수 전달 방식에 의존하지 않습니다. `.env`가 없거나 `SLACK_WEBHOOK_URL`이 비어 있으면 알림이 꺼집니다.
- `bypassPermissions`, `dontAsk` 모드에서는 권한 프롬프트 자체가 없어 `permission_prompt` 알림이 발생하지 않습니다.

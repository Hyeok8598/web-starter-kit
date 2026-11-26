#!/usr/bin/env bash
# Claude Code PreToolUse 훅 (Bash, PowerShell 도구)
# 파일 삭제, Git 강제 Push, 소스 유실 위험이 있는 명령을 실행 전에 검사합니다.
#   deny : 실행 차단 / ask : 사용자 승인 요청 / allow : 프롬프트 없이 허용
#   해당 없음 : 아무것도 출력하지 않아 기존 권한 흐름을 따릅니다.
#
# 한계: 정규식 기반 사고 방지 장치이며 보안 경계가 아닙니다.
#       난독화, 스크립트 파일 내부, alias, 심볼릭 링크는 탐지하지 못합니다.
#       훅 자체가 실패하면 명령이 그대로 실행됩니다(fail-open).

set -f # 토큰 분리 시 와일드카드(*) 확장을 막습니다.

RANK=0
LEVEL=""
REASON=""
NORM=""

# ── 정규식 (소문자 기준) ──────────────────────────────
# 재귀 삭제: rm -r/-rf, Remove-Item -Recurse, rd /s, del /s
RM_CMD_RE='(^|[^[:alnum:]_./-])(rm|ri|remove-item|unlink|rmdir)[[:space:]]'
RECURSE_FLAG_RE='(^|[[:space:]])(-[a-z]*r[a-z]*|--recursive)([[:space:]]|$)'
CMD_RECURSE_RE='(^|[^[:alnum:]_])(rd|rmdir|del|erase)([[:space:]].*)?[[:space:]]/s([[:space:]]|$)'
DEL_CMD_RE='(^|[^[:alnum:]_./-])(rm|ri|remove-item|unlink|rmdir|del|erase|rd)[[:space:]]'
PROTECTED_ENV_RE='(^|[/\\])\.env($|\.)'
ENV_TEMPLATE_RE='\.env\.(example|sample|template)$'
PROTECTED_GIT_RE='(^|[/\\])\.git/?\*?$'
# find 일괄 삭제, mv/Move-Item 이동 (보호 파일 이동 검사용)
FIND_DELETE_RE='(^|[^[:alnum:]_./-])find[[:space:]][^;&|]*(-delete|-exec(dir)?[[:space:]]+rm)([[:space:]]|$)'
FIND_FILTER_RE='[[:space:]]-(name|iname|path|ipath|regex|type|mtime|newer|empty|size)([[:space:]]|$)'
MOVE_CMD_RE='(^|[^[:alnum:]_./-])(mv|move|move-item|rename-item|ren)[[:space:]]'
# git branch 강제 삭제 (-df, --delete --force 등)
BRANCH_CMD_RE='(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*branch[[:space:]]'
BRANCH_DELETE_OPT_RE='(^|[[:space:]])(-[a-z]*d[a-z]*|--delete)([[:space:]]|$)'
BRANCH_FORCE_OPT_RE='(^|[[:space:]])(-[a-z]*f[a-z]*|--force)([[:space:]]|$)'
# 따옴표로 감싼 강제 Push 옵션 (소문자 원본 명령 기준)
PUSH_QUOTED_FORCE_RE="(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*push[^;&|]*[\"'](\\+|--force|-[a-z]*f)"
# --force-if-includes 단독은 lease 없는 강제 Push와 같으므로 차단 대상
PUSH_IF_INCLUDES_RE='(^|[[:space:]])--force-if-includes([[:space:]]|$)'
# 루트, 홈, 드라이브, 시스템 경로 (토큰은 소문자로 바꾼 뒤 검사)
# 시스템 경로는 하위 전체를, 사용자 경로(/home, C:\Users)는 정확히 일치할 때만 차단합니다.
DANGER_TARGET_RE='^(/+\*?|\.\.?/?\*?|\.\*|\*|\*\.\*|~/?\*?|\$\{?home\}?/?\*?|%userprofile%/?\*?|\$\{?env:userprofile\}?/?\*?|[a-z]:[\\/]?\*?|/[a-z]/?\*?|/(home|users)/?\*?|/(bin|boot|dev|etc|lib|lib64|opt|root|sbin|sys|system|library|applications|usr|var)(/.*)?|[a-z]:[\\/]users/?\*?|[a-z]:[\\/](windows|program|programdata)([\\/].*)?|%systemroot%|%windir%|\$\{?env:systemroot\}?|\$\{?env:windir\}?)$'
# 재생성 가능한 산출물 폴더
REGEN_RE='^(node_modules|\.next|dist|build|out|coverage|\.turbo|\.cache)$'
# 셸을 한 번 더 감싸는 명령 (이 경우 따옴표 안 내용도 검사합니다)
WRAPPER_RE='(^|[^[:alnum:]_.-])(bash|sh|zsh|eval|pwsh|powershell|cmd)([[:space:]]|$)'
# Git
GIT_PUSH_RE='(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*push([[:space:]]+([^;&|]*))?'
RESET_HARD_RE='(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*reset[^;&|]*--(hard|merge)'
CLEAN_RE='(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*clean([[:space:]]|$)'
CLEAN_DRY_RE='(^|[[:space:]])(-[a-z]*n[a-z]*|--dry-run)([[:space:]]|$)'
CLEAN_FORCE_RE='(^|[[:space:]])(-[a-z]*f[a-z]*|--force)([[:space:]]|$)'
CHECKOUT_RE='(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*checkout[[:space:]]([^;&|]*[[:space:]])?(--([[:space:]]|$)|\.([[:space:]]|$)|-f([[:space:]]|$)|--force([[:space:]]|$))'
RESTORE_RE='(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*restore([[:space:]]|$)'
STASH_RE='(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*stash[[:space:]]+(drop|clear)([[:space:]]|$)'
BRANCH_FORCE_DELETE_RE='(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*branch[^;&|]*[[:space:]]-D([[:space:]]|$)'
NO_VERIFY_RE='(^|[^[:alnum:]_-])git[[:space:]]+[^;&|]*(commit|push)[^;&|]*--no-verify'
PUSH_DRY_RE='(^|[[:space:]])--dry-run([[:space:]]|$)'
PUSH_MIRROR_RE='(^|[[:space:]])--mirror([[:space:]]|$)'
PUSH_FORCE_RE='(^|[[:space:]])(--force|--force=[^[:space:]]*|-[a-z]*f[a-z]*)([[:space:]]|$)'
PUSH_PLUS_RE='(^|[[:space:]])\+[^[:space:]]'
PUSH_LEASE_RE='(^|[[:space:]])--force-with-lease([[:space:]]|=|$)'
PUSH_DELETE_RE='(^|[[:space:]])--delete([[:space:]]|$)'
PROTECTED_BRANCH_RE='^(main|master|develop|dev|release.*|prod|production.*)$'
# 시스템
DISK_CMD_RE='(^|[^[:alnum:]_-])(mkfs[a-z0-9.]*|format-volume|diskpart|clear-disk|initialize-disk)([[:space:]]|$)|(^|[^[:alnum:]_-])format[[:space:]]+[a-z]:|(^|[^[:alnum:]_-])dd[[:space:]][^;&|]*of=/dev/'
PERM_CMD_RE='(^|[^[:alnum:]_-])(chmod|chown|chgrp|icacls|takeown)[[:space:]]'
RECURSE_PERM_RE='[[:space:]](-r|/t)([[:space:]]|$)'
SUDO_RE='(^|[^[:alnum:]_-])sudo[[:space:]]'
SYSTEM_ASK_RE='(^|[^[:alnum:]_-])(shutdown|reboot|stop-computer|restart-computer)([[:space:]]|$)|set-executionpolicy'

# ── 판정 ───────────────────────────────────────────────
# 판정을 기록합니다. 더 높은 등급만 기존 판정을 덮어쓰며, 같은 등급은 처음 사유를 유지합니다.
# allow는 복합 명령(&&, ;, |, $())에서 쓰지 않습니다. 뒤에 위험한 명령이 숨어 있을 수 있기 때문입니다.
decide() {
  local level=$1 reason=$2 rank=0
  case $level in
    deny) rank=3 ;;
    ask) rank=2 ;;
    allow)
      has_operator && return
      rank=1
      ;;
  esac
  if (( rank > RANK )); then
    RANK=$rank
    LEVEL=$level
    REASON=$reason
  fi
}

# ── 입력 처리 ──────────────────────────────────────────
# stdin JSON에서 tool_input.command 값을 꺼냅니다. jq 없이 sed로 처리합니다.
extract_command() {
  printf '%s' "$1" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p' | head -n 1
}

# JSON 문자열 이스케이프를 되돌립니다. \\ 를 임시 문자(\x01)로 먼저 바꿔 \n, \" 와 섞이지 않게 합니다.
json_unescape() {
  printf '%s' "$1" | sed -e 's/\\\\/\x01/g' -e 's/\\"/"/g' -e 's/\\[nt]/ /g' -e 's/\x01/\\/g'
}

# 따옴표 안 텍스트(커밋 메시지, echo 문자열 등)를 지워 명령으로 오인하지 않게 합니다.
strip_quoted() {
  printf '%s' "$1" | sed -e 's/"[^"]*"/""/g' -e "s/'[^']*'//g"
}

# 연결 연산자나 명령 치환이 있는지 확인합니다. (allow 판정 제외 조건)
has_operator() {
  [[ $code == *';'* || $code == *'&'* || $code == *'|'* || $code == *'$('* || $code == *'`'* ]]
}

# 토큰의 따옴표를 제거하고 소문자로 바꿔 NORM에 담습니다.
normalize_token() {
  NORM=$1
  NORM=${NORM//\"/}
  NORM=${NORM//\'/}
  NORM=${NORM,,}
}

# 원본 명령의 토큰 중 복구 불가능한 범위(루트, 홈, 시스템 경로)가 있는지 확인합니다.
has_dangerous_target() {
  local tok
  for tok in $raw; do
    normalize_token "$tok"
    # 경로 표기를 정리합니다: /./ 와 // 는 / 로, 끝의 /. 는 제거합니다.
    NORM=${NORM//\/.\//\/}
    NORM=${NORM//\/\//\/}
    [[ $NORM == /. ]] && NORM=/
    NORM=${NORM%/.}
    [[ $NORM =~ $DANGER_TARGET_RE ]] && return 0
  done
  return 1
}

# 삭제 대상이 재생성 가능한 산출물 폴더뿐인지 확인합니다.
is_regen_only() {
  local tok first=1
  has_operator && return 1
  for tok in $raw; do
    normalize_token "$tok"
    if (( first )); then
      first=0
      continue
    fi
    [[ $NORM == -* ]] && continue
    NORM=${NORM%/}
    [[ $NORM =~ $REGEN_RE ]] || return 1
  done
  return 0
}

# 현재 NORM 토큰이 환경 변수 파일(.env, 예시 제외)이나 Git 저장소(.git)인지 확인합니다.
is_protected_file() {
  if [[ $NORM =~ $PROTECTED_ENV_RE ]] && [[ ! $NORM =~ $ENV_TEMPLATE_RE ]]; then
    return 0
  fi
  [[ $NORM =~ $PROTECTED_GIT_RE ]]
}

# 재귀 삭제 명령인지 확인합니다.
is_recursive_delete() {
  if [[ $lc =~ $RM_CMD_RE && $lc =~ $RECURSE_FLAG_RE ]]; then
    return 0
  fi
  [[ $lc =~ $CMD_RECURSE_RE ]]
}

# 현재 프로젝트의 브랜치 이름을 소문자로 반환합니다.
current_branch() {
  local branch
  branch=$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null)
  printf '%s' "${branch,,}"
}

# 참조 이름 하나가 보호 브랜치인지 확인합니다. HEAD는 현재 브랜치로 풀어서 봅니다.
is_protected_ref() {
  local name=$1
  name=${name#+}
  name=${name##*:}
  [[ $name == head ]] && name=$(current_branch)
  [[ $name =~ $PROTECTED_BRANCH_RE ]]
}

# 참조가 하나도 없으면 현재 브랜치를 대상으로 봅니다.
is_protected_push() {
  local ref
  (( $# == 0 )) && set -- "$(current_branch)"
  for ref in "$@"; do
    is_protected_ref "$ref" && return 0
  done
  return 1
}

# ── 규칙 ───────────────────────────────────────────────
check_delete() {
  local tok
  if [[ $lc == *--no-preserve-root* ]]; then
    decide deny "루트 보호를 끄는 --no-preserve-root 옵션이라 차단합니다."
  fi

  if is_recursive_delete; then
    if has_dangerous_target; then
      decide deny "루트, 홈, 시스템 경로를 재귀 삭제하는 명령이라 차단합니다. 대상을 프로젝트 내부 경로로 좁히거나 직접 터미널에서 실행하세요."
    elif is_regen_only; then
      decide allow "재생성 가능한 산출물 폴더(node_modules, .next 등)만 삭제하므로 허용합니다."
    else
      decide ask "재귀 삭제 명령입니다. 대상 경로를 확인한 뒤 승인하세요."
    fi
  fi

  if [[ $lc =~ $FIND_DELETE_RE ]]; then
    if has_dangerous_target && ! [[ $lc =~ $FIND_FILTER_RE ]]; then
      decide deny "루트, 홈, 시스템 경로를 find로 일괄 삭제하므로 차단합니다. 직접 터미널에서 실행하세요."
    else
      decide ask "find로 파일을 일괄 삭제합니다. 대상 경로와 조건을 확인한 뒤 승인하세요."
    fi
  fi

  if [[ $lc =~ $DEL_CMD_RE || $lc =~ $MOVE_CMD_RE ]]; then
    for tok in $raw; do
      normalize_token "$tok"
      if is_protected_file; then
        decide ask ".env 파일 또는 .git 저장소를 삭제하거나 이동하려고 합니다. 승인 후 실행하세요."
      fi
    done
  fi
}

# git push 인자(BASH_REMATCH[3])를 검사합니다.
check_git_push() {
  local args=$1 tok ref is_delete=0 is_lease=0
  local -a positional=() refs=()

  for tok in $args; do
    normalize_token "$tok"
    [[ $NORM == -* ]] || positional+=("$NORM")
  done
  # 첫 번째 위치 인자는 원격 이름이므로 제외합니다.
  refs=("${positional[@]:1}")

  if [[ $args =~ $PUSH_DRY_RE ]]; then
    decide allow "Push 드라이런(--dry-run)이라 허용합니다."
    return
  fi
  if [[ $args =~ $PUSH_MIRROR_RE ]]; then
    decide deny "--mirror는 원격 저장소 전체를 덮어쓰므로 차단합니다. 직접 실행하세요."
    return
  fi
  if [[ $args =~ $PUSH_FORCE_RE || $args =~ $PUSH_PLUS_RE ]]; then
    decide deny "강제 Push는 원격 이력을 덮어써 차단합니다. --force-with-lease 사용을 검토하거나 직접 실행하세요."
    return
  fi
  if [[ $args =~ $PUSH_IF_INCLUDES_RE && ! $args =~ $PUSH_LEASE_RE ]]; then
    decide deny "--force-if-includes 단독 사용은 강제 Push라 차단합니다. --force-with-lease를 사용하세요."
    return
  fi

  [[ $args =~ $PUSH_DELETE_RE ]] && is_delete=1
  for ref in "${refs[@]}"; do
    [[ $ref == :* ]] && is_delete=1
  done
  [[ $args =~ $PUSH_LEASE_RE ]] && is_lease=1

  if (( is_delete || is_lease )); then
    if is_protected_push "${refs[@]}"; then
      decide deny "보호 브랜치(main, master, develop, release 등)의 원격 삭제 또는 강제 갱신이라 차단합니다. 직접 실행하세요."
    else
      decide ask "원격 브랜치 삭제 또는 lease 강제 갱신입니다. 대상 브랜치를 확인한 뒤 승인하세요."
    fi
  fi
}

check_git() {
  if [[ $rawlc =~ $PUSH_QUOTED_FORCE_RE ]]; then
    decide deny "따옴표로 감싼 강제 Push 옵션이라 차단합니다. 직접 실행하세요."
  fi
  if [[ $lc =~ $GIT_PUSH_RE ]]; then
    check_git_push "${BASH_REMATCH[3]}"
  fi
  if [[ $lc =~ $RESET_HARD_RE ]]; then
    decide ask "git reset --hard는 커밋되지 않은 변경을 지웁니다. 승인 후 실행하세요."
  fi
  if [[ $lc =~ $CLEAN_RE ]]; then
    if [[ $lc =~ $CLEAN_DRY_RE ]]; then
      decide allow "git clean 드라이런(-n)이라 허용합니다."
    elif [[ $lc =~ $CLEAN_FORCE_RE ]]; then
      decide ask "git clean -f는 추적되지 않은 파일을 영구 삭제합니다. 승인 후 실행하세요."
    fi
  fi
  if [[ $lc =~ $CHECKOUT_RE ]]; then
    decide ask "git checkout으로 커밋되지 않은 변경을 되돌립니다. 승인 후 실행하세요."
  fi
  if [[ $lc =~ $RESTORE_RE && $lc != *--staged* ]]; then
    decide ask "git restore는 작업 중인 변경을 되돌립니다. 승인 후 실행하세요."
  fi
  if [[ $lc =~ $STASH_RE ]]; then
    decide ask "git stash drop/clear는 보관된 변경을 영구 삭제합니다. 승인 후 실행하세요."
  fi
  if [[ $scan =~ $BRANCH_FORCE_DELETE_RE ]]; then
    decide ask "git branch -D는 병합되지 않은 브랜치를 강제 삭제합니다. 승인 후 실행하세요."
  fi
  if [[ $lc =~ $BRANCH_CMD_RE && $lc =~ $BRANCH_DELETE_OPT_RE && $lc =~ $BRANCH_FORCE_OPT_RE ]]; then
    decide ask "강제 삭제 옵션으로 브랜치를 지웁니다. 병합되지 않은 작업이 사라질 수 있으니 승인 후 실행하세요."
  fi
  if [[ $lc =~ $NO_VERIFY_RE ]]; then
    decide ask "--no-verify는 Git 훅 검사를 건너뜁니다. 승인 후 실행하세요."
  fi
}

check_system() {
  if [[ $lc =~ $DISK_CMD_RE ]]; then
    decide deny "디스크 포맷 또는 파티션 조작 명령이라 차단합니다."
  fi
  if [[ $lc =~ $PERM_CMD_RE && $lc =~ $RECURSE_PERM_RE ]]; then
    if has_dangerous_target; then
      decide deny "시스템 또는 홈 경로의 권한을 재귀 변경하므로 차단합니다."
    else
      decide ask "권한을 재귀 변경하는 명령입니다. 승인 후 실행하세요."
    fi
  fi
  if [[ $lc =~ $SUDO_RE ]]; then
    decide ask "관리자 권한(sudo) 명령입니다. 승인 후 실행하세요."
  fi
  if [[ $lc =~ $SYSTEM_ASK_RE ]]; then
    decide ask "시스템 종료, 재부팅 또는 실행 정책 변경 명령입니다. 승인 후 실행하세요."
  fi
}

# ── 메인 ───────────────────────────────────────────────
input=$(cat)
cmd=$(extract_command "$input")
[[ -n $cmd ]] || exit 0

raw=$(json_unescape "$cmd")
code=$(strip_quoted "$raw")
rawlc=${raw,,}

# 셸 래퍼가 있으면 따옴표 안의 명령도 검사 대상이 됩니다.
scan=$code
lc=${code,,}
if [[ $lc =~ $WRAPPER_RE ]]; then
  scan=$raw
fi
lc=${scan,,}

check_delete
check_git
check_system

if [[ -n $LEVEL ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$LEVEL" "$REASON"
fi
exit 0

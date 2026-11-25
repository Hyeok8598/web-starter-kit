# web-starter-kit

Next.js 기반 웹 프로젝트 스타터 킷입니다. 복제 후 사이트 설정과 디자인 토큰만 바꿔 바로 개발을 시작할 수 있습니다.

## 기술 스택

- Next.js (App Router), React, TypeScript
- shadcn/ui (base-nova, Base UI), Tailwind CSS v4
- Lucide React (아이콘), next-themes (테마), sonner (토스트)
- usehooks-ts (공용 훅)

## 시작하기

```bash
npm install
npm run dev     # 개발 서버
npm run lint    # ESLint
npm run build   # 프로덕션 빌드
```

> Next.js 16은 기존 버전과 다른 점이 있습니다. 구현 전 `node_modules/next/dist/docs/`의 관련 문서를 확인하세요.

## 디렉터리 구조

```
app/            라우팅, 페이지 조립, 전역 레이아웃
  _components/  특정 페이지 전용 컴포넌트 (홈의 컴포넌트 예시 등)
  globals.css   디자인 토큰 (테마 커스터마이징 지점)
components/
  ui/           shadcn 생성 컴포넌트 (직접 수정 최소화)
  layout/       헤더, 푸터, 컨테이너
lib/            순수 유틸과 설정 (cn, site)
hooks/          공용 훅 (필요할 때 생성)
public/         정적 자산
```

의존 방향은 `app → components → lib` 단방향입니다.

## 프로젝트별 커스터마이징

| 변경 대상 | 위치 |
|---|---|
| 사이트명, 설명, 메뉴 | `lib/site.ts` |
| 색상, 반경(`--radius`) | `app/globals.css`의 `:root` / `.dark` |
| 폰트 | `app/layout.tsx`(폰트 로드), `app/globals.css`의 `--font-sans` |
| 기본 테마 | `app/layout.tsx`의 `ThemeProvider defaultTheme` (현재 `dark`) |

색상은 `bg-primary`, `text-muted-foreground` 같은 시맨틱 토큰만 사용하고, 임의 색상값은 쓰지 않습니다.

## 컴포넌트 추가

```bash
npx shadcn@latest add <component>
```

- 이미 있는 파일은 덮어쓸지 묻고 멈춥니다. 덮어쓰려면 `-y -o`를 붙입니다.
- 생성된 파일이 `from "cn"`을 import하면 `from "@/lib/utils"`로 바꾸고, `package.json`에 `cn` 패키지가 다시 들어왔다면 제거합니다.
- 이 프로젝트는 Base UI 기반이라 트리거에 `asChild` 대신 `render` prop 또는 `buttonVariants` 클래스를 사용합니다.

## 개발 원칙

- 재사용 순서: 기존 컴포넌트 → shadcn → 조합 → 신규 작성
- 3곳 이상에서 반복될 때만 공통 영역으로 승격합니다.
- 훅은 `usehooks-ts`를 우선 사용하고, 같은 기능의 다른 라이브러리를 추가하지 않습니다.
- 서버 컴포넌트가 기본이며, 상호작용이 필요한 말단만 `"use client"`를 사용합니다.
- 새 외부 의존성은 기존 기능으로 해결할 수 없을 때만 추가합니다.

## 컨벤션

- 파일명 kebab-case, 컴포넌트 PascalCase, 함수와 변수 camelCase (영어)
- 주석, 커밋 메시지, 문서는 한국어
- 기능이 커지면 `features/<name>/`에 components, actions, types를 함께 둡니다.

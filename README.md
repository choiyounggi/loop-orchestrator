# loop-orchestrator

자연어 목표 하나를 던지면, 오케스트레이터가 작업을 **여러 tmux 독립 Claude Code 세션**으로 쪼개 병렬로 구현하고, 각 세션은 실제 개발 방법론에 근거한 **검증 루프**로 작업을 완수하며, 통합 테스트 후 **사용자 확인을 거쳐 병합**까지 진행하는 Claude Code 플러그인.

자율로 굴러가되 사고가 남는 두 지점(작업 분해 / 병합)에는 사람 게이트를 둔다.

## 빠른 시작

### 1. 사전 요구사항
- **macOS 또는 Linux** (tmux 의존)
- [Claude Code](https://github.com/anthropics/claude-code) 설치 + 로그인
- `git`, `tmux`, `jq` — 없으면 플러그인이 설치 방법을 안내합니다 (자동 설치는 하지 않음)

### 2. 설치
```
/plugin marketplace add choiyounggi/loop-orchestrator
/plugin install loop-orchestrator@loop-orchestrator
```
> Claude Code 플러그인이라 git 저장소 기반으로 설치됩니다 (npm 아님).

### 3. 사용
Claude Code 대화에서 자연어로 요청하세요:
> "이 목표를 오케스트레이터로 구현해줘: &lt;무엇을 만들지&gt;"

오케스트레이터가 필요한 정보를 질문으로 채운 뒤, 작업을 나눠 병렬로 진행합니다.

## 동작 원리

```
자연어 목표
  → [구체화]      목표/범위/제약/완료기준을 질문으로 명확화
  → [환경 감지]   git 저장소 → 피처브랜치 + 작업별 워크트리 / 없으면 git init(선검사 후)
  → [작업 분해]   독립 작업 N개 + 충돌·의존 분석 → Wave
  → 🚦 분해 승인   "이렇게 N개로 쪼갰어. 진행?"          ← 사용자 확인
  → [세션 기동]   워크트리마다 claude 세션 → 각자 검증 루프로 구현
  → [검토·재작업] 오케가 각 결과 검토 (재작업 최대 3회)
  → [통합 테스트] 통합 지점에서 전체 동작 검증
  → 🚦 병합 검수   통합 diff 전체 제시                   ← 사용자 확인
  → [정리·병합]   서브브랜치 → 피처브랜치 병합 → 워크트리/세션 정리
```

사용자 접점은 네 군데뿐입니다: 구체화 질문, 모호할 때 되물음, **분해 승인**, **병합 검수**. 나머지는 자율.

## 검증 루프 (loop-implement)

각 세션이 작업 하나에 대해 도는 닫힌 루프입니다. 임의로 정한 단계가 아니라 인정받는 방법론에 근거합니다:

```
0. 완료조건 정의 (DoD/인수기준)   1. 분석   2. 계획/설계
3. 테스트 작성(Red, test-first)    4. 구현(Green)   5. 테스트 실행
6. 셀프리뷰 + 리팩터
6.5 독립 검증 (test-quality-auditor — 자기 테스트를 자기가 판정하지 않음)
7. 완료조건 판정 → 통과 시 done / 실패 시 반성 후 재시도(최대 3회)
```

근거: TDD Red-Green-Refactor·test-first(Kent Beck), PDCA(Shewhart/Deming), 코드리뷰(Google eng-practices), Definition of Done(Scrum)·인수기준(XP), self-verification(Self-Refine·Reflexion·Anthropic *Building Effective Agents*), bounded retry.

## 안전장치

- **두 게이트**: 작업 분해 승인 + 병합 전 통합 diff 검수 (자율 흐름의 강제 정지점)
- **파괴작업 가드** (`safe-cleanup.sh`): 미커밋 변경 있는 워크트리는 제거 거부(`--force` 미사용), tmux 세션은 정확한 이름만 종료(prefix/grep 매칭 금지), 충돌 시 중단·보고
- **git init 선검사**: 상위 저장소 안(중첩)·시크릿 파일(`.env`/`*.pem`/`*credential*`) 감지 시 거부
- **검증 게이밍 방지**: 코드를 작성한 세션이 자기 테스트 품질을 자가판정하지 않도록 별도 읽기전용 에이전트가 판정

## 구성요소

| 종류 | 이름 | 역할 |
|------|------|------|
| 스킬 | `orchestrate` | 분해·분배·검토·통합·병합 관리 (오케스트레이터) |
| 스킬 | `loop-implement` | 단일 작업 검증 루프 (각 세션, 단독 사용도 가능) |
| 에이전트 | `test-quality-auditor` | 테스트 품질 독립 검증 (읽기전용) |
| 훅 | `preflight` (SessionStart) | git/tmux/jq 탐지 + 안내 |
| 훅 | `loop-gate` (Stop) | 검증 루프 미완 시 세션 종료 차단 |

## 알려진 한계
- **macOS / Linux 전용** — tmux와 POSIX 셸에 의존 (Windows 미지원)
- **원격 push / PR / 머지는 자동화하지 않음** — 피처브랜치 로컬 병합까지만, 그 다음은 사용자 몫
- 세션은 `bypassPermissions`로 실행됩니다. 받는 환경에 별도 파괴명령 가드가 없을 수 있으니 신뢰하는 작업에만 사용하세요.

## 릴리스 자동화 (maintainer)
1. `.claude-plugin/plugin.json`의 `version`을 올립니다.
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. GitHub Actions(`release.yml`)가 태그와 버전 일치를 확인하고 **GitHub Release + 릴리즈노트**를 자동 생성합니다. (npm 배포는 없음)

## 라이선스
MIT

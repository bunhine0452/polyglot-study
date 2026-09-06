import Foundation

// packtool — 콘텐츠 팩 검증·빌드·서명 CLI.
//
// **여기는 자리만 잡아 둔 스텁이다.** 실구현은 플래너의 `{#packtool-structural}`
// `{#packtool-execution}` `{#packtool-semantic}` `{#packtool-report}` `{#packtool-build}`
// `{#packtool-sign}` 항목이고 다른 작업이다.
//
// 의존성이 비어 있는 것도 의도다 — CLI 표면을 만드는 쪽이 `swift-argument-parser` 를
// 붙일지 직접 정하면 된다. Tools 패키지에는 이미 1.8.2 가 핀되어 있다.

let usage = """
packtool — 콘텐츠 팩 검증·빌드·서명 (미구현 스텁)

사용법:
  packtool validate <pack-path>     구조·문법·의미·실행 게이트
  packtool build <pack-path>        solutions 를 벗기고 배포용 팩을 결정적으로 굽기
  packtool sign <pack-path>         정규 매니페스트 바이트에 분리 서명

아직 어떤 하위 명령도 구현되어 있지 않습니다.

"""

FileHandle.standardError.write(Data(usage.utf8))
exit(2)

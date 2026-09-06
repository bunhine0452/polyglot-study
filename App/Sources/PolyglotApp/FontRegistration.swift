internal import CoreText
internal import Foundation

/// IBM Plex 폰트를 **프로세스 스코프**로 런타임 등록한다 — `{#plex-font-bundling}` `{#font-registration-path}`.
///
/// ## 왜 `ATSApplicationFontsPath` 만으로 부족한가
///
/// `Info.plist` 의 `ATSApplicationFontsPath`(`Fonts`)는 LaunchServices 가 번들을
/// **`.app` 으로 등록·실행했을 때만** 읽는다(실측: `App/Package.swift` 상단 주석,
/// `Info.plist` 의 같은 키 주석 참고). 두 경로가 그 조건을 못 채운다.
///
///   1. `swift run --package-path App` — Xcode 프로젝트가 없으므로 이 저장소의 가장 흔한
///      개발 실행 경로다. 산출물이 `.build/debug/PolyglotApp` 단일 실행 파일이라 번들이
///      아예 없다.
///   2. `Scripts/build-app.sh` 가 만든 번들이라도, 방금 만든 번들은 LaunchServices 가
///      아직 인덱싱하지 않았을 수 있다(스크립트가 `lsregister` 를 부르지만 캐시 반영은
///      비동기다).
///
/// `CTFontManagerRegisterFontsForURL(_:.process,_:)` 는 이 두 조건과 무관하게 동작한다 —
/// 파일 경로만 있으면 등록되고, 등록은 현재 프로세스에만 유효해 시스템 폰트 목록을
/// 더럽히지 않는다. `ATSApplicationFontsPath` 와 이 등록이 동시에 성공해도 상관없다 —
/// 중복 등록 에러(`.alreadyRegistered`)를 정상으로 취급한다.
///
/// ## 실측 — 패밀리명 표기
///
/// CoreText 가 보고하는 실제 이름은 다음과 같다(등록 후 `CTFontCopyPostScriptName` /
/// `CTFontCopyFamilyName` 로 확인):
///
/// | 파일 | PostScript 이름 | 표시 패밀리 |
/// |---|---|---|
/// | `IBMPlexSansKR-Regular.ttf` | `IBMPlexSansKR` | `IBM Plex Sans KR` |
/// | `IBMPlexMono-Regular.ttf` | `IBMPlexMono` | `IBM Plex Mono` |
///
/// `Typography.sansFamily`/`monoFamily` (`DesignSystem/Tokens.swift`)는 공백 없는
/// PostScript 형("IBMPlexSansKR")으로 이미 적혀 있다. `AppFont.resolve(_:)` 의 3단계 중
/// **2단계**(`NSFont(name:)` 이 PostScript 이름을 직접 푸는 경로)에서 잡힌다 — 1단계
/// (`availableFontFamilies` 정확 일치)는 표시 패밀리("IBM Plex Sans KR")만 담고 있어
/// 실패하고, 3단계(공백 제거 비교)까지 갈 필요가 없다. 토큰 값을 고치지 않아도 된다.
enum FontRegistration {
    private static let fontExtensions: Set<String> = ["ttf", "otf"]

    /// `PolyglotApp.init()` 에서 첫 화면이 그려지기 전에 호출한다. `AppFont.resolvedSans`/
    /// `resolvedMono` 가 `static let`(첫 접근 시 1회 평가)이므로, 그 접근보다 먼저만
    /// 불리면 순서 문제가 없다.
    static func registerBundledFonts() {
        guard let directory = fontsDirectory() else {
            FileHandle.standardError.write(Data("font register: Fonts 디렉터리를 찾지 못함 — 폴백 폰트로 렌더된다\n".utf8))
            return
        }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }

        for url in entries where fontExtensions.contains(url.pathExtension.lowercased()) {
            var unmanagedError: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &unmanagedError)
            guard !ok, let error = unmanagedError?.takeRetainedValue() else { continue }
            // 이미 등록됐으면(중복 호출, ATSApplicationFontsPath 와 경합 등) 정상이다.
            if CFErrorGetCode(error) == CTFontManagerError.alreadyRegistered.rawValue { continue }
            FileHandle.standardError.write(Data("font register 실패: \(url.lastPathComponent) — \(error)\n".utf8))
        }
    }

    /// 후보 순서: 명시 오버라이드 → 번들 `Contents/Resources/Fonts`(배포 경로,
    /// `build-app.sh` 가 `Info.plist` 의 `ATSApplicationFontsPath` 와 같은 자리에 복사) →
    /// 저장소 루트로 거슬러 올라가며 찾는 개발 경로(`Composition.packCandidates` 와 동일한
    /// 패턴 — 개발 실행에서는 번들이 `App/.build/...` 안에 있다).
    private static func fontsDirectory() -> URL? {
        let manager = FileManager.default
        if let override = ProcessInfo.processInfo.environment["POLYGLOT_FONTS_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Fonts", isDirectory: true),
           manager.fileExists(atPath: bundled.path) {
            return bundled
        }
        var probe = Bundle.main.bundleURL
        for _ in 0..<8 {
            probe.deleteLastPathComponent()
            let candidate = probe.appendingPathComponent("App/Resources/Fonts", isDirectory: true)
            if manager.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }
}

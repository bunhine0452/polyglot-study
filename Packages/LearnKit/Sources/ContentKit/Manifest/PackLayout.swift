/// 팩 디렉터리 레이아웃 v1. `docs/pack-format.md` 와 이 파일이 같은 것을 말해야 한다.
///
/// ```
/// <pack>/
///   manifest.json          팩 메타데이터 (스키마 v1). files 에 자기 자신은 넣지 않는다.
///   stableids.lock         stableID 불변 잠금 파일
///   lessons/    <id>.md    디렉티브 마크다운 레슨 본문
///   starters/   <path>     과제 시작 코드 (학습자에게 주어지는 것)
///   tests/      <path>     숨은 테스트 (채점기가 돌리는 것)
///   solutions/  <path>     정답 코드 (배포 팩에서는 벗겨진다)
///   expected/   <id>.txt   실행 예제의 기대 stdout
///   assets/     <path>     이미지·샘플 DB 등 읽기 전용 자원
/// ```
public enum PackLayout {
    public static let manifestFileName = "manifest.json"
    public static let lockFileName = "stableids.lock"

    public static let lessonsDirectory = "lessons"
    public static let startersDirectory = "starters"
    public static let testsDirectory = "tests"
    public static let solutionsDirectory = "solutions"
    public static let expectedDirectory = "expected"
    public static let assetsDirectory = "assets"

    /// `files` 에 등록될 수 있는 최상위 디렉터리 6종. 이 밖의 위치는 검증에서 거부된다.
    public static let contentDirectories: [String] = [
        lessonsDirectory, startersDirectory, testsDirectory,
        solutionsDirectory, expectedDirectory, assetsDirectory,
    ]

    /// 최상위에 그냥 놓일 수 있는 파일. `manifest.json` 은 자기 해시를 담을 수 없으므로
    /// `files` 에 등록되지 않고, 나머지는 등록된다.
    public static let rootFiles: [String] = [lockFileName]

    /// 배포 팩에서 벗겨지는 디렉터리. `packtool build` 가 여기를 지운다.
    public static let strippedInDistribution: [String] = [solutionsDirectory]

    /// 경로가 레이아웃 안에 있는가. `files` 등록 자격 검사.
    public static func isRegisterable(_ path: PackRelativePath) -> Bool {
        if let directory = path.topLevelDirectory {
            return contentDirectories.contains(directory)
        }
        return rootFiles.contains(path.rawValue)
    }
}
